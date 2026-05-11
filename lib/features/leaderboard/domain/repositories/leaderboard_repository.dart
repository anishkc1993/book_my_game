import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({bool forceRefresh = false});
  Future<DateTime> getLastUpdateTime();
}
