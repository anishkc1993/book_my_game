import 'package:flutter/foundation.dart';

import '../../domain/entities/monthly_plan_entity.dart';
import '../../domain/repositories/monthly_plan_repository.dart';

enum MonthlyPlanState { initial, loading, loaded, error }

class MonthlyPlanProvider extends ChangeNotifier {
  final MonthlyPlanRepository _repository;
  MonthlyPlanProvider({required MonthlyPlanRepository repository})
      : _repository = repository;

  String? _turfId;
  String? get turfId => _turfId;

  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _plans = [];
    _state = MonthlyPlanState.initial;
    notifyListeners();
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

  MonthlyPlanState _state = MonthlyPlanState.initial;
  MonthlyPlanState get state => _state;

  String? _error;
  String? get error => _error;

  bool _saving = false;
  bool get saving => _saving;

  List<MonthlyPlanEntity> _plans = [];
  List<MonthlyPlanEntity> get plans => _plans;

  String get currentMonth => MonthlyPlanEntity.monthKey(DateTime.now());

  /// Bumped when a payment is recorded — analytics + dashboard listen so
  /// revenue refreshes without manual pull-to-refresh.
  final ValueNotifier<int> mutations = ValueNotifier<int>(0);
  void _bumpMutation() => mutations.value = mutations.value + 1;

  Future<void> load() async {
    if (!_hasTurf) return;
    _state = MonthlyPlanState.loading;
    _error = null;
    notifyListeners();
    try {
      _plans = await _repository.list(_turfId!);
      _state = MonthlyPlanState.loaded;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _state = MonthlyPlanState.error;
    }
    notifyListeners();
  }

  Future<bool> save(MonthlyPlanEntity plan) async {
    if (!_hasTurf) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final scoped = plan.copyWith(turfId: _turfId);
      final saved = await _repository.upsert(scoped);
      final idx = _plans.indexWhere((p) => p.id == saved.id);
      if (idx >= 0) {
        _plans[idx] = saved;
      } else {
        _plans.add(saved);
      }
      // Same stable order as the datasource — never re-sort by isActive
      // so toggling never reshuffles.
      _plans.sort((a, b) {
        if (a.startHour != b.startHour) {
          return a.startHour.compareTo(b.startHour);
        }
        return a.customerName.compareTo(b.customerName);
      });
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String planId) async {
    if (!_hasTurf) return false;
    try {
      await _repository.delete(_turfId!, planId);
      _plans.removeWhere((p) => p.id == planId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> setActive(String planId, bool isActive) async {
    if (!_hasTurf) return false;
    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx < 0) return false;
    // Optimistic update — flip the Switch immediately so admin gets
    // instant feedback. If the write fails we revert below.
    final previous = _plans[idx];
    _plans[idx] = previous.copyWith(isActive: isActive);
    notifyListeners();
    try {
      await _repository
          .setActive(_turfId!, planId, isActive)
          .timeout(const Duration(seconds: 8));
      // Re-pull from server to confirm the write actually committed
      // (Firestore can succeed-locally then silently revert if the
      // server rejects with a permission error).
      try {
        await _refreshOne(planId).timeout(const Duration(seconds: 8));
      } catch (_) {/* don't fail the toggle on a refresh hiccup */}
      return true;
    } catch (e) {
      _plans[idx] = previous;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Re-fetch the list and overwrite [_plans] — used after writes to
  /// reconcile any silent rollbacks.
  Future<void> _refreshOne(String planId) async {
    try {
      final fresh = await _repository.list(_turfId!);
      _plans = fresh;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ _refreshOne failed: $e');
    }
  }

  Future<bool> markPaid({
    required String planId,
    required String month,
    required double amount,
    required String markedBy,
  }) async {
    if (!_hasTurf) return false;
    try {
      await _repository.markPaid(
        turfId: _turfId!,
        planId: planId,
        month: month,
        amount: amount,
        markedBy: markedBy,
      );
      final idx = _plans.indexWhere((p) => p.id == planId);
      if (idx >= 0) {
        _plans[idx] = _plans[idx].copyWith(lastPaidMonth: month);
      }
      _bumpMutation();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Sum of plan payments at the current turf in the given range (used by
  /// analytics + dashboard).
  Future<double> sumPaymentsBetween(DateTime start, DateTime end) async {
    if (!_hasTurf) return 0;
    return _repository.sumPaymentsBetween(
      turfId: _turfId!,
      start: start,
      end: end,
    );
  }
}
