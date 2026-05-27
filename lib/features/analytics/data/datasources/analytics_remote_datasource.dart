import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/analytics_entity.dart';

abstract class AnalyticsRemoteDataSource {
  Future<AnalyticsEntity> getAnalytics(String turfId, TimePeriod period);
}

class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  AnalyticsRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
        return List.generate(
          7,
          (i) => _getDateKey(today.subtract(Duration(days: i))),
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

      debugPrint('📊 getAnalytics: Found ${bookings.length} bookings');

      return _calculateAnalytics(bookings, period, dateKeys);
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

  AnalyticsEntity _calculateAnalytics(
    List<Map<String, dynamic>> bookings,
    TimePeriod period,
    List<String> dateKeys,
  ) {
    // Revenue metrics
    double totalRevenue = 0;
    double paidRevenue = 0;
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

      // Revenue calculations
      if (isPaid && amountPaid > 0) {
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
        if (isPaid && amountPaid > 0) {
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
