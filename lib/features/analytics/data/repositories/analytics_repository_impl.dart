import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  AnalyticsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AnalyticsEntity> getAnalytics(TimePeriod period) {
    return remoteDataSource.getAnalytics(period);
  }
}
