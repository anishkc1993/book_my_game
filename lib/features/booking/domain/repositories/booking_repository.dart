import '../entities/booking_entity.dart';
import '../entities/slot_config_entity.dart';
import '../entities/slot_entity.dart';

abstract class BookingRepository {
  /// Get all slots for a specific date
  Future<List<SlotEntity>> getSlotsForDate(DateTime date);

  /// Create a new booking
  Future<BookingEntity> createBooking(BookingEntity booking);

  /// Create a booking as admin (bypasses one-booking limit)
  Future<BookingEntity> createAdminBooking(BookingEntity booking);

  /// Get user's bookings
  Future<List<BookingEntity>> getUserBookings(String userId);

  /// Get all bookings for a specific date (admin)
  Future<List<BookingEntity>> getBookingsForDate(DateTime date);

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId);

  /// Get booking by ID
  Future<BookingEntity?> getBookingById(String bookingId);

  /// Mark booking as paid (admin)
  Future<void> markBookingAsPaid(String bookingId, double amount);

  /// Update booking status (admin)
  Future<void> updateBookingStatus(String bookingId, BookingStatus status);

  /// Get slot configuration (enabled/disabled hours)
  Future<SlotConfigEntity> getSlotConfig();

  /// Update slot configuration (admin)
  Future<void> updateSlotConfig(List<int> enabledHours, String updatedBy);
}
