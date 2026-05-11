import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../models/booking_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl({required BookingRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<SlotEntity>> getSlotsForDate(DateTime date) {
    return _remoteDataSource.getSlotsForDate(date);
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
  Future<List<BookingEntity>> getUserBookings(String userId) {
    return _remoteDataSource.getUserBookings(userId);
  }

  @override
  Future<List<BookingEntity>> getBookingsForDate(DateTime date) {
    return _remoteDataSource.getBookingsForDate(date);
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
  Future<SlotConfigEntity> getSlotConfig() {
    return _remoteDataSource.getSlotConfig();
  }

  @override
  Future<void> updateSlotConfig(List<int> enabledHours, String updatedBy) {
    return _remoteDataSource.updateSlotConfig(enabledHours, updatedBy);
  }
}
