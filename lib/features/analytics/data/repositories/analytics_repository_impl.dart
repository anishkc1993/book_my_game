import '../../domain/entities/analytics_entity.dart';
import '../../domain/entities/yearly_revenue_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  AnalyticsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period) {
    return remoteDataSource.getAnalytics(turfId, period);
  }

  @override
  Future<YearlyRevenueEntity> getYearlyRevenue(String turfId, int year) {
    return remoteDataSource.getYearlyRevenue(turfId, year);
  }
}
