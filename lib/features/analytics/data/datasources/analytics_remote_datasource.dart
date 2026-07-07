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

  /// Sum of monthly_plan_payments at [turfId] with `paidAt` in [start, end),
  /// bucketed by date key so the analytics daily breakdown can attribute
  /// the lump-sum payment to the day admin marked it paid.
  Future<({double total, Map<String, double> byDateKey})>
      _planPaymentsByDay(
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
      final byDate = <String, double>{};
      for (final d in snap.docs) {
        final amt = (d.data()['amount'] as num?)?.toDouble() ?? 0;
        total += amt;
        final paidTs = (d.data()['paidAt'] as Timestamp?)?.toDate();
        if (paidTs != null) {
          final key = _getDateKey(paidTs);
          byDate[key] = (byDate[key] ?? 0) + amt;
        }
      }
      return (total: total, byDateKey: byDate);
    } catch (e) {
      debugPrint('⚠️ _planPaymentsByDay failed: $e');
      return (total: 0.0, byDateKey: const <String, double>{});
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
  Future<({double total, Map<String, double> byDateKey})>
      _tournamentPaymentsByDay(
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
      final byDate = <String, double>{};
      for (final d in snap.docs) {
        final amt = (d.data()['amount'] as num?)?.toDouble() ?? 0;
        total += amt;
        final paidTs = (d.data()['paidAt'] as Timestamp?)?.toDate();
        if (paidTs != null) {
          final key = _getDateKey(paidTs);
          byDate[key] = (byDate[key] ?? 0) + amt;
        }
      }
      return (total: total, byDateKey: byDate);
    } catch (e) {
      debugPrint('⚠️ _tournamentPaymentsByDay failed: $e');
      return (total: 0.0, byDateKey: const <String, double>{});
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
        // Current calendar month: 1st of this month → today.
        return (
          start: DateTime(now.year, now.month, 1),
          end: endOfToday
        );
      case TimePeriod.overall:
        // All-time: from the earliest plausible booking date → today.
        return (start: DateTime(2020, 1, 1), end: endOfToday);
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
        // Anchored Sun→Sat week, up to today.
        final weekStart = _currentWeekStart(now);
        final days = today.difference(weekStart).inDays + 1;
        return List.generate(
          days,
          (i) => _getDateKey(weekStart.add(Duration(days: i))),
        );
      case TimePeriod.month:
        // Current calendar month: 1st → today.
        final monthStart = DateTime(now.year, now.month, 1);
        final days = today.difference(monthStart).inDays + 1;
        return List.generate(
          days,
          (i) => _getDateKey(monthStart.add(Duration(days: i))),
        );
      case TimePeriod.overall:
        // Date keys are derived from actual booking docs at query time.
        return [];
    }
  }

  /// Synthesize virtual booking entries for every active monthly plan
  /// session that falls within [range]. Revenue is intentionally 0 here —
  /// it arrives separately via `_planPaymentsByDay`. The synthetic entries
  /// let `_calculateAnalytics` count plan sessions in booking totals,
  /// hourly distribution, weekday distribution, and utilization rate.
  Future<List<Map<String, dynamic>>> _synthesizePlanSessions(
    String turfId,
    ({DateTime start, DateTime end}) range,
  ) async {
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('monthly_plans')
          .where('isActive', isEqualTo: true)
          .get();
      if (snap.docs.isEmpty) return [];

      final result = <Map<String, dynamic>>[];
      final now = DateTime.now();
      final rangeStart =
          DateTime(range.start.year, range.start.month, range.start.day);
      final rangeEnd =
          DateTime(range.end.year, range.end.month, range.end.day);

      for (final doc in snap.docs) {
        final data = doc.data();
        final daysOfWeek =
            (data['daysOfWeek'] as List?)?.cast<int>() ?? const [];
        if (daysOfWeek.isEmpty) continue;

        // Support both multi-hour (startHours) and legacy single-hour.
        final rawHours = data['startHours'];
        final hours = <int>[];
        if (rawHours is List) {
          for (final h in rawHours) {
            if (h is num) hours.add(h.toInt());
          }
        } else {
          final single = (data['startHour'] as num?)?.toInt();
          if (single != null) hours.add(single);
        }
        if (hours.isEmpty) continue;

        final planStartTs = (data['startDate'] as Timestamp?)?.toDate();
        if (planStartTs == null) continue;
        final planStart = DateTime(
            planStartTs.year, planStartTs.month, planStartTs.day);

        // Respect optional endDate — sessions after endDate don't count.
        final planEndTs = (data['endDate'] as Timestamp?)?.toDate();
        final planEnd = planEndTs != null
            ? DateTime(planEndTs.year, planEndTs.month, planEndTs.day + 1)
            : null;

        // Effective window = intersection of plan lifetime and query range.
        final effectiveStart =
            planStart.isAfter(rangeStart) ? planStart : rangeStart;
        final effectiveEnd = planEnd != null && planEnd.isBefore(rangeEnd)
            ? planEnd
            : rangeEnd;
        if (!effectiveStart.isBefore(effectiveEnd)) continue;

        for (var day = effectiveStart;
            day.isBefore(effectiveEnd);
            day = day.add(const Duration(days: 1))) {
          if (!daysOfWeek.contains(day.weekday)) continue;
          final dateKey = _getDateKey(day);

          for (final hour in hours) {
            final start = DateTime(day.year, day.month, day.day, hour);
            // Only count sessions that have already started — don't inflate
            // future sessions into current-period totals.
            if (start.isAfter(now)) continue;

            final end = DateTime(day.year, day.month, day.day, hour + 1);
            result.add({
              'dateKey': dateKey,
              'startTime': Timestamp.fromDate(start),
              'endTime': Timestamp.fromDate(end),
              'status': 'COMPLETED',
              'isPaid': true,
              // Revenue is 0 here — it flows through _planPaymentsByDay so
              // it is never double-counted.
              'amountPaid': 0.0,
              'basePrice': 0.0,
              'isMonthlyPlan': true,
              'userPhone': data['userPhone'] as String? ?? '',
              'turfId': turfId,
            });
          }
        }
      }

      debugPrint(
          '📊 _synthesizePlanSessions: ${result.length} plan sessions in range');
      return result;
    } catch (e) {
      debugPrint('⚠️ _synthesizePlanSessions failed: $e');
      return [];
    }
  }

  @override
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period) async {
    try {
      debugPrint('📊 getAnalytics: turf=$turfId period=$period');

      final range = _rangeForPeriod(period);

      // For 'overall', use a timestamp-range query (no dateKey whereIn)
      // since enumerating thousands of day keys is impractical.
      final bookingsFuture = period == TimePeriod.overall
          ? _bookingsInRange(turfId, range.start, range.end)
          : _fetchBookingsForDateKeys(turfId, _getDateKeysForPeriod(period));

      // Synthesize plan sessions in parallel with the bookings fetch.
      final planSessionsFuture = _synthesizePlanSessions(turfId, range);

      final rawBookings = await bookingsFuture;
      final planSessions = await planSessionsFuture;

      // Merge — plan sessions count toward booking totals, hourly/weekday
      // distribution, and utilization but NOT toward revenue (amountPaid=0).
      final bookings = [...rawBookings, ...planSessions];

      // Derive date keys. For 'overall', collect from both real bookings
      // and synthesized plan sessions so the daily chart includes plan days.
      final dateKeys = period == TimePeriod.overall
          ? bookings
              .map((b) => b['dateKey'] as String?)
              .whereType<String>()
              .toSet()
              .toList()
          : _getDateKeysForPeriod(period);

      // Plan + tournament payments received in this period also count.
      final plan = await _planPaymentsByDay(turfId, range.start, range.end);
      final tournament =
          await _tournamentPaymentsByDay(turfId, range.start, range.end);
      // Concession sales — tracked separately, NOT added to booking total.
      final concession =
          await _sumConcessionSales(turfId, range.start, range.end);

      debugPrint(
          '📊 getAnalytics: ${rawBookings.length} bookings + ${planSessions.length} plan sessions, '
          'plan=${plan.total}, tournament=${tournament.total}, concession=${concession.total} (${concession.count} sales)');

      // Merge plan + tournament per-day buckets.
      final extraByDay = <String, double>{};
      plan.byDateKey.forEach((k, v) {
        extraByDay[k] = (extraByDay[k] ?? 0) + v;
      });
      tournament.byDateKey.forEach((k, v) {
        extraByDay[k] = (extraByDay[k] ?? 0) + v;
      });

      return _calculateAnalytics(
          bookings, period, dateKeys,
          planRevenue: plan.total + tournament.total,
          planRevenueByDay: extraByDay,
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

        // Same rule as the dashboard PAID pill and the Today/Week/Month
        // analytics card: paid + finished + NOT plan/tournament; amount
        // = amountPaid, falling back to basePrice when amountPaid is
        // unset. Without the fallback, legacy paid rows where
        // amountPaid was never written get silently dropped here while
        // counting elsewhere — diverging totals by exactly that amount.
        final isPaid = b['isPaid'] as bool? ?? false;
        if (!isPaid) continue;
        final isPlan = b['isMonthlyPlan'] as bool? ?? false;
        final isTournament = b['isTournament'] as bool? ?? false;
        if (isPlan || isTournament) continue;
        final amountPaid = (b['amountPaid'] as num?)?.toDouble();
        final basePrice = (b['basePrice'] as num?)?.toDouble();
        final collected = amountPaid ?? basePrice ?? 0;
        if (collected <= 0) continue;
        final endTime = (b['endTime'] as Timestamp?)?.toDate();
        final finished = status == 'COMPLETED' ||
            (endTime != null && endTime.isBefore(nowTs));
        if (!finished) continue;
        // Same hour-range gate as monthly + hourly so totals stay aligned.
        final startTs = (b['startTime'] as Timestamp?)?.toDate();
        final h = startTs?.hour;
        if (h == null ||
            h < AppConstants.slotStartHour ||
            h >= AppConstants.slotEndHour) continue;
        revenueByMonth[month] = (revenueByMonth[month] ?? 0) + collected;
      }

      // Fold plan + tournament payments into the per-month totals so
      // yearly matches the monthly analytics card (which also includes
      // these lump-sum payments since the recent revenue unification).
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
        _planPaymentsByDay(turfId, start, end),
        _tournamentPaymentsByDay(turfId, start, end),
      ]);
      final bookings = results[0] as List<Map<String, dynamic>>;
      final planTotal = (results[1] as ({double total, Map<String, double> byDateKey})).total;
      final tournamentTotal = (results[2] as ({double total, Map<String, double> byDateKey})).total;
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
    /// Per-day breakdown of plan + tournament payments so the daily
    /// chart and breakdown list sum back to the period's total revenue.
    Map<String, double> planRevenueByDay = const {},
    double concessionRevenue = 0,
    int concessionSalesCount = 0,
  }) {
    // Revenue metrics — booking revenue + plan/tournament payments
    // (which arrive as lump sums on the day admin marks them paid).
    // The dashboard PAID pill now also includes today's plan revenue, so
    // analytics matches it as long as the period being viewed is "today".
    // Cafe stays separate (its own card).
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

    // Seed daily revenue with plan + tournament payments paid on each
    // date — bookings then add on top. Without this seed, lump-sum
    // payments would inflate the period total but be invisible in the
    // per-day breakdown.
    planRevenueByDay.forEach((dateKey, amount) {
      dailyRevenueMap[dateKey] =
          (dailyRevenueMap[dateKey] ?? 0) + amount;
    });

    // Process each booking
    final nowTs = DateTime.now();
    for (final booking in bookings) {
      final status = booking['status'] as String?;
      // Cancelled bookings never contribute to revenue or daily bars —
      // even if they were marked paid before cancellation. This matches
      // the hourly breakdown + yearly view exactly. Status counts (and
      // the cancellationRate metric below) are still computed.
      final isCancelled = status == 'CANCELLED';
      final isPaid = booking['isPaid'] as bool? ?? false;
      final amountPaidRaw = (booking['amountPaid'] as num?)?.toDouble();
      final basePrice = (booking['basePrice'] as num?)?.toDouble();
      final userPhone = booking['userPhone'] as String?;
      final dateKey = booking['dateKey'] as String?;

      // Skip plan/tournament synthetic-doc revenue — those flow through
      // their own payment collections and would double-count here.
      final isPlan = booking['isMonthlyPlan'] as bool? ?? false;
      final isTournament = booking['isTournament'] as bool? ?? false;

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

      // Revenue: same rule as the dashboard's PAID pill —
      //   paid && match finished, amountPaid (fall back to basePrice).
      // Plans/tournaments excluded so they aren't double-counted.
      final collected = amountPaidRaw ?? basePrice ?? 0;
      // Same hour-range gate the hourly breakdown applies — a paid
      // booking whose startTime hour falls OUTSIDE the configured slot
      // window (e.g. a stale 10 PM doc from before slotEndHour was
      // raised) should not inflate the day's totals.
      final hourInRange = hour != null &&
          hour >= AppConstants.slotStartHour &&
          hour < AppConstants.slotEndHour;
      if (!isCancelled &&
          isPaid &&
          matchFinished &&
          !isPlan &&
          !isTournament &&
          collected > 0 &&
          hourInRange) {
        paidRevenue += collected;
        totalRevenue += collected;
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

      // Daily metrics — same rule as headline revenue (incl. hour gate
      // and cancelled exclusion).
      if (dateKey != null) {
        if (!isCancelled &&
            isPaid &&
            matchFinished &&
            !isPlan &&
            !isTournament &&
            collected > 0 &&
            hourInRange) {
          dailyRevenueMap[dateKey] =
              (dailyRevenueMap[dateKey] ?? 0) + collected;
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
