import '../entities/analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period);
}
