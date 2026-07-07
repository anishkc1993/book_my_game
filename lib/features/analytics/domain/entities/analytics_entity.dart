import 'package:equatable/equatable.dart';

enum TimePeriod { today, week, month, overall }

class DailyMetric extends Equatable {
  final DateTime date;
  final double value;

  const DailyMetric({
    required this.date,
    required this.value,
  });

  @override
  List<Object?> get props => [date, value];
}

class AnalyticsEntity extends Equatable {
  // Revenue Metrics
  final double totalRevenue;
  final double paidRevenue;
  final double pendingRevenue;
  final double averageBookingValue;
  /// Concession (cafe) revenue for the period — tracked separately so it
  /// never inflates the booking revenue figure on the dashboard.
  final double concessionRevenue;
  /// Count of concession sales in the period.
  final int concessionSalesCount;

  // Booking Metrics
  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int cancelledBookings;
  final int completedBookings;
  final double cancellationRate;

  // Customer Metrics
  final int uniqueCustomers;
  final int newCustomers;
  final int repeatCustomers;

  // Utilization Metrics
  final Map<int, int> bookingsByHour;
  final Map<int, int> bookingsByWeekday;
  final double slotUtilizationRate;

  // Trend Data (for charts)
  final List<DailyMetric> dailyRevenue;
  final List<DailyMetric> dailyBookings;

  // Time period
  final TimePeriod period;

  const AnalyticsEntity({
    required this.totalRevenue,
    required this.paidRevenue,
    required this.pendingRevenue,
    required this.averageBookingValue,
    this.concessionRevenue = 0,
    this.concessionSalesCount = 0,
    required this.totalBookings,
    required this.confirmedBookings,
    required this.pendingBookings,
    required this.cancelledBookings,
    required this.completedBookings,
    required this.cancellationRate,
    required this.uniqueCustomers,
    required this.newCustomers,
    required this.repeatCustomers,
    required this.bookingsByHour,
    required this.bookingsByWeekday,
    required this.slotUtilizationRate,
    required this.dailyRevenue,
    required this.dailyBookings,
    required this.period,
  });

  factory AnalyticsEntity.empty(TimePeriod period) {
    return AnalyticsEntity(
      totalRevenue: 0,
      paidRevenue: 0,
      pendingRevenue: 0,
      averageBookingValue: 0,
      totalBookings: 0,
      confirmedBookings: 0,
      pendingBookings: 0,
      cancelledBookings: 0,
      completedBookings: 0,
      cancellationRate: 0,
      uniqueCustomers: 0,
      newCustomers: 0,
      repeatCustomers: 0,
      bookingsByHour: {},
      bookingsByWeekday: {},
      slotUtilizationRate: 0,
      dailyRevenue: [],
      dailyBookings: [],
      period: period,
    );
  }

  // Computed properties
  int get activeBookings => confirmedBookings + pendingBookings;

  @override
  List<Object?> get props => [
        totalRevenue,
        paidRevenue,
        pendingRevenue,
        averageBookingValue,
        concessionRevenue,
        concessionSalesCount,
        totalBookings,
        confirmedBookings,
        pendingBookings,
        cancelledBookings,
        completedBookings,
        cancellationRate,
        uniqueCustomers,
        newCustomers,
        repeatCustomers,
        bookingsByHour,
        bookingsByWeekday,
        slotUtilizationRate,
        dailyRevenue,
        dailyBookings,
        period,
      ];
}
