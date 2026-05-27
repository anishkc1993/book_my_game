import 'package:flutter/material.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

enum LeaderboardState { initial, loading, loaded, error }

class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardRepository _repository;

  LeaderboardProvider({required LeaderboardRepository repository})
      : _repository = repository;

  // Multi-tenant: current turf scope (set via app glue from AuthProvider).
  String? _turfId;
  String? get turfId => _turfId;

  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _entries = [];
    _state = LeaderboardState.initial;
    _errorMessage = null;
    notifyListeners();
    if (newTurfId != null && newTurfId.isNotEmpty) {
      // Refresh leaderboard data for the new turf.
      fetchLeaderboard();
    }
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

  LeaderboardState _state = LeaderboardState.initial;
  LeaderboardState get state => _state;

  List<LeaderboardEntry> _entries = [];
  List<LeaderboardEntry> get entries => _entries;

  DateTime? _lastUpdate;
  DateTime? get lastUpdate => _lastUpdate;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Month name for display
  String get monthRangeDisplay {
    if (_entries.isEmpty) return '';
    final entry = _entries.first;
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[entry.monthStart.month - 1]} ${entry.monthStart.year}';
  }

  /// Fetch monthly leaderboard
  Future<void> fetchLeaderboard({bool forceRefresh = false}) async {
    if (!_hasTurf) return;
    _state = LeaderboardState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _entries = await _repository.getMonthlyLeaderboard(
        turfId: _turfId!,
        forceRefresh: forceRefresh,
      );
      _lastUpdate = await _repository.getLastUpdateTime();
      _state = LeaderboardState.loaded;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = LeaderboardState.error;
    }

    notifyListeners();
  }

  Future<void> refresh() => fetchLeaderboard(forceRefresh: true);

  String getMedalForRank(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  String get lastUpdateDisplay {
    if (_lastUpdate == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(_lastUpdate!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
