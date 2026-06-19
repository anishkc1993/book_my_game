import '../entities/booking_entity.dart';
import '../entities/regular_booking_entity.dart';
import '../entities/reward_entity.dart';
import '../entities/slot_config_entity.dart';
import '../entities/slot_entity.dart';

abstract class BookingRepository {
  /// Get all slots for a specific date at the given turf.
  /// [includePast] — admin-only escape hatch to include slots whose
  /// hour has already passed today (e.g., backfilling a 6 AM booking at
  /// 4 PM the same day).
  Future<List<SlotEntity>> getSlotsForDate(
    String turfId,
    DateTime date, {
    bool includePast = false,
  });

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
  /// Optionally updates the loyalty free-game threshold in the same write.
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required double weekendPrice,
    required String updatedBy,
    int? freeGameThreshold,
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

  /// Update editable fields on an existing regular booking.
  Future<RegularBookingEntity> updateRegularBooking(
      RegularBookingEntity booking);

  /// Auto-mark past, non-cancelled, unpaid bookings as paid + completed.
  /// Returns the number of bookings updated.
  Future<int> sweepPastBookings(String turfId);

  // ── Loyalty rewards ────────────────────────────────────────────────────

  /// Fetch the reward progress for a single customer at this turf.
  /// Returns a zero-progress entity if nothing's stored yet.
  Future<RewardEntity> getReward(String turfId, String phone);

  /// Fetch all reward docs for a turf (admin view).
  Future<List<RewardEntity>> listRewards(String turfId);

  /// Claim the free game for this customer: resets progress to 0,
  /// increments totalClaimed.
  Future<void> claimFreeGame(String turfId, String phone);
}
