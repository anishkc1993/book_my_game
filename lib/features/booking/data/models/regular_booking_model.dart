import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/regular_booking_entity.dart';

class RegularBookingModel extends RegularBookingEntity {
  const RegularBookingModel({
    super.id,
    required super.customerName,
    required super.userPhone,
    required super.daysOfWeek,
    required super.startHour,
    required super.basePrice,
    required super.startDate,
    super.isActive,
    super.notes,
    super.createdByAdmin,
    super.createdAt,
    super.turfId,
  });

  factory RegularBookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegularBookingModel(
      id: doc.id,
      customerName: data['customerName'] as String,
      userPhone: data['userPhone'] as String,
      daysOfWeek: (data['daysOfWeek'] as List<dynamic>).cast<int>(),
      startHour: data['startHour'] as int,
      basePrice: (data['basePrice'] as num).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool? ?? true,
      notes: data['notes'] as String?,
      createdByAdmin: data['createdByAdmin'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      turfId: data['turfId'] as String?,
    );
  }

  factory RegularBookingModel.fromEntity(RegularBookingEntity entity) {
    return RegularBookingModel(
      id: entity.id,
      customerName: entity.customerName,
      userPhone: entity.userPhone,
      daysOfWeek: entity.daysOfWeek,
      startHour: entity.startHour,
      basePrice: entity.basePrice,
      startDate: entity.startDate,
      isActive: entity.isActive,
      notes: entity.notes,
      createdByAdmin: entity.createdByAdmin,
      createdAt: entity.createdAt,
      turfId: entity.turfId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'userPhone': userPhone,
      'daysOfWeek': daysOfWeek,
      'startHour': startHour,
      'basePrice': basePrice,
      'startDate': Timestamp.fromDate(startDate),
      'isActive': isActive,
      'notes': notes,
      'createdByAdmin': createdByAdmin,
      'turfId': turfId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
