import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/entities/yearly_revenue_entity.dart';

abstract class AnalyticsRemoteDataSource {
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period);
  Future<YearlyRevenueEntity> getYearlyRevenue(String turfId, int year);
}

class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  AnalyticsRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Sum of monthly_plan_payments at [turfId] with `paidAt` in [start, end).
  Future<double> _sumPlanPayments(
      String turfId, DateTime start, DateTime end) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('monthly_plan_payments')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('⚠️ _sumPlanPayments failed: $e');
      return 0;
    }
  }

  /// Concession sales total + count in the period. Returned as a record
  /// so the analytics card can show "Rs. X across N sales" in one query.
  Future<({double total, int count})> _sumConcessionSales(
      String turfId, DateTime start, DateTime end) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('concession_sales')
          .where('soldAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('soldAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      return (total: total, count: snap.docs.length);
    } catch (e) {
      debugPrint('⚠️ _sumConcessionSales failed: $e');
      return (total: 0.0, count: 0);
    }
  }

  /// Sum of tournament_payments at [turfId] with `paidAt` in [start, end).
  Future<double> _sumTournamentPayments(
      String turfId, DateTime start, DateTime end) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('tournament_payments')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('⚠️ _sumTournamentPayments failed: $e');
      return 0;
    }
  }

  /// Anchored week boundaries: Sunday → Saturday. Today is Sunday →
  /// window is just Sunday. Today is Saturday → window is Sun..Sat.
  /// [DateTime.sunday] = 7, weekdays 1..7 Mon..Sun.
  DateTime _currentWeekStart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceSunday = (today.weekday - DateTime.sunday + 7) % 7;
    return today.subtract(Duration(days: daysSinceSunday));
  }

  ({DateTime start, DateTime end}) _rangeForPeriod(TimePeriod period) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    switch (period) {
      case TimePeriod.today:
        return (
          start: DateTime(now.year, now.month, now.day),
          end: endOfToday
        );
      case TimePeriod.week:
        return (start: _currentWeekStart(now), end: endOfToday);
      case TimePeriod.month:
        return (
          start: endOfToday.subtract(const Duration(days: 30)),
          end: endOfToday
        );
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<String> _getDateKeysForPeriod(TimePeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case TimePeriod.today:
        return [_getDateKey(today)];
      case TimePeriod.week:
        // Anchored week: from this Sunday (inclusive) up to today.
        // Resets to a single day when the new week starts (Sunday).
        final weekStart = _currentWeekStart(now);
        final days = today.difference(weekStart).inDays + 1;
        return List.generate(
          days,
          (i) => _getDateKey(weekStart.add(Duration(days: i))),
        );
      case TimePeriod.month:
        return List.generate(
          30,
          (i) => _getDateKey(today.subtract(Duration(days: i))),
        );
    }
  }

  @override
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period) async {
    try {
      debugPrint('📊 getAnalytics: turf=$turfId period=$period');

      final dateKeys = _getDateKeysForPeriod(period);
      final bookings = await _fetchBookingsForDateKeys(turfId, dateKeys);

      // Plan + tournament payments received in this period also count.
      final range = _rangeForPeriod(period);
      final planRevenue =
          await _sumPlanPayments(turfId, range.start, range.end);
      final tournamentRevenue =
          await _sumTournamentPayments(turfId, range.start, range.end);
      // Concession sales — tracked separately, NOT added to booking total.
      final concession =
          await _sumConcessionSales(turfId, range.start, range.end);

      debugPrint(
          '📊 getAnalytics: ${bookings.length} bookings, plan=$planRevenue, tournament=$tournamentRevenue, concession=${concession.total} (${concession.count} sales)');

      return _calculateAnalytics(
          bookings, period, dateKeys,
          planRevenue: planRevenue + tournamentRevenue,
          concessionRevenue: concession.total,
          concessionSalesCount: concession.count);
    } catch (e) {
      debugPrint('❌ getAnalytics ERROR: $e');
      return AnalyticsEntity.empty(period);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBookingsForDateKeys(
    String turfId,
    List<String> dateKeys,
  ) async {
    final allBookings = <Map<String, dynamic>>[];

    // Firestore whereIn has a limit of 10 items, so we batch the queries.
    // turfId filter is required by multi-tenant security rules.
    const batchSize = 10;
    for (var i = 0; i < dateKeys.length; i += batchSize) {
      final batch = dateKeys.skip(i).take(batchSize).toList();
      final snapshot = await _firestore
          .collection(AppConstants.bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('dateKey', whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        allBookings.add({...doc.data(), 'id': doc.id});
      }
    }

    return allBookings;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Yearly revenue
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<YearlyRevenueEntity> getYearlyRevenue(String turfId, int year) async {
    try {
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      final prevStart = DateTime(year - 1, 1, 1);

      final results = await Future.wait([
        _bookingsInRange(turfId, start, end),
        _sumPlanPaymentsByMonth(turfId, start, end),
        _sumYearTotal(turfId, prevStart, start),
        _sumTournamentPaymentsByMonth(turfId, start, end),
      ]);

      final bookings = results[0] as List<Map<String, dynamic>>;
      final planByMonth = results[1] as Map<int, double>;
      final prevYearTotal = results[2] as double;
      final tournamentByMonth = results[3] as Map<int, double>;

      // Aggregate bookings by month (1..12).
      final revenueByMonth = <int, double>{for (var i = 1; i <= 12; i++) i: 0};
      final bookingsByMonth = <int, int>{for (var i = 1; i <= 12; i++) i: 0};

      final nowTs = DateTime.now();
      for (final b in bookings) {
        final status = b['status'] as String?;
        if (status == 'CANCELLED') continue;
        final dateTs = b['date'] as Timestamp?;
        if (dateTs == null) continue;
        final date = dateTs.toDate();
        final month = date.month;

        bookingsByMonth[month] = (bookingsByMonth[month] ?? 0) + 1;

        // Revenue: only paid & finished.
        final isPaid = b['isPaid'] as bool? ?? false;
        final amountPaid = (b['amountPaid'] as num?)?.toDouble() ?? 0;
        if (!isPaid || amountPaid <= 0) continue;
        final endTime = (b['endTime'] as Timestamp?)?.toDate();
        final finished = status == 'COMPLETED' ||
            (endTime != null && endTime.isBefore(nowTs));
        if (!finished) continue;
        revenueByMonth[month] = (revenueByMonth[month] ?? 0) + amountPaid;
      }

      // Fold plan + tournament payment revenue into the same buckets.
      planByMonth.forEach((m, amt) {
        revenueByMonth[m] = (revenueByMonth[m] ?? 0) + amt;
      });
      tournamentByMonth.forEach((m, amt) {
        revenueByMonth[m] = (revenueByMonth[m] ?? 0) + amt;
      });

      final monthly = List<MonthlyRevenue>.generate(
        12,
        (i) {
          final m = i + 1;
          return MonthlyRevenue(
            month: m,
            revenue: revenueByMonth[m] ?? 0,
            bookings: bookingsByMonth[m] ?? 0,
          );
        },
      );

      final totalRevenue = monthly.fold<double>(0, (s, m) => s + m.revenue);
      final totalBookings =
          monthly.fold<int>(0, (s, m) => s + m.bookings);

      return YearlyRevenueEntity(
        year: year,
        totalRevenue: totalRevenue,
        totalBookings: totalBookings,
        monthly: monthly,
        previousYearRevenue: prevYearTotal > 0 ? prevYearTotal : null,
      );
    } catch (e) {
      debugPrint('❌ getYearlyRevenue: $e');
      return YearlyRevenueEntity.empty(year);
    }
  }

  Future<List<Map<String, dynamic>>> _bookingsInRange(
      String turfId, DateTime start, DateTime end) async {
    final snap = await _firestore
        .collection(AppConstants.bookingsCollection)
        .where('turfId', isEqualTo: turfId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  /// Plan payments grouped by month of `paidAt`. Used when computing per-
  /// month revenue for the yearly view.
  Future<Map<int, double>> _sumPlanPaymentsByMonth(
      String turfId, DateTime start, DateTime end) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('monthly_plan_payments')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      final out = <int, double>{};
      for (final d in snap.docs) {
        final data = d.data();
        final paidTs = data['paidAt'] as Timestamp?;
        if (paidTs == null) continue;
        final amt = (data['amount'] as num?)?.toDouble() ?? 0;
        final month = paidTs.toDate().month;
        out[month] = (out[month] ?? 0) + amt;
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ _sumPlanPaymentsByMonth failed: $e');
      return const {};
    }
  }

  /// Tournament payments grouped by month of `paidAt`, mirroring the
  /// plan-payment helper.
  Future<Map<int, double>> _sumTournamentPaymentsByMonth(
      String turfId, DateTime start, DateTime end) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('tournament_payments')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      final out = <int, double>{};
      for (final d in snap.docs) {
        final data = d.data();
        final paidTs = data['paidAt'] as Timestamp?;
        if (paidTs == null) continue;
        final amt = (data['amount'] as num?)?.toDouble() ?? 0;
        final month = paidTs.toDate().month;
        out[month] = (out[month] ?? 0) + amt;
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ _sumTournamentPaymentsByMonth failed: $e');
      return const {};
    }
  }

  /// Total recognized revenue (bookings + plan + tournament payments)
  /// at [turfId] in [start, end). Used as the YoY comparison baseline.
  Future<double> _sumYearTotal(
      String turfId, DateTime start, DateTime end) async {
    try {
      final results = await Future.wait([
        _bookingsInRange(turfId, start, end),
        _sumPlanPayments(turfId, start, end),
        _sumTournamentPayments(turfId, start, end),
      ]);
      final bookings = results[0] as List<Map<String, dynamic>>;
      final planTotal = results[1] as double;
      final tournamentTotal = results[2] as double;
      final nowTs = DateTime.now();
      double bookingTotal = 0;
      for (final b in bookings) {
        if (b['status'] == 'CANCELLED') continue;
        final isPaid = b['isPaid'] as bool? ?? false;
        final amount = (b['amountPaid'] as num?)?.toDouble() ?? 0;
        if (!isPaid || amount <= 0) continue;
        final endTime = (b['endTime'] as Timestamp?)?.toDate();
        final finished = b['status'] == 'COMPLETED' ||
            (endTime != null && endTime.isBefore(nowTs));
        if (!finished) continue;
        bookingTotal += amount;
      }
      return bookingTotal + planTotal + tournamentTotal;
    } catch (e) {
      debugPrint('⚠️ _sumYearTotal failed: $e');
      return 0;
    }
  }

  AnalyticsEntity _calculateAnalytics(
    List<Map<String, dynamic>> bookings,
    TimePeriod period,
    List<String> dateKeys, {
    double planRevenue = 0,
    double concessionRevenue = 0,
    int concessionSalesCount = 0,
  }) {
    // Revenue metrics — start with monthly plan payments folded in.
    double totalRevenue = planRevenue;
    double paidRevenue = planRevenue;
    double pendingRevenue = 0;

    // Booking metrics
    int totalBookings = bookings.length;
    int confirmedBookings = 0;
    int pendingBookings = 0;
    int cancelledBookings = 0;
    int completedBookings = 0;

    // Customer tracking - use phone number for uniqueness
    final customerPhones = <String>{};
    final customerBookingCounts = <String, int>{};

    // Hourly distribution
    final bookingsByHour = <int, int>{};
    final bookingsByWeekday = <int, int>{};

    // Daily metrics for charts
    final dailyRevenueMap = <String, double>{};
    final dailyBookingsMap = <String, int>{};

    // Initialize daily maps with zeros
    for (final dateKey in dateKeys) {
      dailyRevenueMap[dateKey] = 0;
      dailyBookingsMap[dateKey] = 0;
    }

    // Process each booking
    final nowTs = DateTime.now();
    for (final booking in bookings) {
      final status = booking['status'] as String?;
      final isPaid = booking['isPaid'] as bool? ?? false;
      final amountPaid = (booking['amountPaid'] as num?)?.toDouble() ?? 0;
      final userPhone = booking['userPhone'] as String?;
      final dateKey = booking['dateKey'] as String?;

      // Parse startTime to get hour
      final startTimeData = booking['startTime'];
      int? hour;
      int? weekday;
      if (startTimeData is Timestamp) {
        final startTime = startTimeData.toDate();
        hour = startTime.hour;
        weekday = startTime.weekday;
      }

      // Has the match actually been played? COMPLETED status OR the end
      // time has already passed (sweep hasn't run yet).
      final endTime = (booking['endTime'] as Timestamp?)?.toDate();
      final matchFinished = status == 'COMPLETED' ||
          (endTime != null && endTime.isBefore(nowTs));

      // Revenue counts only when match is finished AND paid — advance
      // payments for future games are deferred until the game plays.
      if (isPaid && amountPaid > 0 && matchFinished) {
        paidRevenue += amountPaid;
        totalRevenue += amountPaid;
      }

      // Booking status counts
      switch (status) {
        case 'CONFIRMED':
          confirmedBookings++;
          break;
        case 'PENDING':
          pendingBookings++;
          // Estimate pending revenue (use a default or average)
          pendingRevenue += 1500; // Default booking value
          break;
        case 'CANCELLED':
          cancelledBookings++;
          break;
        case 'COMPLETED':
          completedBookings++;
          break;
      }

      // Customer tracking - use phone number for uniqueness
      if (userPhone != null && userPhone.isNotEmpty) {
        customerPhones.add(userPhone);
        customerBookingCounts[userPhone] =
            (customerBookingCounts[userPhone] ?? 0) + 1;
      }

      // Hourly distribution (only for active bookings)
      if (hour != null &&
          (status == 'CONFIRMED' ||
              status == 'PENDING' ||
              status == 'COMPLETED')) {
        bookingsByHour[hour] = (bookingsByHour[hour] ?? 0) + 1;
      }

      // Weekday distribution
      if (weekday != null &&
          (status == 'CONFIRMED' ||
              status == 'PENDING' ||
              status == 'COMPLETED')) {
        bookingsByWeekday[weekday] = (bookingsByWeekday[weekday] ?? 0) + 1;
      }

      // Daily metrics
      if (dateKey != null) {
        if (isPaid && amountPaid > 0 && matchFinished) {
          dailyRevenueMap[dateKey] =
              (dailyRevenueMap[dateKey] ?? 0) + amountPaid;
        }
        if (status != 'CANCELLED') {
          dailyBookingsMap[dateKey] = (dailyBookingsMap[dateKey] ?? 0) + 1;
        }
      }
    }

    // Calculate derived metrics
    final uniqueCustomers = customerPhones.length;
    final repeatCustomers =
        customerBookingCounts.values.where((count) => count > 1).length;
    final newCustomers = uniqueCustomers - repeatCustomers;

    final cancellationRate = totalBookings > 0
        ? (cancelledBookings / totalBookings * 100)
        : 0.0;

    final averageBookingValue = (confirmedBookings + completedBookings) > 0
        ? paidRevenue / (confirmedBookings + completedBookings)
        : 0.0;

    // Calculate slot utilization
    // Total possible slots = days * slots per day (15 hours from 6 AM to 9 PM)
    final totalPossibleSlots =
        dateKeys.length * (AppConstants.slotEndHour - AppConstants.slotStartHour);
    final activeBookingsCount = confirmedBookings + pendingBookings + completedBookings;
    final slotUtilizationRate = totalPossibleSlots > 0
        ? (activeBookingsCount / totalPossibleSlots * 100)
        : 0.0;

    // Convert daily maps to lists
    final dailyRevenue = <DailyMetric>[];
    final dailyBookings = <DailyMetric>[];

    // Sort date keys and convert to DailyMetric
    final sortedDateKeys = dateKeys.toList()..sort();
    for (final dateKey in sortedDateKeys) {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        dailyRevenue.add(DailyMetric(
          date: date,
          value: dailyRevenueMap[dateKey] ?? 0,
        ));
        dailyBookings.add(DailyMetric(
          date: date,
          value: (dailyBookingsMap[dateKey] ?? 0).toDouble(),
        ));
      }
    }

    return AnalyticsEntity(
      totalRevenue: totalRevenue,
      paidRevenue: paidRevenue,
      pendingRevenue: pendingRevenue,
      averageBookingValue: averageBookingValue,
      concessionRevenue: concessionRevenue,
      concessionSalesCount: concessionSalesCount,
      totalBookings: totalBookings,
      confirmedBookings: confirmedBookings,
      pendingBookings: pendingBookings,
      cancelledBookings: cancelledBookings,
      completedBookings: completedBookings,
      cancellationRate: cancellationRate,
      uniqueCustomers: uniqueCustomers,
      newCustomers: newCustomers,
      repeatCustomers: repeatCustomers,
      bookingsByHour: bookingsByHour,
      bookingsByWeekday: bookingsByWeekday,
      slotUtilizationRate: slotUtilizationRate,
      dailyRevenue: dailyRevenue,
      dailyBookings: dailyBookings,
      period: period,
    );
  }
}
