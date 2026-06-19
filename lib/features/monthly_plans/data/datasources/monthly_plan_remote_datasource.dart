import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/monthly_plan_model.dart';

abstract class MonthlyPlanRemoteDataSource {
  Future<List<MonthlyPlanModel>> list(String turfId);
  Future<MonthlyPlanModel> upsert(MonthlyPlanModel plan);
  Future<void> delete(String turfId, String planId);
  Future<void> setActive(String turfId, String planId, bool isActive);
  Future<void> markPaid({
    required String turfId,
    required String planId,
    required String month,
    required double amount,
    required String markedBy,
  });
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}

class MonthlyPlanRemoteDataSourceImpl implements MonthlyPlanRemoteDataSource {
  final FirebaseFirestore _firestore;

  MonthlyPlanRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _plansCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('monthly_plans');

  CollectionReference<Map<String, dynamic>> _paymentsCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('monthly_plan_payments');

  @override
  Future<List<MonthlyPlanModel>> list(String turfId) async {
    try {
      final snap = await _plansCol(turfId).get();
      final list =
          snap.docs.map((d) => MonthlyPlanModel.fromFirestore(d)).toList();
      // Stable order regardless of isActive — toggling a plan off should
      // not reshuffle the list. Earliest scheduled hour first, then name.
      list.sort((a, b) {
        if (a.startHour != b.startHour) {
          return a.startHour.compareTo(b.startHour);
        }
        return a.customerName.compareTo(b.customerName);
      });
      return list;
    } catch (e) {
      debugPrint('❌ MonthlyPlan.list: $e');
      throw ServerException('Failed to load monthly plans: ${e.toString()}');
    }
  }

  @override
  Future<MonthlyPlanModel> upsert(MonthlyPlanModel plan) async {
    try {
      if (plan.turfId == null || plan.turfId!.isEmpty) {
        throw const ServerException('Missing turf for monthly plan');
      }
      if (plan.id == null) {
        final ref = await _plansCol(plan.turfId!)
            .add(plan.toFirestore(includeServerTimestamp: true));
        return MonthlyPlanModel(
          id: ref.id,
          customerName: plan.customerName,
          userPhone: plan.userPhone,
          daysOfWeek: plan.daysOfWeek,
          startHours: plan.startHours,
          monthlyFee: plan.monthlyFee,
          startDate: plan.startDate,
          isActive: plan.isActive,
          notes: plan.notes,
          lastPaidMonth: plan.lastPaidMonth,
          createdByAdmin: plan.createdByAdmin,
          createdAt: DateTime.now(),
          turfId: plan.turfId,
        );
      } else {
        await _plansCol(plan.turfId!).doc(plan.id).set(
              plan.toFirestore(),
              SetOptions(merge: true),
            );
        return plan;
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to save monthly plan: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String turfId, String planId) async {
    try {
      await _plansCol(turfId).doc(planId).delete();
    } catch (e) {
      throw ServerException('Failed to delete monthly plan: ${e.toString()}');
    }
  }

  @override
  Future<void> setActive(String turfId, String planId, bool isActive) async {
    try {
      await _plansCol(turfId).doc(planId).update({'isActive': isActive});
    } catch (e) {
      throw ServerException(
          'Failed to update monthly plan: ${e.toString()}');
    }
  }

  @override
  Future<void> markPaid({
    required String turfId,
    required String planId,
    required String month,
    required double amount,
    required String markedBy,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_plansCol(turfId).doc(planId), {
        'lastPaidMonth': month,
      });
      batch.set(_paymentsCol(turfId).doc(), {
        'planId': planId,
        'month': month,
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
        'markedBy': markedBy,
      });
      await batch.commit();
    } catch (e) {
      throw ServerException(
          'Failed to mark monthly plan paid: ${e.toString()}');
    }
  }

  @override
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snap = await _paymentsCol(turfId)
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0;
        total += amount;
      }
      return total;
    } catch (e) {
      debugPrint('❌ MonthlyPlan.sumPaymentsBetween: $e');
      return 0;
    }
  }
}
