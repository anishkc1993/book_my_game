import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
  const BookingModel({
    super.id,
    required super.userId,
    required super.userPhone,
    super.customerName,
    required super.date,
    required super.startTime,
    required super.endTime,
    super.remarks,
    super.status,
    super.isPaid,
    super.amountPaid,
    super.paidAt,
    super.createdByAdmin,
    super.createdAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] as String,
      userPhone: data['userPhone'] as String,
      customerName: data['customerName'] as String?,
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      remarks: data['remarks'] as String?,
      status: BookingStatus.fromString(data['status'] as String?),
      isPaid: data['isPaid'] as bool? ?? false,
      amountPaid: (data['amountPaid'] as num?)?.toDouble(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      createdByAdmin: data['createdByAdmin'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory BookingModel.fromEntity(BookingEntity entity) {
    return BookingModel(
      id: entity.id,
      userId: entity.userId,
      userPhone: entity.userPhone,
      customerName: entity.customerName,
      date: entity.date,
      startTime: entity.startTime,
      endTime: entity.endTime,
      remarks: entity.remarks,
      status: entity.status,
      isPaid: entity.isPaid,
      amountPaid: entity.amountPaid,
      paidAt: entity.paidAt,
      createdByAdmin: entity.createdByAdmin,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    // Create a dateKey for easy querying without composite index
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return {
      'userId': userId,
      'userPhone': userPhone,
      'customerName': customerName,
      'date': Timestamp.fromDate(date),
      'dateKey': dateKey, // For querying by date
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'remarks': remarks,
      'status': status.value,
      'isPaid': isPaid,
      'amountPaid': amountPaid,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'createdByAdmin': createdByAdmin,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? userPhone,
    String? customerName,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? remarks,
    BookingStatus? status,
    bool? isPaid,
    double? amountPaid,
    DateTime? paidAt,
    String? createdByAdmin,
    DateTime? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userPhone: userPhone ?? this.userPhone,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      amountPaid: amountPaid ?? this.amountPaid,
      paidAt: paidAt ?? this.paidAt,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
