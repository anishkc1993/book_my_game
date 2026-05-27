import 'package:flutter/foundation.dart';

import '../../domain/entities/analytics_entity.dart';
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
    notifyListeners();
  }
}
