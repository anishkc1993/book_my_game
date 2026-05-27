import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/leaderboard_entry_model.dart';

abstract class LeaderboardRemoteDataSource {
  Future<List<LeaderboardEntryModel>> getMonthlyLeaderboard({
    required String turfId,
    bool forceRefresh = false,
  });
  Future<DateTime> getLastUpdateTime();
}

class LeaderboardRemoteDataSourceImpl implements LeaderboardRemoteDataSource {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  static const String _bookingsCollection = 'bookings';
  static const String _leaderboardCollection = 'leaderboard';
  static const String _lastUpdateKey = 'leaderboard_last_update';
  static const String _monthKeyPref = 'leaderboard_month_key';

  LeaderboardRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    required SharedPreferences prefs,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _prefs = prefs;

  /// Get the start of the current month (1st day, midnight)
  DateTime _getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get the end of the current month (last day, 23:59:59)
  DateTime _getMonthEnd(DateTime date) {
    // Get the first day of next month, then subtract 1 second
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(seconds: 1));
  }

  /// Get month key for caching (e.g., "2026-M04")
  String _getMonthKey(DateTime date) {
    final monthStr = date.month.toString().padLeft(2, '0');
    return '${date.year}-M$monthStr';
  }

  @override
  Future<List<LeaderboardEntryModel>> getMonthlyLeaderboard({
    required String turfId,
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();
      final currentMonthKey = _getMonthKey(now);
      // Cache key includes turfId so different turfs don't clobber each other.
      final cacheKey = '${turfId}_$currentMonthKey';
      final cachedMonthKey = _prefs.getString(_monthKeyPref);

      debugPrint('🏆 getMonthlyLeaderboard: turf=$turfId month=$currentMonthKey, cached=$cachedMonthKey');

      // Check if we need to refresh (new month, new turf, or force refresh)
      final needsRefresh = forceRefresh || cachedMonthKey != cacheKey;

      if (!needsRefresh) {
        final cachedData = await _getCachedLeaderboard(cacheKey);
        if (cachedData.isNotEmpty) {
          debugPrint('🏆 getMonthlyLeaderboard: Cached (${cachedData.length})');
          return cachedData;
        }
      }

      debugPrint('🏆 getMonthlyLeaderboard: Calculating fresh');
      final leaderboard = await _calculateLeaderboard(turfId, now);

      await _cacheLeaderboard(leaderboard, cacheKey);
      await _prefs.setString(_monthKeyPref, cacheKey);
      await _prefs.setString(_lastUpdateKey, now.toIso8601String());

      return leaderboard;
    } catch (e) {
      debugPrint('❌ getMonthlyLeaderboard ERROR: $e');
      throw ServerException('Failed to fetch leaderboard: ${e.toString()}');
    }
  }

  Future<List<LeaderboardEntryModel>> _getCachedLeaderboard(String cacheKey) async {
    try {
      final snapshot = await _firestore
          .collection(_leaderboardCollection)
          .doc(cacheKey)
          .collection('entries')
          .orderBy('rank')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardEntryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('⚠️ _getCachedLeaderboard: Cache miss - $e');
      return [];
    }
  }

  Future<List<LeaderboardEntryModel>> _calculateLeaderboard(
      String turfId, DateTime now) async {
    final monthStart = _getMonthStart(now);
    final monthEnd = _getMonthEnd(now);

    debugPrint('🏆 Calculating leaderboard for turf=$turfId $monthStart to $monthEnd');

    // Fetch all bookings at this turf for the month. The turfId filter is
    // required by Firestore rules under multi-tenant.
    final snapshot = await _firestore
        .collection(_bookingsCollection)
        .where('turfId', isEqualTo: turfId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
        .get();

    debugPrint('🏆 Found ${snapshot.docs.length} bookings for the month');

    // Aggregate by phone number
    final Map<String, _BookingAggregation> aggregations = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      // Only count confirmed and completed bookings
      if (status != 'CONFIRMED' && status != 'COMPLETED') continue;

      final phone = data['userPhone'] as String? ?? '';
      if (phone.isEmpty) continue;

      final customerName = data['customerName'] as String?;

      if (aggregations.containsKey(phone)) {
        aggregations[phone]!.count++;
        // Use most recent customer name if available
        if (customerName != null && customerName.isNotEmpty) {
          aggregations[phone]!.customerName = customerName;
        }
      } else {
        aggregations[phone] = _BookingAggregation(
          phoneNumber: phone,
          customerName: customerName,
          count: 1,
        );
      }
    }

    // Sort by booking count descending
    final sortedEntries = aggregations.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Create ranked leaderboard entries (top 20)
    final leaderboard = <LeaderboardEntryModel>[];
    for (var i = 0; i < sortedEntries.length && i < 20; i++) {
      final entry = sortedEntries[i];
      leaderboard.add(LeaderboardEntryModel(
        phoneNumber: entry.phoneNumber,
        customerName: entry.customerName,
        bookingCount: entry.count,
        rank: i + 1,
        monthStart: monthStart,
        monthEnd: monthEnd,
      ));
    }

    debugPrint('🏆 Calculated ${leaderboard.length} leaderboard entries');
    return leaderboard;
  }

  Future<void> _cacheLeaderboard(List<LeaderboardEntryModel> entries, String cacheKey) async {
    try {
      final batch = _firestore.batch();
      final monthDoc = _firestore.collection(_leaderboardCollection).doc(cacheKey);

      // Set month metadata
      batch.set(monthDoc, {
        'cacheKey': cacheKey,
        'updatedAt': FieldValue.serverTimestamp(),
        'entryCount': entries.length,
      });

      // Delete old entries first (in case of refresh)
      final oldEntries = await monthDoc.collection('entries').get();
      for (final doc in oldEntries.docs) {
        batch.delete(doc.reference);
      }

      // Add new entries
      for (final entry in entries) {
        final entryDoc = monthDoc.collection('entries').doc('rank_${entry.rank}');
        batch.set(entryDoc, entry.toFirestore());
      }

      await batch.commit();
      debugPrint('🏆 Cached ${entries.length} leaderboard entries for $cacheKey');
    } catch (e) {
      debugPrint('⚠️ _cacheLeaderboard: Failed to cache - $e');
      // Non-fatal, leaderboard still works without caching
    }
  }

  @override
  Future<DateTime> getLastUpdateTime() async {
    final lastUpdate = _prefs.getString(_lastUpdateKey);
    if (lastUpdate != null) {
      return DateTime.parse(lastUpdate);
    }
    return DateTime.now();
  }
}

class _BookingAggregation {
  final String phoneNumber;
  String? customerName;
  int count;

  _BookingAggregation({
    required this.phoneNumber,
    this.customerName,
    required this.count,
  });
}
