import 'package:equatable/equatable.dart';

class MonthlyRevenue extends Equatable {
  final int month; // 1..12
  final double revenue;
  final int bookings;

  const MonthlyRevenue({
    required this.month,
    required this.revenue,
    required this.bookings,
  });

  @override
  List<Object?> get props => [month, revenue, bookings];
}

/// Year-level analytics aggregate. Holds twelve [MonthlyRevenue] entries
/// (Jan..Dec, zero-filled for months with no activity) plus convenience
/// totals + a year-over-year delta vs [previousYearRevenue].
class YearlyRevenueEntity extends Equatable {
  final int year;
  final double totalRevenue;
  final int totalBookings;
  final List<MonthlyRevenue> monthly;
  final double? previousYearRevenue;

  const YearlyRevenueEntity({
    required this.year,
    required this.totalRevenue,
    required this.totalBookings,
    required this.monthly,
    this.previousYearRevenue,
  });

  factory YearlyRevenueEntity.empty(int year) => YearlyRevenueEntity(
        year: year,
        totalRevenue: 0,
        totalBookings: 0,
        monthly: List.generate(
          12,
          (i) => MonthlyRevenue(month: i + 1, revenue: 0, bookings: 0),
        ),
        previousYearRevenue: null,
      );

  bool get isCurrentYear => year == DateTime.now().year;

  /// Average across the months we count toward — for the current year we
  /// average over completed months (so YTD doesn't get diluted by the
  /// zero-revenue months still ahead).
  double get averageMonthly {
    final monthsCounted = isCurrentYear
        ? DateTime.now().month.clamp(1, 12)
        : 12;
    if (monthsCounted == 0) return 0;
    return totalRevenue / monthsCounted;
  }

  MonthlyRevenue? get bestMonth {
    if (monthly.isEmpty) return null;
    MonthlyRevenue? best;
    for (final m in monthly) {
      if (m.revenue <= 0) continue;
      if (best == null || m.revenue > best.revenue) best = m;
    }
    return best;
  }

  /// Year-over-year percentage change. Null when there's no prior year
  /// data to compare against.
  double? get yoyChangePercent {
    final prev = previousYearRevenue;
    if (prev == null || prev <= 0) return null;
    return ((totalRevenue - prev) / prev) * 100;
  }

  @override
  List<Object?> get props => [
        year,
        totalRevenue,
        totalBookings,
        monthly,
        previousYearRevenue,
      ];
}
