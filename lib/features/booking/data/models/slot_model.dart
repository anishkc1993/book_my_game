import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/slot_entity.dart';

class SlotModel extends SlotEntity {
  const SlotModel({
    required super.id,
    required super.startTime,
    required super.endTime,
    super.status,
    super.bookedByUserId,
    super.bookingId,
  });

  /// Create a slot model for a specific hour on a date
  factory SlotModel.forHour(DateTime date, int hour) {
    final startTime = DateTime(date.year, date.month, date.day, hour);
    final endTime = DateTime(date.year, date.month, date.day, hour + 1);
    final id = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${hour.toString().padLeft(2, '0')}';

    return SlotModel(
      id: id,
      startTime: startTime,
      endTime: endTime,
      status: SlotStatus.available,
    );
  }

  /// Generate all slots for a date (6 AM to 8 PM = 14 slots)
  static List<SlotModel> generateSlotsForDate(DateTime date) {
    final slots = <SlotModel>[];
    for (int hour = 6; hour < 20; hour++) {
      slots.add(SlotModel.forHour(date, hour));
    }
    return slots;
  }

  factory SlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SlotModel(
      id: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: SlotStatus.fromString(data['status'] as String?),
      bookedByUserId: data['bookedByUserId'] as String?,
      bookingId: data['bookingId'] as String?,
    );
  }

  factory SlotModel.fromEntity(SlotEntity entity) {
    return SlotModel(
      id: entity.id,
      startTime: entity.startTime,
      endTime: entity.endTime,
      status: entity.status,
      bookedByUserId: entity.bookedByUserId,
      bookingId: entity.bookingId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.value,
      'bookedByUserId': bookedByUserId,
      'bookingId': bookingId,
    };
  }

  SlotModel copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    SlotStatus? status,
    String? bookedByUserId,
    String? bookingId,
  }) {
    return SlotModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      bookingId: bookingId ?? this.bookingId,
    );
  }
}
