import '../entities/analytics_entity.dart';
import '../entities/yearly_revenue_entity.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period);

  /// Year-level revenue: month-by-month breakdown plus a YoY delta vs
  /// the previous year's total.
  Future<YearlyRevenueEntity> getYearlyRevenue(String turfId, int year);
}
