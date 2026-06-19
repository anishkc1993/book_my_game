import 'package:flutter/foundation.dart';

import '../../domain/entities/concession_item_entity.dart';
import '../../domain/entities/concession_sale_entity.dart';
import '../../domain/repositories/concession_repository.dart';

enum ConcessionState { initial, loading, loaded, error }

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

  List<ConcessionSaleEntity> _sales = [];
  List<ConcessionSaleEntity> get sales => _sales;

  double _todayTotal = 0;
  double get todayTotal => _todayTotal;

  /// Daily concession totals for the last 7 days (today inclusive).
  /// Ordered newest first. Each entry: date (midnight) + total + sale count.
  List<ConcessionDay> _weekBreakdown = const [];
  List<ConcessionDay> get weekBreakdown => _weekBreakdown;
  double get weekTotal =>
      _weekBreakdown.fold<double>(0, (s, d) => s + d.amount);

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
        // raw data for the daily breakdown, in one round trip.
        _repository.listSales(
          _turfId!,
          since: DateTime.now().subtract(const Duration(days: 7)),
          limit: 500,
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
  }) async {
    // amount can be 0 (e.g., free water complimentary to a booker).
    if (!_hasTurf || quantity <= 0 || amount < 0) return false;
    try {
      final sale = ConcessionSaleEntity(
        itemId: item?.id,
        itemName: itemName,
        quantity: quantity,
        amount: amount,
        soldAt: DateTime.now(),
        markedBy: markedBy,
        notes: notes,
        turfId: _turfId,
      );
      final saved = await _repository.recordSale(sale);
      _sales = [saved, ..._sales];
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
}
