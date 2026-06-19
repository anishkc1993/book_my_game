import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remoteDataSource;

  LeaderboardRepositoryImpl({required LeaderboardRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({
    required String turfId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getMonthlyLeaderboard(
      turfId: turfId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<DateTime> getLastUpdateTime() => _remoteDataSource.getLastUpdateTime();

  @override
  Future<int> mergePhoneNumbers({
    required String turfId,
    required List<String> sourcePhones,
    required String targetPhone,
  }) {
    return _remoteDataSource.mergePhoneNumbers(
      turfId: turfId,
      sourcePhones: sourcePhones,
      targetPhone: targetPhone,
    );
  }
}
