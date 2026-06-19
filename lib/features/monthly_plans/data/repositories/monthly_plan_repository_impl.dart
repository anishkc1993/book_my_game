import '../../domain/entities/monthly_plan_entity.dart';
import '../../domain/repositories/monthly_plan_repository.dart';
import '../datasources/monthly_plan_remote_datasource.dart';
import '../models/monthly_plan_model.dart';

class MonthlyPlanRepositoryImpl implements MonthlyPlanRepository {
  final MonthlyPlanRemoteDataSource remoteDataSource;
  MonthlyPlanRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<MonthlyPlanEntity>> list(String turfId) async {
    final models = await remoteDataSource.list(turfId);
    // The datasource returns List<MonthlyPlanModel>. We need a true
    // List<MonthlyPlanEntity> so the provider can put plain entities
    // (e.g., from copyWith) back into the same list without a runtime
    // type-mismatch ("Entity is not a subtype of Model").
    return List<MonthlyPlanEntity>.from(models);
  }

  @override
  Future<MonthlyPlanEntity> upsert(MonthlyPlanEntity plan) =>
      remoteDataSource.upsert(MonthlyPlanModel.fromEntity(plan));

  @override
  Future<void> delete(String turfId, String planId) =>
      remoteDataSource.delete(turfId, planId);

  @override
  Future<void> setActive(String turfId, String planId, bool isActive) =>
      remoteDataSource.setActive(turfId, planId, isActive);

  @override
  Future<void> markPaid({
    required String turfId,
    required String planId,
    required String month,
    required double amount,
    required String markedBy,
  }) =>
      remoteDataSource.markPaid(
        turfId: turfId,
        planId: planId,
        month: month,
        amount: amount,
        markedBy: markedBy,
      );

  @override
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) =>
      remoteDataSource.sumPaymentsBetween(
        turfId: turfId,
        start: start,
        end: end,
      );
}
