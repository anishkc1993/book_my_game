import 'package:flutter/foundation.dart';

import '../../domain/entities/concession_expense_entity.dart';
import '../../domain/entities/concession_item_entity.dart';
import '../../domain/entities/concession_sale_entity.dart';
import '../../domain/repositories/concession_repository.dart';

enum ConcessionState { initial, loading, loaded, error }

/// One calendar month's cafe collection — total + sale count + the days
/// inside the month. Populated by [ConcessionProvider.monthlyBreakdown].
class ConcessionMonth {
  final int year;
  final int month; // 1..12
  final double amount;
  final int count;
  /// Individual days within the month with their per-day totals.
  final List<ConcessionDay> days;
  const ConcessionMonth({
    required this.year,
    required this.month,
    required this.amount,
    required this.count,
    required this.days,
  });

  String get monthKey =>
      '$year-${month.toString().padLeft(2, '0')}';
}

/// One day in the concession 7-day breakdown.
class ConcessionDay {
  final DateTime date; // midnight-normalized
  final double amount;
  final int count;
  const ConcessionDay({
    required this.date,
    required this.amount,
    required this.count,
  });
}

class ConcessionProvider extends ChangeNotifier {
  final ConcessionRepository _repository;
  ConcessionProvider({required ConcessionRepository repository})
      : _repository = repository;

  String? _turfId;
  String? get turfId => _turfId;

  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _items = [];
    _sales = [];
    _todayTotal = 0;
    _state = ConcessionState.initial;
    notifyListeners();
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

  ConcessionState _state = ConcessionState.initial;
  ConcessionState get state => _state;

  String? _error;
  String? get error => _error;

  List<ConcessionItemEntity> _items = [];
  List<ConcessionItemEntity> get items => _items;
  List<ConcessionItemEntity> get activeItems =>
      _items.where((i) => i.isActive).toList();

  /// Active items sorted by recent sales volume (most-sold over the
  /// last-7-days window first). Items with zero sales fall to the end
  /// alphabetically. Used by the cafe quick-record chips so popular
  /// items bubble to the top automatically as the catalog grows.
  List<ConcessionItemEntity> get popularItems {
    final salesByItemId = <String, int>{};
    for (final s in _sales) {
      final id = s.itemId;
      if (id == null || id.isEmpty) continue;
      salesByItemId[id] = (salesByItemId[id] ?? 0) + s.quantity;
    }
    final list = [..._items.where((i) => i.isActive)];
    list.sort((a, b) {
      final ca = salesByItemId[a.id ?? ''] ?? 0;
      final cb = salesByItemId[b.id ?? ''] ?? 0;
      if (ca != cb) return cb.compareTo(ca);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// One-tap shortcut: records [quantity] × [item] at the item's
  /// default price. Used by the cafe chip's short-tap. Falls back to
  /// the full sheet only if quantity or price isn't a clean default.
  Future<bool> quickSale({
    required ConcessionItemEntity item,
    required String markedBy,
    int quantity = 1,
  }) {
    return recordSale(
      item: item,
      itemName: item.name,
      quantity: quantity,
      amount: item.defaultPrice * quantity,
      markedBy: markedBy,
    );
  }

  List<ConcessionSaleEntity> _sales = [];
  List<ConcessionSaleEntity> get sales => _sales;

  /// Wider sales window (~180 days) used to build the by-month
  /// breakdown on the collections page. Kept separate from [_sales]
  /// (which stays at last-7 days) so the smaller UI slice doesn't drag
  /// in older docs unnecessarily.
  List<ConcessionSaleEntity> _monthlySales = const [];

  double _todayTotal = 0;
  double get todayTotal => _todayTotal;

  /// Daily concession totals for the last 7 days (today inclusive).
  /// Ordered newest first. Each entry: date (midnight) + total + sale count.
  List<ConcessionDay> _weekBreakdown = const [];
  List<ConcessionDay> get weekBreakdown => _weekBreakdown;
  double get weekTotal =>
      _weekBreakdown.fold<double>(0, (s, d) => s + d.amount);

  /// Concession totals grouped by calendar month, newest first.
  /// Powers the "By month" section on the collections page. Each month
  /// carries its own per-day breakdown for the expand-to-see-days UX.
  List<ConcessionMonth> get monthlyBreakdown {
    if (_monthlySales.isEmpty) return const [];
    // Group by (year, month), collecting a per-day bucket inside each.
    final byMonth = <String, _MonthBucket>{};
    for (final s in _monthlySales) {
      final d = DateTime(s.soldAt.year, s.soldAt.month, s.soldAt.day);
      final mKey = '${d.year}-${d.month}';
      final bucket = byMonth.putIfAbsent(
        mKey,
        () => _MonthBucket(year: d.year, month: d.month),
      );
      final dKey = _keyFor(d);
      final day = bucket.byDay.putIfAbsent(
        dKey,
        () => _DayBucket(date: d),
      );
      day.amount += s.amount;
      day.count += 1;
      bucket.amount += s.amount;
      bucket.count += 1;
    }
    final months = byMonth.values.map((b) {
      final days = b.byDay.values
          .map((d) =>
              ConcessionDay(date: d.date, amount: d.amount, count: d.count))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return ConcessionMonth(
        year: b.year,
        month: b.month,
        amount: b.amount,
        count: b.count,
        days: days,
      );
    }).toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
    return months;
  }

  /// Bumped on every successful sale/record/delete so dashboards can
  /// refresh their concession revenue line without a manual reload.
  final ValueNotifier<int> mutations = ValueNotifier<int>(0);
  void _bump() => mutations.value = mutations.value + 1;

  Future<void> load() async {
    if (!_hasTurf) return;
    _state = ConcessionState.loading;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.listItems(_turfId!),
        // Pull last 7 days of sales — gives us both the recent list and
        // raw data for the 7-day daily breakdown, in one round trip.
        _repository.listSales(
          _turfId!,
          since: DateTime.now().subtract(const Duration(days: 7)),
          limit: 500,
        ),
        // Pull last ~35 days of expenses so weekly/monthly totals
        // resolve without an extra round trip.
        _repository.listExpenses(
          _turfId!,
          since: DateTime.now().subtract(const Duration(days: 35)),
          limit: 500,
        ),
        // Pull ~180 days of sales for the by-month breakdown card on
        // the collections page. Small futsal volume → still cheap.
        _repository.listSales(
          _turfId!,
          since: DateTime.now().subtract(const Duration(days: 180)),
          limit: 5000,
        ),
      ]);
      _items = results[0] as List<ConcessionItemEntity>;
      final weekSales = results[1] as List<ConcessionSaleEntity>;
      _sales = weekSales;
      _weekBreakdown = _aggregateByDay(weekSales);
      _todayTotal = _weekBreakdown.isNotEmpty &&
              _isSameDay(_weekBreakdown.first.date, DateTime.now())
          ? _weekBreakdown.first.amount
          : 0;
      _expenses = results[2] as List<ConcessionExpenseEntity>;
      await _refreshExpenseTotals();
      _monthlySales = results[3] as List<ConcessionSaleEntity>;
      _state = ConcessionState.loaded;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _state = ConcessionState.error;
    }
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Group raw sales into per-day buckets, including 0-revenue days so
  /// the UI shows a complete 7-day strip.
  List<ConcessionDay> _aggregateByDay(List<ConcessionSaleEntity> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <String, ConcessionDay>{};
    // Pre-fill 7 days so empty days still render.
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      buckets[_keyFor(d)] = ConcessionDay(date: d, amount: 0, count: 0);
    }
    for (final s in sales) {
      final d = DateTime(s.soldAt.year, s.soldAt.month, s.soldAt.day);
      final key = _keyFor(d);
      final existing = buckets[key];
      if (existing == null) continue; // outside the 7-day window
      buckets[key] = ConcessionDay(
        date: existing.date,
        amount: existing.amount + s.amount,
        count: existing.count + 1,
      );
    }
    final list = buckets.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  String _keyFor(DateTime d) =>
      '${d.year}-${d.month}-${d.day}';


  Future<bool> saveItem(ConcessionItemEntity item) async {
    if (!_hasTurf) return false;
    try {
      final scoped = item.copyWith(turfId: _turfId);
      final saved = await _repository.upsertItem(scoped);
      final idx = _items.indexWhere((x) => x.id == saved.id);
      if (idx >= 0) {
        _items[idx] = saved;
      } else {
        _items.add(saved);
      }
      _items.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    if (!_hasTurf) return false;
    try {
      await _repository.deleteItem(_turfId!, id);
      final idx = _items.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(isActive: false);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordSale({
    required ConcessionItemEntity? item,
    required String itemName,
    required int quantity,
    required double amount,
    String? notes,
    required String markedBy,
    DateTime? date,
  }) async {
    // amount can be 0 (e.g., free water complimentary to a booker).
    if (!_hasTurf || quantity <= 0 || amount < 0) return false;
    try {
      final sale = ConcessionSaleEntity(
        itemId: item?.id,
        itemName: itemName,
        quantity: quantity,
        amount: amount,
        soldAt: date ?? DateTime.now(),
        markedBy: markedBy,
        notes: notes,
        turfId: _turfId,
      );
      final saved = await _repository.recordSale(sale);
      _sales = [saved, ..._sales];
      _ledgerSales = [saved, ..._ledgerSales];
      // Re-aggregate so today's bucket + week total stay consistent.
      _weekBreakdown = _aggregateByDay(_sales);
      _todayTotal = _weekBreakdown.isNotEmpty &&
              _isSameDay(_weekBreakdown.first.date, DateTime.now())
          ? _weekBreakdown.first.amount
          : amount;
      _bump();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Edit an existing sale (item / quantity / amount / notes). Preserves
  /// `soldAt`, `markedBy`, `turfId` so the history bucketing stays stable.
  Future<bool> updateSale({
    required ConcessionSaleEntity original,
    required ConcessionItemEntity? item,
    required String itemName,
    required int quantity,
    required double amount,
    String? notes,
  }) async {
    if (!_hasTurf || original.id == null) return false;
    if (quantity <= 0 || amount < 0) return false;
    try {
      final updated = ConcessionSaleEntity(
        id: original.id,
        itemId: item?.id,
        itemName: itemName,
        quantity: quantity,
        amount: amount,
        soldAt: original.soldAt,
        markedBy: original.markedBy,
        notes: notes,
        turfId: original.turfId ?? _turfId,
      );
      final saved = await _repository.updateSale(updated);
      final idx = _sales.indexWhere((s) => s.id == saved.id);
      if (idx >= 0) {
        _sales[idx] = saved;
      }
      _weekBreakdown = _aggregateByDay(_sales);
      _todayTotal = _weekBreakdown.isNotEmpty &&
              _isSameDay(_weekBreakdown.first.date, DateTime.now())
          ? _weekBreakdown.first.amount
          : 0;
      _bump();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSale(ConcessionSaleEntity sale) async {
    if (!_hasTurf || sale.id == null) return false;
    try {
      await _repository.deleteSale(_turfId!, sale.id!);
      _sales.removeWhere((s) => s.id == sale.id);
      _weekBreakdown = _aggregateByDay(_sales);
      _todayTotal = _weekBreakdown.isNotEmpty &&
              _isSameDay(_weekBreakdown.first.date, DateTime.now())
          ? _weekBreakdown.first.amount
          : 0;
      _bump();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Period totals for analytics integration.
  Future<double> sumBetween(DateTime start, DateTime end) async {
    if (!_hasTurf) return 0;
    return _repository.sumSalesBetween(
      turfId: _turfId!,
      start: start,
      end: end,
    );
  }

  /// Raw sales for a single day — used by the history page when the
  /// admin picks a date older than the in-memory 7-day window.
  Future<List<ConcessionSaleEntity>> salesForDay(DateTime day) async {
    if (!_hasTurf) return const [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _repository.listSalesBetween(
      turfId: _turfId!,
      start: start,
      end: end,
    );
  }

  // ── Expenses ──────────────────────────────────────────────────────────
  List<ConcessionExpenseEntity> _expenses = const [];
  List<ConcessionExpenseEntity> get expenses => _expenses;

  // Full history for the combined ledger view — all time, no date cap.
  List<ConcessionSaleEntity> _ledgerSales = const [];
  List<ConcessionExpenseEntity> _ledgerExpenses = const [];
  List<ConcessionSaleEntity> get ledgerSales => _ledgerSales;
  List<ConcessionExpenseEntity> get ledgerExpenses => _ledgerExpenses;

  /// Fetch all-time sales + expenses for the combined ledger page.
  Future<void> loadLedger() async {
    if (!_hasTurf) return;
    try {
      final results = await Future.wait([
        _repository.listSales(_turfId!, limit: 5000),
        _repository.listExpenses(_turfId!, limit: 5000),
      ]);
      _ledgerSales = results[0] as List<ConcessionSaleEntity>;
      _ledgerExpenses = results[1] as List<ConcessionExpenseEntity>;
      // Also keep _expenses up to date for the totals.
      _expenses = _ledgerExpenses;
      await _refreshExpenseTotals();
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Period totals computed locally from the loaded expenses (last 30
  /// days fetched in [load]). For the rare case of expenses older than
  /// the loaded window, call [sumExpenseBetween] directly.
  double _todayExpense = 0;
  double _weekExpense = 0;
  double _monthExpense = 0;
  double get todayExpense => _todayExpense;
  double get weekExpense => _weekExpense;
  double get monthExpense => _monthExpense;

  /// Net profit shortcuts. Sales − expenses for the matching window.
  double get todayNet => _todayTotal - _todayExpense;
  double get weekNet => weekTotal - _weekExpense;

  Future<void> _refreshExpenseTotals() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final daysSinceSunday = (now.weekday - DateTime.sunday + 7) % 7;
    final startOfWeek =
        startOfDay.subtract(Duration(days: daysSinceSunday));
    final startOfMonth = DateTime(now.year, now.month, 1);
    _todayExpense = _sumExpensesLocal(startOfDay);
    _weekExpense = _sumExpensesLocal(startOfWeek);
    _monthExpense = _sumExpensesLocal(startOfMonth);
  }

  double _sumExpensesLocal(DateTime since) {
    double total = 0;
    for (final e in _expenses) {
      if (!e.spentAt.isBefore(since)) total += e.amount;
    }
    return total;
  }

  /// Pull recent expenses + recompute today/week/month totals. Cheap —
  /// one query, ~30 day window.
  Future<void> loadExpenses() async {
    if (!_hasTurf) return;
    try {
      final since = DateTime.now().subtract(const Duration(days: 35));
      _expenses = await _repository.listExpenses(_turfId!, since: since);
      await _refreshExpenseTotals();
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> recordExpense({
    required String itemName,
    required int quantity,
    required double amount,
    String? notes,
    required String markedBy,
    DateTime? date,
  }) async {
    if (!_hasTurf || itemName.isEmpty || quantity <= 0 || amount < 0) {
      return false;
    }
    try {
      final entity = ConcessionExpenseEntity(
        itemName: itemName,
        quantity: quantity,
        amount: amount,
        spentAt: date ?? DateTime.now(),
        markedBy: markedBy,
        notes: notes,
        turfId: _turfId,
      );
      final saved = await _repository.recordExpense(entity);
      _expenses = [saved, ..._expenses];
      _ledgerExpenses = [saved, ..._ledgerExpenses];
      await _refreshExpenseTotals();
      _bump();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(ConcessionExpenseEntity expense) async {
    if (!_hasTurf || expense.id == null) return false;
    try {
      await _repository.deleteExpense(_turfId!, expense.id!);
      _expenses.removeWhere((e) => e.id == expense.id);
      await _refreshExpenseTotals();
      _bump();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}

/// Internal accumulator for the monthly breakdown builder.
class _MonthBucket {
  final int year;
  final int month;
  double amount = 0;
  int count = 0;
  final Map<String, _DayBucket> byDay = {};
  _MonthBucket({required this.year, required this.month});
}

class _DayBucket {
  final DateTime date;
  double amount = 0;
  int count = 0;
  _DayBucket({required this.date});
}
