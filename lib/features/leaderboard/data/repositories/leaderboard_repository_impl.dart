import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remoteDataSource;

  LeaderboardRepositoryImpl({required LeaderboardRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({bool forceRefresh = false}) async {
    return await _remoteDataSource.getMonthlyLeaderboard(forceRefresh: forceRefresh);
  }

  @override
  Future<DateTime> getLastUpdateTime() async {
    return await _remoteDataSource.getLastUpdateTime();
  }
}
