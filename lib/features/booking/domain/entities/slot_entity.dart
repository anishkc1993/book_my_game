import 'package:equatable/equatable.dart';

enum SlotStatus {
  available('AVAILABLE'),
  booked('BOOKED'),
  blocked('BLOCKED'),
  unavailable('UNAVAILABLE'), // For past time slots
  played('PLAYED'); // Past + was booked — game is already done

  final String value;
  const SlotStatus(this.value);

  static SlotStatus fromString(String? value) {
    return SlotStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SlotStatus.available,
    );
  }
}

class SlotEntity extends Equatable {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final SlotStatus status;
  final String? bookedByUserId;
  final String? bookingId;

  const SlotEntity({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.status = SlotStatus.available,
    this.bookedByUserId,
    this.bookingId,
  });

  bool get isAvailable => status == SlotStatus.available;
  bool get isBooked => status == SlotStatus.booked;
  bool get isBlocked => status == SlotStatus.blocked;
  bool get isUnavailable => status == SlotStatus.unavailable;
  bool get isPast => status == SlotStatus.unavailable; // Alias for clarity
  bool get isPlayed => status == SlotStatus.played;

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
  List<Object?> get props => [id, startTime, endTime, status, bookedByUserId, bookingId];
}
