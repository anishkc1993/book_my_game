import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../models/booking_model.dart';
import '../models/slot_config_model.dart';
import '../models/slot_model.dart';

abstract class BookingRemoteDataSource {
  Future<List<SlotModel>> getSlotsForDate(DateTime date);
  Future<BookingModel> createBooking(BookingModel booking);
  Future<BookingModel> createAdminBooking(BookingModel booking);
  Future<List<BookingModel>> getUserBookings(String userId);
  Future<List<BookingModel>> getBookingsForDate(DateTime date);
  Future<void> cancelBooking(String bookingId);
  Future<BookingModel?> getBookingById(String bookingId);
  Future<void> markBookingAsPaid(String bookingId, double amount);
  Future<void> updateBookingStatus(String bookingId, String status);
  Future<SlotConfigModel> getSlotConfig();
  Future<void> updateSlotConfig(List<int> enabledHours, String updatedBy);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final FirebaseFirestore _firestore;

  static const String _bookingsCollection = 'bookings';

  // Cache for slot config to avoid repeated reads
  SlotConfigModel? _cachedSlotConfig;

  BookingRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get date key for Firestore document ID
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<List<SlotModel>> getSlotsForDate(DateTime date) async {
    try {
      debugPrint('📅 getSlotsForDate: Fetching slots for ${_getDateKey(date)}');

      // Get slot configuration to filter enabled hours (with fallback)
      Set<int> enabledHours;
      try {
        final slotConfig = await getSlotConfig();
        enabledHours = slotConfig.enabledHours.toSet();
      } catch (e) {
        debugPrint('⚠️ getSlotsForDate: Could not fetch slot config, using defaults');
        // Fall back to all hours if config fetch fails
        enabledHours = SlotConfigEntity.allPossibleHours.toSet();
      }

      // Generate all possible slots for the date
      final allSlots = SlotModel.generateSlotsForDate(date);

      // Filter to only enabled hours
      final enabledSlots = allSlots
          .where((slot) => enabledHours.contains(slot.startTime.hour))
          .toList();

      // Fetch existing bookings for this date using a simple date string key
      // This avoids needing a composite index
      final dateKey = _getDateKey(date);

      final bookingsSnapshot = await _firestore
          .collection(_bookingsCollection)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      debugPrint('📅 getSlotsForDate: Found ${bookingsSnapshot.docs.length} bookings');

      // Create a set of booked hours from active bookings
      final bookedHours = <int>{};
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        // Only count PENDING and CONFIRMED bookings
        if (status == 'PENDING' || status == 'CONFIRMED') {
          final booking = BookingModel.fromFirestore(doc);
          bookedHours.add(booking.startTime.hour);
        }
      }

      // Get current time to check for past slots
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      // Update slot statuses based on bookings and current time
      final updatedSlots = enabledSlots.map((slot) {
        // Mark as unavailable if slot time has already passed (for today)
        if (isToday && slot.startTime.hour <= now.hour) {
          return slot.copyWith(status: SlotStatus.unavailable);
        }
        // Mark as booked if already booked
        if (bookedHours.contains(slot.startTime.hour)) {
          return slot.copyWith(status: SlotStatus.booked);
        }
        return slot;
      }).toList();

      debugPrint('📅 getSlotsForDate: Returning ${updatedSlots.length} slots (${allSlots.length - enabledSlots.length} disabled)');
      return updatedSlots;
    } catch (e) {
      debugPrint('❌ getSlotsForDate ERROR: $e');
      throw ServerException('Failed to fetch slots: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> createBooking(BookingModel booking) async {
    try {
      debugPrint('📝 createBooking: Creating booking for ${booking.userPhone}');

      // Check bookings for this date
      final dateKey = _getDateKey(booking.date);

      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      for (final doc in existingBookings.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status == 'PENDING' || status == 'CONFIRMED') {
          final existingBooking = BookingModel.fromFirestore(doc);
          // Check if user already has a booking on this date
          if (existingBooking.userId == booking.userId) {
            throw const ServerException('You already have a booking for this date. You can book on a different day.');
          }
          // Check if the specific time slot is already booked by anyone
          if (existingBooking.startTime.hour == booking.startTime.hour) {
            throw const ServerException('This time slot is already booked');
          }
        }
      }

      // Create the booking
      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toFirestore());

      debugPrint('📝 createBooking: Booking created with ID ${docRef.id}');

      return booking.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ createBooking ERROR: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create booking: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      debugPrint('📋 getUserBookings: Fetching bookings for user $userId');

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();

      debugPrint('📋 getUserBookings: Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      debugPrint('❌ getUserBookings ERROR: $e');
      throw ServerException('Failed to fetch bookings: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      debugPrint('🚫 cancelBooking: Cancelling booking $bookingId');

      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'CANCELLED',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🚫 cancelBooking: Booking cancelled successfully');
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
      debugPrint('👑 createAdminBooking: Admin creating booking');

      // Check if slot is still available using dateKey
      final dateKey = _getDateKey(booking.date);

      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      // Check if the specific time slot is already booked
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

      // Create the booking (no user limit check for admin)
      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toFirestore());

      debugPrint('👑 createAdminBooking: Booking created with ID ${docRef.id}');

      return booking.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ createAdminBooking ERROR: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create booking: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getBookingsForDate(DateTime date) async {
    try {
      final dateKey = _getDateKey(date);
      debugPrint('📋 getBookingsForDate: Fetching bookings for $dateKey');

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();

      // Sort by start time
      bookings.sort((a, b) => a.startTime.compareTo(b.startTime));

      debugPrint('📋 getBookingsForDate: Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      debugPrint('❌ getBookingsForDate ERROR: $e');
      throw ServerException('Failed to fetch bookings: ${e.toString()}');
    }
  }

  @override
  Future<void> markBookingAsPaid(String bookingId, double amount) async {
    try {
      debugPrint('💰 markBookingAsPaid: Marking booking $bookingId as paid with amount $amount');

      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'isPaid': true,
        'amountPaid': amount,
        'paidAt': FieldValue.serverTimestamp(),
      });

      debugPrint('💰 markBookingAsPaid: Booking marked as paid');
    } catch (e) {
      debugPrint('❌ markBookingAsPaid ERROR: $e');
      throw ServerException('Failed to update payment status: ${e.toString()}');
    }
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      debugPrint('📝 updateBookingStatus: Updating booking $bookingId to $status');

      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📝 updateBookingStatus: Status updated');
    } catch (e) {
      debugPrint('❌ updateBookingStatus ERROR: $e');
      throw ServerException('Failed to update booking status: ${e.toString()}');
    }
  }

  @override
  Future<SlotConfigModel> getSlotConfig() async {
    try {
      // Return cached config if available
      if (_cachedSlotConfig != null) {
        return _cachedSlotConfig!;
      }

      debugPrint('⚙️ getSlotConfig: Fetching slot configuration');

      final doc = await _firestore
          .collection(AppConstants.settingsCollection)
          .doc(AppConstants.slotConfigDoc)
          .get();

      if (!doc.exists) {
        // Return default config without writing (read-only for non-admin users)
        // Admin will create the document when they first update slot config
        debugPrint('⚙️ getSlotConfig: No config found, using default (all hours enabled)');
        final defaultConfig = SlotConfigModel.fromEntity(SlotConfigEntity.defaultConfig());
        _cachedSlotConfig = defaultConfig;
        return defaultConfig;
      }

      _cachedSlotConfig = SlotConfigModel.fromFirestore(doc);
      debugPrint('⚙️ getSlotConfig: Loaded ${_cachedSlotConfig!.enabledHours.length} enabled hours');
      return _cachedSlotConfig!;
    } catch (e) {
      debugPrint('❌ getSlotConfig ERROR: $e');
      // Return default config on error instead of throwing
      debugPrint('⚙️ getSlotConfig: Returning default config due to error');
      final defaultConfig = SlotConfigModel.fromEntity(SlotConfigEntity.defaultConfig());
      _cachedSlotConfig = defaultConfig;
      return defaultConfig;
    }
  }

  @override
  Future<void> updateSlotConfig(List<int> enabledHours, String updatedBy) async {
    try {
      debugPrint('⚙️ updateSlotConfig: Updating to ${enabledHours.length} enabled hours');

      final config = SlotConfigModel(
        enabledHours: enabledHours,
        updatedBy: updatedBy,
      );

      await _firestore
          .collection(AppConstants.settingsCollection)
          .doc(AppConstants.slotConfigDoc)
          .set(config.toFirestore());

      // Update cache
      _cachedSlotConfig = config;

      debugPrint('⚙️ updateSlotConfig: Configuration updated');
    } catch (e) {
      debugPrint('❌ updateSlotConfig ERROR: $e');
      throw ServerException('Failed to update slot configuration: ${e.toString()}');
    }
  }
}
