import '../entities/booking_entity.dart';
import '../entities/regular_booking_entity.dart';
import '../entities/slot_config_entity.dart';
import '../entities/slot_entity.dart';

abstract class BookingRepository {
  /// Get all slots for a specific date at the given turf.
  Future<List<SlotEntity>> getSlotsForDate(String turfId, DateTime date);

  /// Create a new booking. The booking's `turfId` MUST be set.
  Future<BookingEntity> createBooking(BookingEntity booking);

  /// Create a booking as admin (bypasses one-booking limit). The booking's
  /// `turfId` MUST be set.
  Future<BookingEntity> createAdminBooking(BookingEntity booking);

  /// Get user's bookings (scoped to a single turf).
  Future<List<BookingEntity>> getUserBookings(String turfId, String userId);

  /// Get all bookings for a specific date at the given turf (admin view).
  Future<List<BookingEntity>> getBookingsForDate(
      String turfId, DateTime date);

  /// Cancel a booking by id.
  Future<void> cancelBooking(String bookingId);

  /// Get booking by ID.
  Future<BookingEntity?> getBookingById(String bookingId);

  /// Mark booking as paid (admin).
  Future<void> markBookingAsPaid(String bookingId, double amount);

  /// Update booking status (admin).
  Future<void> updateBookingStatus(String bookingId, BookingStatus status);

  /// Get slot configuration for the given turf.
  Future<SlotConfigEntity> getSlotConfig(String turfId);

  /// Update slot configuration (admin) for the given turf.
  Future<void> updateSlotConfig(
      String turfId, List<int> enabledHours, String updatedBy);

  /// Update slot pricing (admin) for the given turf.
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required String updatedBy,
  });

  /// Create a regular (recurring) booking. The booking's `turfId` MUST be set.
  Future<RegularBookingEntity> createRegularBooking(
      RegularBookingEntity booking);

  /// Get all regular bookings at the given turf.
  Future<List<RegularBookingEntity>> getRegularBookings(String turfId);

  /// Delete a regular booking.
  Future<void> deleteRegularBooking(String id);

  /// Toggle a regular booking's active status.
  Future<void> setRegularBookingActive(String id, bool isActive);

  /// Auto-mark past, non-cancelled, unpaid bookings as paid + completed.
  /// Returns the number of bookings updated.
  Future<int> sweepPastBookings(String turfId);
}
