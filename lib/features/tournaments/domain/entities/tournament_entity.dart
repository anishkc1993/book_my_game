import 'package:equatable/equatable.dart';

/// A multi-day tournament that reserves a fixed hour-range on each
/// scheduled day. Tournament hours take precedence over normal bookings,
/// regulars and monthly plans — the day view suppresses anything that
/// overlaps the tournament window.
class TournamentEntity extends Equatable {
  final String? id;
  final String name;
  final String organizerName;
  final String organizerPhone;
  /// Each day the tournament runs (midnight-normalized).
  final List<DateTime> dates;
  /// Start hour (0..23) — e.g. 8 for 8 AM.
  final int startHour;
  /// End hour (1..24) — exclusive boundary. 17 means slots up to 4-5 PM
  /// inclusive; if you want "8 to 5 PM" coverage, end=17 (5 PM marker).
  final int endHour;
  final double totalAmount;
  final bool isPaid;
  final double? amountPaid;
  final DateTime? paidAt;
  final String? notes;
  final String? createdByAdmin;
  final DateTime? createdAt;
  final String? turfId;

  const TournamentEntity({
    this.id,
    required this.name,
    required this.organizerName,
    required this.organizerPhone,
    required this.dates,
    required this.startHour,
    required this.endHour,
    required this.totalAmount,
    this.isPaid = false,
    this.amountPaid,
    this.paidAt,
    this.notes,
    this.createdByAdmin,
    this.createdAt,
    this.turfId,
  });

  bool appliesTo(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return dates.any(
      (x) => x.year == d.year && x.month == d.month && x.day == d.day,
    );
  }

  /// Whether [hour] falls inside the tournament's reserved window.
  bool overlapsHour(int hour) => hour >= startHour && hour < endHour;

  String _fmtHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String get timeRange => '${_fmtHour(startHour)} – ${_fmtHour(endHour)}';

  int get totalHours => endHour - startHour;

  /// Human "Mon 14 Aug, Tue 15 Aug" or "Aug 14 → Aug 16" when the dates
  /// are contiguous.
  String get datesSummary {
    if (dates.isEmpty) return '';
    final sorted = [...dates]..sort();
    // Detect contiguous range.
    bool contiguous = true;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff != 1) {
        contiguous = false;
        break;
      }
    }
    String fmt(DateTime d) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}';
    }
    if (contiguous && sorted.length > 1) {
      return '${fmt(sorted.first)} → ${fmt(sorted.last)}';
    }
    return sorted.map(fmt).join(', ');
  }

  TournamentEntity copyWith({
    String? id,
    String? name,
    String? organizerName,
    String? organizerPhone,
    List<DateTime>? dates,
    int? startHour,
    int? endHour,
    double? totalAmount,
    bool? isPaid,
    double? amountPaid,
    DateTime? paidAt,
    String? notes,
    String? createdByAdmin,
    DateTime? createdAt,
    String? turfId,
  }) {
    return TournamentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      organizerName: organizerName ?? this.organizerName,
      organizerPhone: organizerPhone ?? this.organizerPhone,
      dates: dates ?? this.dates,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      totalAmount: totalAmount ?? this.totalAmount,
      isPaid: isPaid ?? this.isPaid,
      amountPaid: amountPaid ?? this.amountPaid,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      createdAt: createdAt ?? this.createdAt,
      turfId: turfId ?? this.turfId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        organizerName,
        organizerPhone,
        dates,
        startHour,
        endHour,
        totalAmount,
        isPaid,
        amountPaid,
        paidAt,
        notes,
        createdByAdmin,
        createdAt,
        turfId,
      ];
}
