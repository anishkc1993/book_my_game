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

  /// Merge one or more `sourcePhones` into `targetPhone` across
  /// `bookings`, `regular_bookings`, and the turf's `monthly_plans`
  /// subcollection. Each source is matched against every stored
  /// representation (`9812345678`, `9779812345678`, `+9779812345678`) and
  /// rewritten to the canonical `+977<10>` form of `targetPhone`.
  /// Returns total docs updated. The single-edit case is just a merge
  /// with one source.
  Future<int> mergePhoneNumbers({
    required String turfId,
    required List<String> sourcePhones,
    required String targetPhone,
  });
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

  /// Strip the Nepal country code + any non-digits so leaderboard
  /// aggregation treats "+9779812345678", "9779812345678", and
  /// "9812345678" as the same customer.
  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('977') && digits.length > 10) {
      digits = digits.substring(3);
    }
    return digits;
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
          .limit(40)
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

    final nowTs = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      // Skip cancelled outright.
      if (status == 'CANCELLED') continue;

      // Only count games that have actually been played:
      // - status == COMPLETED (sweep already moved it), OR
      // - status == CONFIRMED but the end time is in the past (sweep
      //   hasn't run yet for it, but the game time has clearly passed).
      // Future confirmed bookings don't count yet.
      final endTime = (data['endTime'] as Timestamp?)?.toDate();
      final hasBeenPlayed = status == 'COMPLETED' ||
          (status == 'CONFIRMED' &&
              endTime != null &&
              endTime.isBefore(nowTs));
      if (!hasBeenPlayed) continue;

      final rawPhone = data['userPhone'] as String? ?? '';
      if (rawPhone.isEmpty) continue;
      // Normalize so the same customer isn't double-counted across rows
      // saved with vs without the +977 country code (e.g.,
      // "+9779812345678" and "9812345678" must aggregate together).
      final phone = _normalizePhone(rawPhone);
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

    // Create ranked leaderboard entries (top 40)
    final leaderboard = <LeaderboardEntryModel>[];
    for (var i = 0; i < sortedEntries.length && i < 40; i++) {
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

  @override
  Future<int> mergePhoneNumbers({
    required String turfId,
    required List<String> sourcePhones,
    required String targetPhone,
  }) async {
    final targetDigits = _normalizePhone(targetPhone);
    if (targetDigits.length != 10) {
      throw const ServerException('Target must be a 10-digit phone');
    }
    final targetCanonical = '+977$targetDigits';

    // Sources: drop duplicates and the target itself (no-op to merge into
    // self). Keep only well-formed 10-digit entries.
    final sources = <String>{};
    for (final raw in sourcePhones) {
      final d = _normalizePhone(raw);
      if (d.length != 10) continue;
      if (d == targetDigits) continue;
      sources.add(d);
    }
    if (sources.isEmpty) {
      return 0;
    }

    int updated = 0;
    final batch = _firestore.batch();

    Future<void> rewrite(
      Query<Map<String, dynamic>> base,
      String variant,
    ) async {
      final snap = await base.where('userPhone', isEqualTo: variant).get();
      for (final d in snap.docs) {
        batch.update(d.reference, {'userPhone': targetCanonical});
        updated++;
      }
    }

    final bookingsBase = _firestore
        .collection('bookings')
        .where('turfId', isEqualTo: turfId);
    final regularsBase = _firestore
        .collection('regular_bookings')
        .where('turfId', isEqualTo: turfId);
    final plansBase = _firestore
        .collection('turfs')
        .doc(turfId)
        .collection('monthly_plans');

    for (final source in sources) {
      final variants = <String>{
        source,
        '977$source',
        '+977$source',
      };
      for (final v in variants) {
        await rewrite(bookingsBase, v);
        await rewrite(regularsBase, v);
        await rewrite(plansBase, v);
      }
    }

    if (updated == 0) {
      debugPrint('🔄 mergePhoneNumbers: no docs matched any source');
      return 0;
    }

    await batch.commit();
    debugPrint(
        '🔄 mergePhoneNumbers: rewrote $updated docs → $targetCanonical (from ${sources.length} sources)');
    return updated;
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
