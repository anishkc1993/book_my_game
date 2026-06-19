import 'package:flutter/foundation.dart';

import '../../domain/entities/analytics_entity.dart';
import '../../domain/entities/yearly_revenue_entity.dart';
import '../../domain/repositories/analytics_repository.dart';

enum AnalyticsState { initial, loading, loaded, error }

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsRepository _repository;

  AnalyticsProvider({required AnalyticsRepository repository})
      : _repository = repository;

  // Multi-tenant: current turf scope (set via app glue from AuthProvider).
  String? _turfId;
  String? get turfId => _turfId;

  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _analyticsCache.clear();
    _state = AnalyticsState.initial;
    _errorMessage = null;
    notifyListeners();
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

  AnalyticsState _state = AnalyticsState.initial;
  String? _errorMessage;
  TimePeriod _selectedPeriod = TimePeriod.today;

  // Cache analytics per period
  final Map<TimePeriod, AnalyticsEntity> _analyticsCache = {};

  AnalyticsState get state => _state;
  String? get errorMessage => _errorMessage;
  TimePeriod get selectedPeriod => _selectedPeriod;

  AnalyticsEntity? get currentAnalytics => _analyticsCache[_selectedPeriod];

  Future<void> fetchAnalytics({bool forceRefresh = false}) async {
    if (!_hasTurf) return;

    if (!forceRefresh && _analyticsCache.containsKey(_selectedPeriod)) {
      _state = AnalyticsState.loaded;
      notifyListeners();
      return;
    }

    _state = AnalyticsState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final analytics =
          await _repository.getAnalytics(_turfId!, _selectedPeriod);
      _analyticsCache[_selectedPeriod] = analytics;
      _state = AnalyticsState.loaded;
    } catch (e) {
      _state = AnalyticsState.error;
      _errorMessage = e.toString();
      debugPrint('❌ AnalyticsProvider.fetchAnalytics ERROR: $e');
    }

    notifyListeners();
  }

  void selectPeriod(TimePeriod period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      notifyListeners();
      fetchAnalytics();
    }
  }

  void clearCache() {
    _analyticsCache.clear();
    _yearlyCache.clear();
    notifyListeners();
  }

  // ── Yearly revenue ──────────────────────────────────────────────────────

  final Map<int, YearlyRevenueEntity> _yearlyCache = {};
  YearlyRevenueEntity? yearlyFor(int year) => _yearlyCache[year];

  AnalyticsState _yearlyState = AnalyticsState.initial;
  AnalyticsState get yearlyState => _yearlyState;

  String? _yearlyError;
  String? get yearlyError => _yearlyError;

  /// Returns the cached entity for [year] if present, otherwise fetches.
  Future<YearlyRevenueEntity?> fetchYearly(int year,
      {bool forceRefresh = false}) async {
    if (!_hasTurf) return null;
    if (!forceRefresh && _yearlyCache.containsKey(year)) {
      return _yearlyCache[year];
    }
    _yearlyState = AnalyticsState.loading;
    _yearlyError = null;
    notifyListeners();
    try {
      final result = await _repository.getYearlyRevenue(_turfId!, year);
      _yearlyCache[year] = result;
      _yearlyState = AnalyticsState.loaded;
      notifyListeners();
      return result;
    } catch (e) {
      _yearlyError = e.toString().replaceAll('Exception: ', '');
      _yearlyState = AnalyticsState.error;
      notifyListeners();
      return null;
    }
  }
}
