import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Get the monthly leaderboard for a specific turf.
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({
    required String turfId,
    bool forceRefresh = false,
  });
  Future<DateTime> getLastUpdateTime();

  /// Merge one or more `sourcePhones` into `targetPhone` so all bookings
  /// for the same customer consolidate into a single leaderboard entry.
  /// Returns the count of documents updated.
  Future<int> mergePhoneNumbers({
    required String turfId,
    required List<String> sourcePhones,
    required String targetPhone,
  });

  /// Persist a display-name override for [phone].
  Future<void> setNameOverride({
    required String turfId,
    required String phone,
    required String name,
  });
}
