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
      var plans =
          snap.docs.map((d) => MonthlyPlanModel.fromFirestore(d)).toList();

      // Auto-expire plans whose endDate has passed: deactivate them and
      // clear lastPaidMonth so they show as unpaid (no new month payment
      // is expected from an expired plan).
      final today = DateTime.now();
      final expiredIds = <String>[];
      plans = plans.map((plan) {
        if (!plan.isActive) return plan;
        if (plan.endDate == null) return plan;
        final end = DateTime(
            plan.endDate!.year, plan.endDate!.month, plan.endDate!.day);
        if (!today.isAfter(end)) return plan;
        expiredIds.add(plan.id!);
        return MonthlyPlanModel(
          id: plan.id,
          customerName: plan.customerName,
          userPhone: plan.userPhone,
          daysOfWeek: plan.daysOfWeek,
          startHours: plan.startHours,
          monthlyFee: plan.monthlyFee,
          startDate: plan.startDate,
          endDate: plan.endDate,
          isActive: false,
          lastPaidMonth: null, // reset so it shows unpaid
          notes: plan.notes,
          createdByAdmin: plan.createdByAdmin,
          createdAt: plan.createdAt,
          turfId: plan.turfId,
        );
      }).toList();

      if (expiredIds.isNotEmpty) {
        final batch = _firestore.batch();
        for (final id in expiredIds) {
          batch.update(_plansCol(turfId).doc(id), {
            'isActive': false,
            'lastPaidMonth': null,
          });
        }
        await batch.commit();
        debugPrint(
            '📅 MonthlyPlan.list: auto-expired ${expiredIds.length} plan(s)');
      }

      // Stable order regardless of isActive.
      plans.sort((a, b) {
        if (a.startHour != b.startHour) {
          return a.startHour.compareTo(b.startHour);
        }
        return a.customerName.compareTo(b.customerName);
      });
      return plans;
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
      // If the endDate is already in the past, mark the plan inactive and
      // clear payment so it doesn't appear as overdue for a new month.
      MonthlyPlanModel effective = plan;
      if (plan.endDate != null) {
        final today = DateTime.now();
        final end = DateTime(
            plan.endDate!.year, plan.endDate!.month, plan.endDate!.day);
        if (today.isAfter(end)) {
          effective = MonthlyPlanModel(
            id: plan.id,
            customerName: plan.customerName,
            userPhone: plan.userPhone,
            daysOfWeek: plan.daysOfWeek,
            startHours: plan.startHours,
            monthlyFee: plan.monthlyFee,
            startDate: plan.startDate,
            endDate: plan.endDate,
            isActive: false,
            lastPaidMonth: null,
            notes: plan.notes,
            createdByAdmin: plan.createdByAdmin,
            createdAt: plan.createdAt,
            turfId: plan.turfId,
          );
        }
      }
      if (effective.id == null) {
        final ref = await _plansCol(effective.turfId!)
            .add(effective.toFirestore(includeServerTimestamp: true));
        return MonthlyPlanModel(
          id: ref.id,
          customerName: effective.customerName,
          userPhone: effective.userPhone,
          daysOfWeek: effective.daysOfWeek,
          startHours: effective.startHours,
          monthlyFee: effective.monthlyFee,
          startDate: effective.startDate,
          endDate: effective.endDate,
          isActive: effective.isActive,
          notes: effective.notes,
          lastPaidMonth: effective.lastPaidMonth,
          createdByAdmin: effective.createdByAdmin,
          createdAt: DateTime.now(),
          turfId: effective.turfId,
        );
      } else {
        await _plansCol(effective.turfId!).doc(effective.id).set(
              effective.toFirestore(),
              SetOptions(merge: true),
            );
        return effective;
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
      // Deterministic doc ID — double-tapping just overwrites the same
      // record instead of creating a duplicate payment entry.
      final paymentDocId = '${planId}_$month';
      batch.set(_paymentsCol(turfId).doc(paymentDocId), {
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
