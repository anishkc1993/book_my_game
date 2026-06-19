import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../models/booking_model.dart';
import '../models/regular_booking_model.dart';
import '../models/reward_model.dart';
import '../models/slot_config_model.dart';
import '../models/slot_model.dart';

abstract class BookingRemoteDataSource {
  /// [includePast] — when true (admin-only flow) skip the "past hour =
  /// unavailable" gate so admins can backfill bookings for slots that
  /// have already started/finished.
  Future<List<SlotModel>> getSlotsForDate(
    String turfId,
    DateTime date, {
    bool includePast = false,
  });
  Future<BookingModel> createBooking(BookingModel booking);
  Future<BookingModel> createAdminBooking(BookingModel booking);
  Future<List<BookingModel>> getUserBookings(String turfId, String userId);
  Future<List<BookingModel>> getBookingsForDate(String turfId, DateTime date);
  Future<void> cancelBooking(String bookingId);
  Future<BookingModel?> getBookingById(String bookingId);
  Future<void> markBookingAsPaid(String bookingId, double amount);
  Future<void> updateBookingStatus(String bookingId, String status);
  Future<SlotConfigModel> getSlotConfig(String turfId);
  Future<void> updateSlotConfig(
      String turfId, List<int> enabledHours, String updatedBy);
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required double weekendPrice,
    required String updatedBy,
    int? freeGameThreshold,
  });

  Future<RegularBookingModel> createRegularBooking(RegularBookingModel booking);
  Future<List<RegularBookingModel>> getRegularBookings(String turfId);
  Future<void> deleteRegularBooking(String id);
  Future<void> setRegularBookingActive(String id, bool isActive);
  Future<RegularBookingModel> updateRegularBooking(RegularBookingModel booking);

  /// Auto-mark past, non-cancelled, unpaid bookings as paid + completed.
  /// Returns the number of bookings updated.
  Future<int> sweepPastBookings(String turfId);

  Future<RewardModel> getReward(String turfId, String phone);
  Future<List<RewardModel>> listRewards(String turfId);
  Future<void> claimFreeGame(String turfId, String phone);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final FirebaseFirestore _firestore;

  static const String _bookingsCollection = 'bookings';
  static const String _regularBookingsCollection = 'regular_bookings';
  static const String _turfsCollection = 'turfs';

  // Cache for slot config to avoid repeated reads — keyed by turfId.
  final Map<String, SlotConfigModel> _cachedSlotConfig = {};

  BookingRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get date key for Firestore document ID
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Slot config document for a given turf.
  DocumentReference _slotConfigDoc(String turfId) => _firestore
      .collection(_turfsCollection)
      .doc(turfId)
      .collection('settings')
      .doc('slot_config');

  /// Helper: hours reserved by all active regulars matching a date for a turf.
  Future<Map<int, RegularBookingModel>> _regularsForDate(
      String turfId, DateTime date) async {
    // For dates strictly in the past, the booking list must rely on real
    // (materialized) booking docs only. Synthesizing from the *current*
    // regular config would let toggles, day changes, or startDate edits
    // retroactively rewrite history — exactly what we don't want.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) return const {};

    final snapshot = await _firestore
        .collection(_regularBookingsCollection)
        .where('turfId', isEqualTo: turfId)
        .where('isActive', isEqualTo: true)
        .get();

    final result = <int, RegularBookingModel>{};
    for (final doc in snapshot.docs) {
      final reg = RegularBookingModel.fromFirestore(doc);
      if (reg.appliesTo(date)) {
        result[reg.startHour] = reg;
      }
    }
    return result;
  }

  /// Helper: tournaments whose dateKeys include this date. The booking
  /// path queries by dateKey for an indexed lookup. Failures fall back
  /// to an empty list so the day view still renders.
  Future<List<_TournamentSlot>> _tournamentsForDate(
      String turfId, DateTime date) async {
    final dateKey = _getDateKey(date);
    final snap = await _firestore
        .collection(_turfsCollection)
        .doc(turfId)
        .collection('tournaments')
        .where('dateKeys', arrayContains: dateKey)
        .get();
    return [
      for (final d in snap.docs)
        _TournamentSlot(
          id: d.id,
          name: (d.data()['name'] as String?) ?? '',
          organizerName: (d.data()['organizerName'] as String?) ?? '',
          organizerPhone: (d.data()['organizerPhone'] as String?) ?? '',
          startHour: (d.data()['startHour'] as num?)?.toInt() ?? 0,
          endHour: (d.data()['endHour'] as num?)?.toInt() ?? 0,
          totalAmount:
              (d.data()['totalAmount'] as num?)?.toDouble() ?? 0,
          isPaid: (d.data()['isPaid'] as bool?) ?? false,
          amountPaid: (d.data()['amountPaid'] as num?)?.toDouble(),
          paidAt: (d.data()['paidAt'] as Timestamp?)?.toDate(),
        ),
    ];
  }

  /// Helper: hours reserved by all active monthly plans matching a date.
  /// Plans live under `turfs/{turfId}/monthly_plans/{id}`. A single plan
  /// may reserve multiple hours (e.g., 8 AM + 6 PM) — each becomes a
  /// separate entry keyed by hour.
  Future<Map<int, _PlanSlot>> _plansForDate(
      String turfId, DateTime date) async {
    final snapshot = await _firestore
        .collection(_turfsCollection)
        .doc(turfId)
        .collection('monthly_plans')
        .where('isActive', isEqualTo: true)
        .get();

    final result = <int, _PlanSlot>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final daysOfWeek =
          (data['daysOfWeek'] as List<dynamic>?)?.cast<int>() ?? const [];
      // Prefer new multi-hour field, fall back to legacy single startHour.
      final rawHours = data['startHours'];
      final hours = <int>[];
      if (rawHours is List && rawHours.isNotEmpty) {
        for (final h in rawHours) {
          if (h is num) hours.add(h.toInt());
        }
      } else {
        final single = (data['startHour'] as num?)?.toInt();
        if (single != null) hours.add(single);
      }
      if (hours.isEmpty) continue;
      final startDate =
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final day = DateTime(date.year, date.month, date.day);
      final start =
          DateTime(startDate.year, startDate.month, startDate.day);
      if (day.isBefore(start)) continue;
      if (!daysOfWeek.contains(day.weekday)) continue;
      final slot = _PlanSlot(
        id: doc.id,
        customerName: data['customerName'] as String? ?? '',
        userPhone: data['userPhone'] as String? ?? '',
        monthlyFee: (data['monthlyFee'] as num?)?.toDouble() ?? 0,
      );
      for (final h in hours) {
        // If two plans overlap on the same hour, the last one wins —
        // matches the previous single-hour behavior.
        result[h] = slot;
      }
    }
    return result;
  }

  @override
  Future<List<SlotModel>> getSlotsForDate(
    String turfId,
    DateTime date, {
    bool includePast = false,
  }) async {
    try {
      debugPrint('📅 getSlotsForDate: $turfId / ${_getDateKey(date)}'
          '${includePast ? " (incl past)" : ""}');

      Set<int> enabledHours;
      try {
        final slotConfig = await getSlotConfig(turfId);
        enabledHours = slotConfig.enabledHours.toSet();
      } catch (e) {
        debugPrint('⚠️ getSlotsForDate: Could not fetch slot config, defaults');
        enabledHours = SlotConfigEntity.allPossibleHours.toSet();
      }

      final allSlots = SlotModel.generateSlotsForDate(date);
      final enabledSlots = allSlots
          .where((slot) => enabledHours.contains(slot.startTime.hour))
          .toList();

      final dateKey = _getDateKey(date);

      final bookingsSnapshot = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      debugPrint(
          '📅 getSlotsForDate: Found ${bookingsSnapshot.docs.length} bookings');

      final bookedHours = <int>{};
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        // COMPLETED counts too — once the sweep auto-completes a past
        // booking, that hour must still register as occupied so the slot
        // is shown as Played (not free for the admin to re-book).
        if (status == 'PENDING' ||
            status == 'CONFIRMED' ||
            status == 'COMPLETED') {
          final booking = BookingModel.fromFirestore(doc);
          bookedHours.add(booking.startTime.hour);
        }
      }

      final regulars = await _regularsForDate(turfId, date);
      bookedHours.addAll(regulars.keys);

      // Active monthly plans also reserve their scheduled hours. Wrapped
      // so a missing collection / denied read doesn't kill the grid.
      try {
        final plans = await _plansForDate(turfId, date);
        bookedHours.addAll(plans.keys);
      } catch (e) {
        debugPrint('⚠️ slot grid: plan reservations skipped: $e');
      }

      // Tournaments take a full hour range — block every hour in the
      // window so the slot grid greys them all out.
      try {
        final tournaments = await _tournamentsForDate(turfId, date);
        for (final t in tournaments) {
          for (int h = t.startHour; h < t.endHour; h++) {
            bookedHours.add(h);
          }
        }
      } catch (e) {
        debugPrint('⚠️ slot grid: tournament reservations skipped: $e');
      }

      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final updatedSlots = enabledSlots.map((slot) {
        final isPastHour =
            isToday && slot.startTime.hour <= now.hour;
        final isBooked = bookedHours.contains(slot.startTime.hour);
        // Past + booked → game's already done. Mark "played" so the UI
        // can label it distinctly while keeping it non-selectable. This
        // applies to both customer and admin views (admins can see past
        // empty slots as available because of includePast, but a past
        // booked slot is still past — and the game already happened).
        if (isPastHour && isBooked) {
          return slot.copyWith(status: SlotStatus.played);
        }
        if (!includePast && isPastHour) {
          return slot.copyWith(status: SlotStatus.unavailable);
        }
        if (isBooked) {
          return slot.copyWith(status: SlotStatus.booked);
        }
        return slot;
      }).toList();

      debugPrint(
          '📅 getSlotsForDate: Returning ${updatedSlots.length} slots');
      return updatedSlots;
    } catch (e) {
      debugPrint('❌ getSlotsForDate ERROR: $e');
      throw ServerException('Failed to fetch slots: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> createBooking(BookingModel booking) async {
    try {
      if (booking.turfId == null || booking.turfId!.isEmpty) {
        throw const ServerException('Missing turf for booking');
      }
      debugPrint('📝 createBooking: ${booking.userPhone} @ ${booking.turfId}');

      final dateKey = _getDateKey(booking.date);

      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: booking.turfId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      for (final doc in existingBookings.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status == 'PENDING' || status == 'CONFIRMED') {
          final existingBooking = BookingModel.fromFirestore(doc);
          if (existingBooking.userId == booking.userId) {
            throw const ServerException(
                'You already have a booking for this date. You can book on a different day.');
          }
          if (existingBooking.startTime.hour == booking.startTime.hour) {
            throw const ServerException('This time slot is already booked');
          }
        }
      }

      final regulars = await _regularsForDate(booking.turfId!, booking.date);
      if (regulars.containsKey(booking.startTime.hour)) {
        throw const ServerException(
            'This slot is reserved by a regular booking');
      }

      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toFirestore());

      debugPrint('📝 createBooking: ID ${docRef.id}');
      return booking.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ createBooking ERROR: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create booking: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getUserBookings(
      String turfId, String userId) async {
    try {
      debugPrint('📋 getUserBookings: turf=$turfId user=$userId');

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('userId', isEqualTo: userId)
          .get();

      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid composite index requirement.
      bookings.sort((a, b) => b.date.compareTo(a.date));

      debugPrint('📋 getUserBookings: Found ${bookings.length}');
      return bookings;
    } catch (e) {
      debugPrint('❌ getUserBookings ERROR: $e');
      throw ServerException('Failed to fetch bookings: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'CANCELLED',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ cancelBooking ERROR: $e');
      throw ServerException('Failed to cancel booking: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!doc.exists) return null;
      return BookingModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ getBookingById ERROR: $e');
      throw ServerException('Failed to fetch booking: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> createAdminBooking(BookingModel booking) async {
    try {
      if (booking.turfId == null || booking.turfId!.isEmpty) {
        throw const ServerException('Missing turf for admin booking');
      }

      final dateKey = _getDateKey(booking.date);

      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: booking.turfId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      for (final doc in existingBookings.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status == 'PENDING' || status == 'CONFIRMED') {
          final existingBooking = BookingModel.fromFirestore(doc);
          if (existingBooking.startTime.hour == booking.startTime.hour) {
            throw const ServerException('This time slot is already booked');
          }
        }
      }

      // Regular-slot guard — but skip it when the booking IS the regular's
      // own materialization (mark-paid for a synthetic regular entry).
      // Otherwise the regular's hour blocks the very record we're creating
      // to recognize the payment.
      if (!booking.isRegular) {
        final regulars =
            await _regularsForDate(booking.turfId!, booking.date);
        if (regulars.containsKey(booking.startTime.hour)) {
          throw const ServerException(
              'This slot is reserved by a regular booking');
        }
      }

      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toFirestore());

      return booking.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ createAdminBooking ERROR: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create booking: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getBookingsForDate(
      String turfId, DateTime date) async {
    try {
      final dateKey = _getDateKey(date);

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      // Cancelled bookings are dropped from the day view entirely —
      // showing them takes a slot in the list and prevents the synthesizer
      // from filling that hour with the regular/plan that would otherwise
      // apply. The booking doc still exists in Firestore for auditing.
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .where((b) => !b.isCancelled)
          .toList();

      // Synthesize virtual entries for active regulars matching this date.
      // Wrapped — a denied/failed regulars query must NOT take down the
      // real bookings list.
      try {
        final realHours = bookings.map((b) => b.startTime.hour).toSet();
        final regulars = await _regularsForDate(turfId, date);
        regulars.forEach((hour, reg) {
          if (realHours.contains(hour)) return;
          final start = DateTime(date.year, date.month, date.day, hour);
          final end = DateTime(date.year, date.month, date.day, hour + 1);
          bookings.add(BookingModel(
            id: 'regular_${reg.id}_$dateKey',
            userId: '',
            userPhone: reg.userPhone,
            customerName: reg.customerName,
            date: date,
            startTime: start,
            endTime: end,
            status: BookingStatus.confirmed,
            isPaid: false,
            basePrice: reg.basePrice,
            createdByAdmin: reg.createdByAdmin,
            createdAt: reg.createdAt,
            isRegular: true,
            regularBookingId: reg.id,
            turfId: turfId,
          ));
        });
      } catch (e) {
        debugPrint('⚠️ regulars synth failed (continuing): $e');
      }

      // Synthesize virtual entries for active monthly plans matching the
      // date. Plans never persist booking docs (so leaderboard ignores
      // them); they only surface in today's pitch / day view.
      // Wrapped for the same reason — if plans collection doesn't exist
      // yet or rules deny, we still want the real bookings to render.
      try {
        final plansTaken = bookings.map((b) => b.startTime.hour).toSet();
        final plans = await _plansForDate(turfId, date);
        plans.forEach((hour, plan) {
          if (plansTaken.contains(hour)) return;
          final start = DateTime(date.year, date.month, date.day, hour);
          final end = DateTime(date.year, date.month, date.day, hour + 1);
          bookings.add(BookingModel(
            id: 'plan_${plan.id}_$dateKey',
            userId: '',
            userPhone: plan.userPhone,
            customerName: plan.customerName,
            date: date,
            startTime: start,
            endTime: end,
            status: BookingStatus.confirmed,
            // Plans pre-paid monthly — surface as already-paid on the day
            // view so they don't show as "pending revenue".
            isPaid: true,
            basePrice: plan.monthlyFee,
            isMonthlyPlan: true,
            monthlyPlanId: plan.id,
            turfId: turfId,
          ));
        });
      } catch (e) {
        debugPrint('⚠️ plans synth failed (continuing): $e');
      }

      // Tournaments take precedence — any booking falling inside a
      // tournament hour window is suppressed and replaced by a single
      // tournament entry spanning the full range.
      try {
        final tournaments = await _tournamentsForDate(turfId, date);
        for (final t in tournaments) {
          bookings.removeWhere((b) {
            final h = b.startTime.hour;
            return h >= t.startHour && h < t.endHour;
          });
          final start = DateTime(date.year, date.month, date.day, t.startHour);
          final end = DateTime(date.year, date.month, date.day, t.endHour);
          bookings.add(BookingModel(
            id: 'tournament_${t.id}_$dateKey',
            userId: '',
            userPhone: t.organizerPhone,
            customerName: t.organizerName,
            date: date,
            startTime: start,
            endTime: end,
            status: BookingStatus.confirmed,
            isPaid: t.isPaid,
            basePrice: t.totalAmount,
            amountPaid: t.amountPaid,
            paidAt: t.paidAt,
            isTournament: true,
            tournamentId: t.id,
            tournamentName: t.name,
            turfId: turfId,
          ));
        }
      } catch (e) {
        debugPrint('⚠️ tournament synth failed (continuing): $e');
      }

      bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
      return bookings;
    } catch (e) {
      debugPrint('❌ getBookingsForDate ERROR: $e');
      throw ServerException('Failed to fetch bookings: ${e.toString()}');
    }
  }

  @override
  Future<void> markBookingAsPaid(String bookingId, double amount) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'isPaid': true,
        'amountPaid': amount,
        'paidAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Failed to update payment status: ${e.toString()}');
    }
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException(
          'Failed to update booking status: ${e.toString()}');
    }
  }

  @override
  Future<SlotConfigModel> getSlotConfig(String turfId) async {
    try {
      final cached = _cachedSlotConfig[turfId];
      if (cached != null) return cached;

      final doc = await _slotConfigDoc(turfId).get();

      if (!doc.exists) {
        final defaultConfig =
            SlotConfigModel.fromEntity(SlotConfigEntity.defaultConfig());
        _cachedSlotConfig[turfId] = defaultConfig;
        return defaultConfig;
      }

      final config = SlotConfigModel.fromFirestore(doc);
      _cachedSlotConfig[turfId] = config;
      return config;
    } catch (e) {
      debugPrint('❌ getSlotConfig: $e — returning defaults');
      final defaultConfig =
          SlotConfigModel.fromEntity(SlotConfigEntity.defaultConfig());
      _cachedSlotConfig[turfId] = defaultConfig;
      return defaultConfig;
    }
  }

  @override
  Future<void> updateSlotConfig(
      String turfId, List<int> enabledHours, String updatedBy) async {
    try {
      final current = await getSlotConfig(turfId);
      final config = SlotConfigModel(
        enabledHours: enabledHours,
        morningPrice: current.morningPrice,
        dayPrice: current.dayPrice,
        eveningPrice: current.eveningPrice,
        weekendPrice: current.weekendPrice,
        updatedBy: updatedBy,
        freeGameThreshold: current.freeGameThreshold,
      );

      await _slotConfigDoc(turfId).set(config.toFirestore());
      _cachedSlotConfig[turfId] = config;
    } catch (e) {
      throw ServerException(
          'Failed to update slot configuration: ${e.toString()}');
    }
  }

  @override
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required double weekendPrice,
    required String updatedBy,
    int? freeGameThreshold,
  }) async {
    try {
      final current = await getSlotConfig(turfId);
      final config = SlotConfigModel(
        enabledHours: current.enabledHours,
        morningPrice: morningPrice,
        dayPrice: dayPrice,
        eveningPrice: eveningPrice,
        weekendPrice: weekendPrice,
        updatedBy: updatedBy,
        // Preserve the existing threshold if the caller didn't pass one.
        freeGameThreshold: freeGameThreshold ?? current.freeGameThreshold,
      );

      await _slotConfigDoc(turfId).set(config.toFirestore());
      _cachedSlotConfig[turfId] = config;
    } catch (e) {
      throw ServerException('Failed to update slot pricing: ${e.toString()}');
    }
  }

  // ============ Regular Bookings ============

  /// Capture every past session of the regular `id` as a real booking doc
  /// BEFORE the admin mutates it (toggle off, edit dates/days/hour,
  /// delete). After this runs, history is frozen as fact — subsequent
  /// changes affect future sessions only.
  Future<void> _snapshotBeforeRegularMutation(String regularId) async {
    try {
      final doc = await _firestore
          .collection(_regularBookingsCollection)
          .doc(regularId)
          .get();
      if (!doc.exists) return;
      final turfId = (doc.data() ?? const {})['turfId'] as String?;
      if (turfId == null || turfId.isEmpty) return;
      await _materializePastRegulars(turfId);
    } catch (e) {
      debugPrint('⚠️ snapshotBeforeRegularMutation failed (continuing): $e');
    }
  }

  @override
  Future<RegularBookingModel> createRegularBooking(
      RegularBookingModel booking) async {
    try {
      if (booking.turfId == null || booking.turfId!.isEmpty) {
        throw const ServerException('Missing turf for regular booking');
      }
      final docRef = await _firestore
          .collection(_regularBookingsCollection)
          .add(booking.toFirestore());

      return RegularBookingModel(
        id: docRef.id,
        customerName: booking.customerName,
        userPhone: booking.userPhone,
        daysOfWeek: booking.daysOfWeek,
        startHour: booking.startHour,
        basePrice: booking.basePrice,
        startDate: booking.startDate,
        isActive: booking.isActive,
        notes: booking.notes,
        createdByAdmin: booking.createdByAdmin,
        createdAt: booking.createdAt,
        turfId: booking.turfId,
      );
    } catch (e) {
      debugPrint('❌ createRegularBooking ERROR: $e');
      if (e is ServerException) rethrow;
      throw ServerException(
          'Failed to create regular booking: ${e.toString()}');
    }
  }

  @override
  Future<List<RegularBookingModel>> getRegularBookings(String turfId) async {
    try {
      final snapshot = await _firestore
          .collection(_regularBookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .get();
      final list = snapshot.docs
          .map((doc) => RegularBookingModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        if (a.startHour != b.startHour) {
          return a.startHour.compareTo(b.startHour);
        }
        return a.customerName.compareTo(b.customerName);
      });
      return list;
    } catch (e) {
      debugPrint('❌ getRegularBookings ERROR: $e');
      throw ServerException(
          'Failed to fetch regular bookings: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteRegularBooking(String id) async {
    try {
      // Freeze past sessions as bookings before the regular vanishes.
      await _snapshotBeforeRegularMutation(id);
      await _firestore.collection(_regularBookingsCollection).doc(id).delete();
    } catch (e) {
      throw ServerException(
          'Failed to delete regular booking: ${e.toString()}');
    }
  }

  @override
  Future<void> setRegularBookingActive(String id, bool isActive) async {
    try {
      // Capture past sessions before flipping the active flag — otherwise
      // toggling off would erase un-materialized history from view.
      if (!isActive) await _snapshotBeforeRegularMutation(id);
      await _firestore
          .collection(_regularBookingsCollection)
          .doc(id)
          .update({'isActive': isActive});
    } catch (e) {
      throw ServerException(
          'Failed to update regular booking: ${e.toString()}');
    }
  }

  @override
  Future<RegularBookingModel> updateRegularBooking(
      RegularBookingModel booking) async {
    try {
      if (booking.id == null || booking.id!.isEmpty) {
        throw const ServerException('Missing id for regular booking update');
      }
      // Freeze past sessions under the OLD config before applying changes,
      // so editing days/hour/startDate doesn't rewrite history.
      await _snapshotBeforeRegularMutation(booking.id!);
      // Don't overwrite createdAt / createdByAdmin / turfId — those are
      // immutable. Only persist the fields admins can change.
      await _firestore
          .collection(_regularBookingsCollection)
          .doc(booking.id)
          .update({
        'customerName': booking.customerName,
        'userPhone': booking.userPhone,
        'daysOfWeek': booking.daysOfWeek,
        'startHour': booking.startHour,
        'basePrice': booking.basePrice,
        'startDate': Timestamp.fromDate(DateTime(
            booking.startDate.year,
            booking.startDate.month,
            booking.startDate.day)),
        'isActive': booking.isActive,
        'notes': booking.notes,
      });
      return booking;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          'Failed to update regular booking: ${e.toString()}');
    }
  }

  @override
  Future<int> sweepPastBookings(String turfId) async {
    try {
      final now = DateTime.now();

      // Open (active) bookings only — saves reads. whereIn allows up to 30
      // values; 2 is well within the limit.
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('status', whereIn: ['PENDING', 'CONFIRMED']).get();

      final batch = _firestore.batch();
      int count = 0;
      // Phone → number of bookings being completed in this sweep (for the
      // reward counter increment below).
      final completedByPhone = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final endTs = data['endTime'] as Timestamp?;
        if (endTs == null) continue;
        if (!endTs.toDate().isBefore(now)) continue; // not yet past

        final isPaid = data['isPaid'] as bool? ?? false;
        final basePrice = (data['basePrice'] as num?)?.toDouble();
        final userPhone = data['userPhone'] as String?;

        final updates = <String, dynamic>{
          'status': 'COMPLETED',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (!isPaid) {
          updates['isPaid'] = true;
          if (basePrice != null) updates['amountPaid'] = basePrice;
          updates['paidAt'] = FieldValue.serverTimestamp();
        }

        batch.update(doc.reference, updates);
        count++;

        // Loyalty progress — only weekday morning/day games count toward
        // the free-game threshold. Evening slots (5 PM+) and weekend games
        // (Sat/Sun) are excluded by policy.
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final qualifies = userPhone != null &&
            userPhone.isNotEmpty &&
            startTime != null &&
            startTime.hour < 17 && // morning + day = hours 6-16
            startTime.weekday <= 5; // Mon-Fri
        if (qualifies) {
          completedByPhone[userPhone] =
              (completedByPhone[userPhone] ?? 0) + 1;
        }
      }

      // Bump reward progress for each affected customer. Same batch so
      // either everything succeeds or nothing does.
      completedByPhone.forEach((phone, n) {
        final ref = _rewardDoc(turfId, phone);
        batch.set(
          ref,
          {
            'userPhone': phone,
            'progressCount': FieldValue.increment(n),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (count > 0) {
        await batch.commit();
        debugPrint('🧹 sweepPastBookings: auto-completed $count bookings, '
            'rewards bumped for ${completedByPhone.length} phones');
      }

      // ── Also materialize past regulars ────────────────────────────────
      // Regular sessions are synthetic (no booking doc). Once a session's
      // time has passed, materialize it as a real COMPLETED + PAID booking
      // so it counts toward revenue/leaderboard/rewards automatically —
      // no manual mark-paid needed.
      try {
        final extras = await _materializePastRegulars(turfId);
        if (extras > 0) {
          debugPrint(
              '🧹 sweepPastBookings: materialized $extras past regular sessions');
        }
        return count + extras;
      } catch (e) {
        debugPrint('⚠️ materialize past regulars failed: $e');
        return count;
      }
    } catch (e) {
      debugPrint('❌ sweepPastBookings ERROR: $e');
      // Non-fatal — don't disrupt dashboard load if sweep fails.
      return 0;
    }
  }

  /// Walk back through the last [lookbackDays] days and, for each active
  /// regular booking, materialize any past occurrence that hasn't been
  /// recorded yet. Returns the number of new booking docs written.
  Future<int> _materializePastRegulars(
    String turfId, {
    int lookbackDays = 7,
  }) async {
    final regularsSnap = await _firestore
        .collection(_regularBookingsCollection)
        .where('turfId', isEqualTo: turfId)
        .where('isActive', isEqualTo: true)
        .get();
    if (regularsSnap.docs.isEmpty) return 0;

    final now = DateTime.now();
    final lookbackStart =
        DateTime(now.year, now.month, now.day - lookbackDays);

    // Fetch every booking in the window in one round trip so we can
    // dedup in memory (avoid re-materializing the same slot).
    final bookingsSnap = await _firestore
        .collection(_bookingsCollection)
        .where('turfId', isEqualTo: turfId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(lookbackStart))
        .get();
    final occupied = <String>{}; // "YYYY-MM-DD@H" tokens
    for (final doc in bookingsSnap.docs) {
      final data = doc.data();
      final dateKey = data['dateKey'] as String?;
      final start = (data['startTime'] as Timestamp?)?.toDate();
      if (dateKey == null || start == null) continue;
      occupied.add('$dateKey@${start.hour}');
    }

    final batch = _firestore.batch();
    int created = 0;
    final rewardBumps = <String, int>{};

    for (final regDoc in regularsSnap.docs) {
      final reg = RegularBookingModel.fromFirestore(regDoc);
      // Walk every day in the window. Latest first isn't required; order
      // doesn't matter for the dedup logic.
      for (int i = 0; i <= lookbackDays; i++) {
        final day =
            DateTime(now.year, now.month, now.day - i);
        if (!reg.appliesTo(day)) continue;
        final start = DateTime(day.year, day.month, day.day, reg.startHour);
        final end = start.add(const Duration(hours: 1));
        // Only materialize if the session has actually finished.
        if (!end.isBefore(now)) continue;

        final dateKey = _getDateKey(day);
        final token = '$dateKey@${reg.startHour}';
        if (occupied.contains(token)) continue;
        // Mark as occupied so two regulars sharing the same hour on the
        // same day don't both materialize.
        occupied.add(token);

        final docRef = _firestore.collection(_bookingsCollection).doc();
        batch.set(docRef, {
          'userId': '',
          'userPhone': reg.userPhone,
          'customerName': reg.customerName,
          'date': Timestamp.fromDate(day),
          'dateKey': dateKey,
          'startTime': Timestamp.fromDate(start),
          'endTime': Timestamp.fromDate(end),
          'status': 'COMPLETED',
          'isPaid': true,
          'basePrice': reg.basePrice,
          'amountPaid': reg.basePrice,
          'paidAt': FieldValue.serverTimestamp(),
          'createdByAdmin': reg.createdByAdmin,
          'turfId': turfId,
          'isRegular': true,
          'regularBookingId': reg.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        created++;

        // Same reward-eligibility policy as the real-booking sweep.
        final qualifies = reg.userPhone.isNotEmpty &&
            reg.startHour < 17 &&
            day.weekday <= 5;
        if (qualifies) {
          rewardBumps[reg.userPhone] =
              (rewardBumps[reg.userPhone] ?? 0) + 1;
        }
      }
    }

    if (created == 0) return 0;
    rewardBumps.forEach((phone, n) {
      batch.set(
        _rewardDoc(turfId, phone),
        {
          'userPhone': phone,
          'progressCount': FieldValue.increment(n),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    await batch.commit();
    return created;
  }

  // ============ Loyalty rewards ============

  DocumentReference _rewardDoc(String turfId, String phone) {
    return _firestore
        .collection(_turfsCollection)
        .doc(turfId)
        .collection('rewards')
        .doc(RewardModel.docIdFor(phone));
  }

  @override
  Future<RewardModel> getReward(String turfId, String phone) async {
    try {
      final doc = await _rewardDoc(turfId, phone).get();
      if (!doc.exists) {
        return RewardModel(userPhone: phone);
      }
      return RewardModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ getReward: $e');
      return RewardModel(userPhone: phone);
    }
  }

  @override
  Future<List<RewardModel>> listRewards(String turfId) async {
    try {
      final snap = await _firestore
          .collection(_turfsCollection)
          .doc(turfId)
          .collection('rewards')
          .get();
      return snap.docs.map((d) => RewardModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('❌ listRewards: $e');
      return [];
    }
  }

  @override
  Future<void> claimFreeGame(String turfId, String phone) async {
    try {
      await _rewardDoc(turfId, phone).set({
        'userPhone': phone,
        'progressCount': 0,
        'totalClaimed': FieldValue.increment(1),
        'lastClaimedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ claimFreeGame: $e');
      throw ServerException('Failed to claim free game: ${e.toString()}');
    }
  }
}

/// Internal helper representing one applicable monthly-plan slot for a date.
class _PlanSlot {
  final String id;
  final String customerName;
  final String userPhone;
  final double monthlyFee;
  _PlanSlot({
    required this.id,
    required this.customerName,
    required this.userPhone,
    required this.monthlyFee,
  });
}

/// Internal helper for a tournament hitting a specific date.
class _TournamentSlot {
  final String id;
  final String name;
  final String organizerName;
  final String organizerPhone;
  final int startHour;
  final int endHour;
  final double totalAmount;
  final bool isPaid;
  final double? amountPaid;
  final DateTime? paidAt;
  _TournamentSlot({
    required this.id,
    required this.name,
    required this.organizerName,
    required this.organizerPhone,
    required this.startHour,
    required this.endHour,
    required this.totalAmount,
    required this.isPaid,
    this.amountPaid,
    this.paidAt,
  });
}
