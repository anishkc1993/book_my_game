import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Get the monthly leaderboard for a specific turf.
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({
    required String turfId,
    bool forceRefresh = false,
  });
  Future<DateTime> getLastUpdateTime();
}
