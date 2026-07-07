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
  final double? basePrice; // Auto-calculated price based on time period
  final double? amountPaid;
  final DateTime? paidAt;
  final String? createdByAdmin; // Admin UID if created by admin
  final DateTime? createdAt;
  // Synthesized from a recurring/regular booking template — not persisted.
  final bool isRegular;
  // When isRegular is true, the source regular booking's id.
  final String? regularBookingId;
  // Synthesized from a monthly subscription plan — not persisted.
  final bool isMonthlyPlan;
  // When isMonthlyPlan is true, the source plan's id.
  final String? monthlyPlanId;
  // Synthesized from a tournament booking — not persisted.
  final bool isTournament;
  // When isTournament is true, the source tournament's id.
  final String? tournamentId;
  // Tournament title (organizer-provided), used only for display.
  final String? tournamentName;
  // Multi-tenant: which turf this booking belongs to.
  final String? turfId;
  /// True when admin claimed a free game on this booking. Such bookings
  /// have `amountPaid == 0`, do NOT count toward the leaderboard, and
  /// do NOT count toward the next reward cycle for the customer.
  final bool isFreeGame;

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
    this.basePrice,
    this.amountPaid,
    this.paidAt,
    this.createdByAdmin,
    this.createdAt,
    this.isRegular = false,
    this.regularBookingId,
    this.isMonthlyPlan = false,
    this.monthlyPlanId,
    this.isTournament = false,
    this.tournamentId,
    this.tournamentName,
    this.turfId,
    this.isFreeGame = false,
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
        basePrice,
        amountPaid,
        paidAt,
        createdByAdmin,
        createdAt,
        isRegular,
        regularBookingId,
        isMonthlyPlan,
        monthlyPlanId,
        isTournament,
        tournamentId,
        tournamentName,
        turfId,
        isFreeGame,
      ];
}
