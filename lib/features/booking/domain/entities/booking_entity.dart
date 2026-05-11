import 'package:equatable/equatable.dart';

enum BookingStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromString(String? value) {
    return BookingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingStatus.pending,
    );
  }
}

class BookingEntity extends Equatable {
  final String? id;
  final String userId;
  final String userPhone;
  final String? customerName; // For walk-in customers
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String? remarks;
  final BookingStatus status;
  final bool isPaid;
  final double? amountPaid;
  final DateTime? paidAt;
  final String? createdByAdmin; // Admin UID if created by admin
  final DateTime? createdAt;

  const BookingEntity({
    this.id,
    required this.userId,
    required this.userPhone,
    this.customerName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.remarks,
    this.status = BookingStatus.pending,
    this.isPaid = false,
    this.amountPaid,
    this.paidAt,
    this.createdByAdmin,
    this.createdAt,
  });

  bool get isPending => status == BookingStatus.pending;
  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isCancelled => status == BookingStatus.cancelled;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isAdminBooking => createdByAdmin != null;

  String get timeRange {
    final startHour = startTime.hour;
    final endHour = endTime.hour;
    final startPeriod = startHour >= 12 ? 'PM' : 'AM';
    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final displayStartHour = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour);
    final displayEndHour = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
    return '$displayStartHour $startPeriod - $displayEndHour $endPeriod';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userPhone,
        customerName,
        date,
        startTime,
        endTime,
        remarks,
        status,
        isPaid,
        amountPaid,
        paidAt,
        createdByAdmin,
        createdAt,
      ];
}
