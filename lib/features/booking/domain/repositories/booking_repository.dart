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
  Future<List<BookingEntity>> getBookingsForDate(String turfId, DateTime date);

  /// Cancel a booking by id.
  Future<void> cancelBooking(String bookingId);

  /// Get booking by ID.
  Future<BookingEntity?> getBookingById(String bookingId);

  /// Mark booking as paid (admin).
  Future<void> markBookingAsPaid(String bookingId, double amount);

  /// Update booking status (admin).
  Future<void> updateBookingStatus(String bookingId, BookingStatus status);

  /// Patch customer name / phone on a booking (admin).
  Future<void> updateBookingCustomer(
    String bookingId, {
    String? customerName,
    String? userPhone,
  });

  /// Get slot configuration for the given turf.
  Future<SlotConfigEntity> getSlotConfig(String turfId);

  /// Update slot configuration (admin) for the given turf.
  Future<void> updateSlotConfig(
      String turfId, List<int> enabledHours, String updatedBy);

  /// Update slot pricing (admin) for the given turf.
  /// Optionally updates the loyalty free-game threshold and the
  /// dynamic Morning/Day/Evening band boundaries in the same write.
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required double weekendPrice,
    required double holidayPrice,
    required String updatedBy,
    int? freeGameThreshold,
    int? dayStartHour,
    int? eveningStartHour,
  });

  /// Add a date as a holiday (dateKey = "YYYY-MM-DD", optional label).
  Future<void> addHoliday(
      String turfId, String dateKey, {String? label});

  /// Remove a holiday date.
  Future<void> removeHoliday(String turfId, String dateKey);

  /// Fetch all holiday dateKeys for the turf.
  Future<Map<String, String>> getHolidays(String turfId);

  /// Create a regular (recurring) booking. The booking's `turfId` MUST be set.
  Future<void> cancelRegularForDate(
      String turfId, BookingEntity regular, DateTime date);

  Future<void> restoreRegularForDate(
      String turfId, BookingEntity cancelledBooking);

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
  /// increments totalClaimed. When [bookingId] is provided, marks that
  /// booking as a free game (amount=0, isFreeGame=true) atomically.
  Future<void> claimFreeGame(String turfId, String phone,
      {String? bookingId, int threshold = 0});

  /// Live reward count per customer phone, computed from booking docs
  /// using the same rule the leaderboard uses. Free-game claims and
  /// bookings before the customer's lastClaimedAt are excluded.
  Future<Map<String, int>> liveRewardCounts(String turfId);

  /// Distinct {name, phone} pairs from recent bookings at this turf.
  Future<List<({String name, String phone})>> listRecentCustomers(
    String turfId, {
    int limit = 200,
  });

  /// Admin-only: mark a customer as not eligible for free-game rewards.
  Future<void> setRewardExcluded(
      String turfId, String phone, bool excluded);

  /// Booking datetimes that count toward [phone]'s current reward cycle,
  /// most-recent first. Empty after claiming (cycle resets).
  Future<List<DateTime>> getRewardBookingDates(String turfId, String phone);
}
