import '../entities/monthly_plan_entity.dart';

abstract class MonthlyPlanRepository {
  Future<List<MonthlyPlanEntity>> list(String turfId);
  Future<MonthlyPlanEntity> upsert(MonthlyPlanEntity plan);
  Future<void> delete(String turfId, String planId);
  Future<void> setActive(String turfId, String planId, bool isActive);

  /// Mark this plan's fee for [month] (`YYYY-MM`) as paid. Updates
  /// `lastPaidMonth` on the plan and records a payment row.
  Future<void> markPaid({
    required String turfId,
    required String planId,
    required String month,
    required double amount,
    required String markedBy,
  });

  /// Sum of plan payments at [turfId] whose `paidAt` is within
  /// [start, end] (inclusive lower bound, exclusive upper bound). Used by
  /// analytics to fold plan revenue into dashboard totals.
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}
