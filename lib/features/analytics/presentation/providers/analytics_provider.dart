import 'package:flutter/foundation.dart';

import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';

enum AnalyticsState { initial, loading, loaded, error }

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsRepository _repository;

  AnalyticsProvider({required AnalyticsRepository repository})
      : _repository = repository;

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
    // Return cached data if available and not forcing refresh
    if (!forceRefresh && _analyticsCache.containsKey(_selectedPeriod)) {
      _state = AnalyticsState.loaded;
      notifyListeners();
      return;
    }

    _state = AnalyticsState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final analytics = await _repository.getAnalytics(_selectedPeriod);
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
