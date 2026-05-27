import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../models/booking_model.dart';
import '../models/regular_booking_model.dart';
import '../models/slot_config_model.dart';
import '../models/slot_model.dart';

abstract class BookingRemoteDataSource {
  Future<List<SlotModel>> getSlotsForDate(String turfId, DateTime date);
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
    required String updatedBy,
  });

  Future<RegularBookingModel> createRegularBooking(RegularBookingModel booking);
  Future<List<RegularBookingModel>> getRegularBookings(String turfId);
  Future<void> deleteRegularBooking(String id);
  Future<void> setRegularBookingActive(String id, bool isActive);

  /// Auto-mark past, non-cancelled, unpaid bookings as paid + completed.
  /// Returns the number of bookings updated.
  Future<int> sweepPastBookings(String turfId);
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

  @override
  Future<List<SlotModel>> getSlotsForDate(
      String turfId, DateTime date) async {
    try {
      debugPrint('📅 getSlotsForDate: $turfId / ${_getDateKey(date)}');

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
        if (status == 'PENDING' || status == 'CONFIRMED') {
          final booking = BookingModel.fromFirestore(doc);
          bookedHours.add(booking.startTime.hour);
        }
      }

      final regulars = await _regularsForDate(turfId, date);
      bookedHours.addAll(regulars.keys);

      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final updatedSlots = enabledSlots.map((slot) {
        if (isToday && slot.startTime.hour <= now.hour) {
          return slot.copyWith(status: SlotStatus.unavailable);
        }
        if (bookedHours.contains(slot.startTime.hour)) {
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

      final regulars = await _regularsForDate(booking.turfId!, booking.date);
      if (regulars.containsKey(booking.startTime.hour)) {
        throw const ServerException(
            'This slot is reserved by a regular booking');
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

      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();

      // Synthesize virtual entries for active regulars matching this date.
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
        updatedBy: updatedBy,
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
    required String updatedBy,
  }) async {
    try {
      final current = await getSlotConfig(turfId);
      final config = SlotConfigModel(
        enabledHours: current.enabledHours,
        morningPrice: morningPrice,
        dayPrice: dayPrice,
        eveningPrice: eveningPrice,
        updatedBy: updatedBy,
      );

      await _slotConfigDoc(turfId).set(config.toFirestore());
      _cachedSlotConfig[turfId] = config;
    } catch (e) {
      throw ServerException('Failed to update slot pricing: ${e.toString()}');
    }
  }

  // ============ Regular Bookings ============

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
      await _firestore.collection(_regularBookingsCollection).doc(id).delete();
    } catch (e) {
      throw ServerException(
          'Failed to delete regular booking: ${e.toString()}');
    }
  }

  @override
  Future<void> setRegularBookingActive(String id, bool isActive) async {
    try {
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

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final endTs = data['endTime'] as Timestamp?;
        if (endTs == null) continue;
        if (!endTs.toDate().isBefore(now)) continue; // not yet past

        final isPaid = data['isPaid'] as bool? ?? false;
        final basePrice = (data['basePrice'] as num?)?.toDouble();

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
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('🧹 sweepPastBookings: auto-completed $count bookings');
      }
      return count;
    } catch (e) {
      debugPrint('❌ sweepPastBookings ERROR: $e');
      // Non-fatal — don't disrupt dashboard load if sweep fails.
      return 0;
    }
  }
}
