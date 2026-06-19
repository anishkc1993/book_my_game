import 'package:equatable/equatable.dart';

/// A monthly subscription plan: customer plays a fixed weekly schedule
/// (e.g., Mon/Wed/Fri at 7 AM) for a flat monthly fee.
///
/// Differences from [RegularBookingEntity]:
///   - Pricing is per-MONTH (not per-session).
///   - Tracked via [lastPaidMonth]; revenue is recognized when admin marks
///     a month paid, not per session.
///   - Plan sessions are surfaced as synthetic bookings in today's pitch
///     but never persisted to the bookings collection — so they are
///     intentionally excluded from the leaderboard.
class MonthlyPlanEntity extends Equatable {
  final String? id;
  final String customerName;
  final String userPhone;
  final List<int> daysOfWeek; // 1=Mon … 7=Sun
  /// Hours the plan reserves on each scheduled day (e.g., [8, 18] means
  /// 8 AM AND 6 PM blocks every matching weekday). Must contain at least
  /// one entry. Values are 0..23 (slot start hour).
  final List<int> startHours;
  final double monthlyFee;
  final DateTime startDate; // first effective day
  final bool isActive;
  final String? notes;
  /// Most recent paid month, `YYYY-MM`. Null/empty means never paid.
  final String? lastPaidMonth;
  final String? createdByAdmin;
  final DateTime? createdAt;
  final String? turfId;

  const MonthlyPlanEntity({
    this.id,
    required this.customerName,
    required this.userPhone,
    required this.daysOfWeek,
    required this.startHours,
    required this.monthlyFee,
    required this.startDate,
    this.isActive = true,
    this.notes,
    this.lastPaidMonth,
    this.createdByAdmin,
    this.createdAt,
    this.turfId,
  });

  /// Legacy single-hour shim — returns the first scheduled hour for code
  /// paths that haven't migrated to [startHours] yet. Returns 0 if empty.
  int get startHour => startHours.isEmpty ? 0 : startHours.first;

  bool appliesTo(DateTime date) {
    if (!isActive) return false;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (day.isBefore(start)) return false;
    return daysOfWeek.contains(day.weekday);
  }

  String _fmt(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  /// Comma-separated list of scheduled hour blocks, e.g. "8 AM, 6 PM".
  /// Falls back to a single block string when only one hour is set.
  String get timeRange {
    if (startHours.isEmpty) return '';
    final sorted = [...startHours]..sort();
    if (sorted.length == 1) {
      return '${_fmt(sorted.first)} – ${_fmt(sorted.first + 1)}';
    }
    return sorted.map(_fmt).join(', ');
  }

  String get daysSummary {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...daysOfWeek]..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  bool isPaidFor(String month) =>
      lastPaidMonth != null && lastPaidMonth == month;

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  MonthlyPlanEntity copyWith({
    String? id,
    String? customerName,
    String? userPhone,
    List<int>? daysOfWeek,
    List<int>? startHours,
    double? monthlyFee,
    DateTime? startDate,
    bool? isActive,
    String? notes,
    String? lastPaidMonth,
    String? createdByAdmin,
    DateTime? createdAt,
    String? turfId,
  }) {
    return MonthlyPlanEntity(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      userPhone: userPhone ?? this.userPhone,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startHours: startHours ?? this.startHours,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      lastPaidMonth: lastPaidMonth ?? this.lastPaidMonth,
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
        startHours,
        monthlyFee,
        startDate,
        isActive,
        notes,
        lastPaidMonth,
        createdByAdmin,
        createdAt,
        turfId,
      ];
}
