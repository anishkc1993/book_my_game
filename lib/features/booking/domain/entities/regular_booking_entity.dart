import 'package:equatable/equatable.dart';

class RegularBookingEntity extends Equatable {
  final String? id;
  final String customerName;
  final String userPhone;
  final List<int> daysOfWeek; // 1=Mon … 7=Sun (DateTime.weekday)
  final int startHour; // 0..23
  final double basePrice;
  final DateTime startDate; // first effective date
  final bool isActive;
  final String? notes;
  final String? createdByAdmin;
  final DateTime? createdAt;
  final String? turfId;

  const RegularBookingEntity({
    this.id,
    required this.customerName,
    required this.userPhone,
    required this.daysOfWeek,
    required this.startHour,
    required this.basePrice,
    required this.startDate,
    this.isActive = true,
    this.notes,
    this.createdByAdmin,
    this.createdAt,
    this.turfId,
  });

  /// True if this regular booking covers the given date's weekday and start has begun.
  bool appliesTo(DateTime date) {
    if (!isActive) return false;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (day.isBefore(start)) return false;
    return daysOfWeek.contains(day.weekday);
  }

  String get timeRange {
    final endHour = startHour + 1;
    String fmt(int h) {
      if (h == 0) return '12 AM';
      if (h < 12) return '$h AM';
      if (h == 12) return '12 PM';
      return '${h - 12} PM';
    }

    return '${fmt(startHour)} – ${fmt(endHour)}';
  }

  /// "Mon, Wed, Fri" — sorted by weekday.
  String get daysSummary {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...daysOfWeek]..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  RegularBookingEntity copyWith({
    String? id,
    String? customerName,
    String? userPhone,
    List<int>? daysOfWeek,
    int? startHour,
    double? basePrice,
    DateTime? startDate,
    bool? isActive,
    String? notes,
    String? createdByAdmin,
    DateTime? createdAt,
    String? turfId,
  }) {
    return RegularBookingEntity(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      userPhone: userPhone ?? this.userPhone,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startHour: startHour ?? this.startHour,
      basePrice: basePrice ?? this.basePrice,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      createdAt: createdAt ?? this.createdAt,
      turfId: turfId ?? this.turfId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerName,
        userPhone,
        daysOfWeek,
        startHour,
        basePrice,
        startDate,
        isActive,
        notes,
        createdByAdmin,
        createdAt,
        turfId,
      ];
}
