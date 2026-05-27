import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/regular_booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../models/booking_model.dart';
import '../models/regular_booking_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl({required BookingRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<SlotEntity>> getSlotsForDate(String turfId, DateTime date) {
    return _remoteDataSource.getSlotsForDate(turfId, date);
  }

  @override
  Future<BookingEntity> createBooking(BookingEntity booking) {
    final model = BookingModel.fromEntity(booking);
    return _remoteDataSource.createBooking(model);
  }

  @override
  Future<BookingEntity> createAdminBooking(BookingEntity booking) {
    final model = BookingModel.fromEntity(booking);
    return _remoteDataSource.createAdminBooking(model);
  }

  @override
  Future<List<BookingEntity>> getUserBookings(String turfId, String userId) {
    return _remoteDataSource.getUserBookings(turfId, userId);
  }

  @override
  Future<List<BookingEntity>> getBookingsForDate(
      String turfId, DateTime date) {
    return _remoteDataSource.getBookingsForDate(turfId, date);
  }

  @override
  Future<void> cancelBooking(String bookingId) {
    return _remoteDataSource.cancelBooking(bookingId);
  }

  @override
  Future<BookingEntity?> getBookingById(String bookingId) {
    return _remoteDataSource.getBookingById(bookingId);
  }

  @override
  Future<void> markBookingAsPaid(String bookingId, double amount) {
    return _remoteDataSource.markBookingAsPaid(bookingId, amount);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus status) {
    return _remoteDataSource.updateBookingStatus(bookingId, status.value);
  }

  @override
  Future<SlotConfigEntity> getSlotConfig(String turfId) {
    return _remoteDataSource.getSlotConfig(turfId);
  }

  @override
  Future<void> updateSlotConfig(
      String turfId, List<int> enabledHours, String updatedBy) {
    return _remoteDataSource.updateSlotConfig(turfId, enabledHours, updatedBy);
  }

  @override
  Future<void> updateSlotPricing({
    required String turfId,
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required String updatedBy,
  }) {
    return _remoteDataSource.updateSlotPricing(
      turfId: turfId,
      morningPrice: morningPrice,
      dayPrice: dayPrice,
      eveningPrice: eveningPrice,
      updatedBy: updatedBy,
    );
  }

  @override
  Future<RegularBookingEntity> createRegularBooking(
      RegularBookingEntity booking) {
    return _remoteDataSource
        .createRegularBooking(RegularBookingModel.fromEntity(booking));
  }

  @override
  Future<List<RegularBookingEntity>> getRegularBookings(String turfId) {
    return _remoteDataSource.getRegularBookings(turfId);
  }

  @override
  Future<void> deleteRegularBooking(String id) {
    return _remoteDataSource.deleteRegularBooking(id);
  }

  @override
  Future<void> setRegularBookingActive(String id, bool isActive) {
    return _remoteDataSource.setRegularBookingActive(id, isActive);
  }

  @override
  Future<int> sweepPastBookings(String turfId) {
    return _remoteDataSource.sweepPastBookings(turfId);
  }
}
