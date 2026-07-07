import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/monthly_plan_entity.dart';

class MonthlyPlanModel extends MonthlyPlanEntity {
  const MonthlyPlanModel({
    super.id,
    required super.customerName,
    required super.userPhone,
    required super.daysOfWeek,
    required super.startHours,
    required super.monthlyFee,
    required super.startDate,
    super.endDate,
    super.isActive = true,
    super.notes,
    super.lastPaidMonth,
    super.createdByAdmin,
    super.createdAt,
    super.turfId,
  });

  factory MonthlyPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Prefer the new multi-hour field; fall back to the legacy singular
    // `startHour` so plans created before the multi-hour migration still
    // render correctly.
    List<int> hours;
    final rawHours = data['startHours'];
    if (rawHours is List && rawHours.isNotEmpty) {
      hours = rawHours.map((e) => (e as num).toInt()).toList();
    } else {
      final single = (data['startHour'] as num?)?.toInt();
      hours = single == null ? const [] : [single];
    }
    return MonthlyPlanModel(
      id: doc.id,
      customerName: data['customerName'] as String? ?? '',
      userPhone: data['userPhone'] as String? ?? '',
      daysOfWeek:
          (data['daysOfWeek'] as List<dynamic>?)?.cast<int>() ?? const [],
      startHours: hours,
      monthlyFee: (data['monthlyFee'] as num?)?.toDouble() ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      notes: data['notes'] as String?,
      lastPaidMonth: data['lastPaidMonth'] as String?,
      createdByAdmin: data['createdByAdmin'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      turfId: data['turfId'] as String?,
    );
  }

  factory MonthlyPlanModel.fromEntity(MonthlyPlanEntity e) {
    return MonthlyPlanModel(
      id: e.id,
      customerName: e.customerName,
      userPhone: e.userPhone,
      daysOfWeek: e.daysOfWeek,
      startHours: e.startHours,
      monthlyFee: e.monthlyFee,
      startDate: e.startDate,
      endDate: e.endDate,
      isActive: e.isActive,
      notes: e.notes,
      lastPaidMonth: e.lastPaidMonth,
      createdByAdmin: e.createdByAdmin,
      createdAt: e.createdAt,
      turfId: e.turfId,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final sortedHours = [...startHours]..sort();
    final map = <String, dynamic>{
      'customerName': customerName,
      'userPhone': userPhone,
      'daysOfWeek': daysOfWeek,
      'startHours': sortedHours,
      // Also keep `startHour` populated with the first hour for backwards
      // compatibility with any read path that hasn't migrated yet.
      'startHour': sortedHours.isEmpty ? 0 : sortedHours.first,
      'monthlyFee': monthlyFee,
      'startDate': Timestamp.fromDate(
          DateTime(startDate.year, startDate.month, startDate.day)),
      'endDate': endDate != null
          ? Timestamp.fromDate(
              DateTime(endDate!.year, endDate!.month, endDate!.day))
          : null,
      'isActive': isActive,
      'notes': notes,
      'lastPaidMonth': lastPaidMonth,
      'createdByAdmin': createdByAdmin,
      'turfId': turfId,
    };
    if (includeServerTimestamp) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}
