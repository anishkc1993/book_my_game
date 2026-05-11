import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../../domain/repositories/booking_repository.dart';

enum BookingState { initial, loading, loaded, error, creating, success }
enum SlotConfigState { initial, loading, loaded, error, saving }

class BookingProvider extends ChangeNotifier {
  final BookingRepository _repository;

  BookingProvider({required BookingRepository repository})
      : _repository = repository;

  BookingState _state = BookingState.initial;
  BookingState get state => _state;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  List<SlotEntity> _slots = [];
  List<SlotEntity> get slots => _slots;

  SlotEntity? _selectedSlot;
  SlotEntity? get selectedSlot => _selectedSlot;

  List<BookingEntity> _userBookings = [];
  List<BookingEntity> get userBookings => _userBookings;

  // Admin: bookings for selected date
  List<BookingEntity> _dateBookings = [];
  List<BookingEntity> get dateBookings => _dateBookings;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BookingEntity? _lastBooking;
  BookingEntity? get lastBooking => _lastBooking;

  // Slot configuration state
  SlotConfigState _slotConfigState = SlotConfigState.initial;
  SlotConfigState get slotConfigState => _slotConfigState;

  SlotConfigEntity? _slotConfig;
  SlotConfigEntity? get slotConfig => _slotConfig;

  String? _slotConfigError;
  String? get slotConfigError => _slotConfigError;

  /// Select a date and fetch available slots
  Future<void> selectDate(DateTime date) async {
    // Normalize to start of day
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedSlot = null;
    await fetchSlotsForSelectedDate();
  }

  /// Fetch slots for the selected date
  Future<void> fetchSlotsForSelectedDate() async {
    _state = BookingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _slots = (await _repository.getSlotsForDate(_selectedDate))
          .cast<SlotEntity>();
      _state = BookingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = BookingState.error;
    }

    notifyListeners();
  }

  /// Select a time slot
  void selectSlot(SlotEntity slot) {
    if (slot.isAvailable) {
      _selectedSlot = slot;
      notifyListeners();
    }
  }

  /// Clear slot selection
  void clearSlotSelection() {
    _selectedSlot = null;
    notifyListeners();
  }

  /// Create a booking
  Future<bool> createBooking({
    required String userId,
    required String userPhone,
    String? remarks,
  }) async {
    if (_selectedSlot == null) {
      _errorMessage = 'Please select a time slot';
      notifyListeners();
      return false;
    }

    _state = BookingState.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = BookingEntity(
        userId: userId,
        userPhone: userPhone,
        date: _selectedDate,
        startTime: _selectedSlot!.startTime,
        endTime: _selectedSlot!.endTime,
        remarks: remarks,
        status: BookingStatus.confirmed,
      );

      _lastBooking = await _repository.createBooking(booking);
      _state = BookingState.success;

      // Refresh slots after booking
      await fetchSlotsForSelectedDate();
      _selectedSlot = null;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = BookingState.error;
      notifyListeners();
      return false;
    }
  }

  /// Fetch user's bookings
  Future<void> fetchUserBookings(String userId) async {
    try {
      _userBookings = (await _repository.getUserBookings(userId))
          .cast<BookingEntity>();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user bookings: $e');
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _repository.cancelBooking(bookingId);
      // Refresh user bookings
      if (_userBookings.isNotEmpty) {
        final userId = _userBookings.first.userId;
        await fetchUserBookings(userId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Check if a date is today or in the future
  bool isDateSelectable(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return !normalizedDate.isBefore(normalizedToday);
  }

  // ============ Admin Methods ============

  /// Fetch all bookings for the selected date (admin)
  Future<void> fetchBookingsForSelectedDate() async {
    _state = BookingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _dateBookings = (await _repository.getBookingsForDate(_selectedDate))
          .cast<BookingEntity>();
      _state = BookingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = BookingState.error;
    }

    notifyListeners();
  }

  /// Create a booking as admin (bypasses one-booking limit)
  Future<bool> createAdminBooking(BookingEntity booking) async {
    _state = BookingState.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastBooking = await _repository.createAdminBooking(booking);
      _state = BookingState.success;

      // Refresh bookings and slots for the date
      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = BookingState.error;
      notifyListeners();
      return false;
    }
  }

  /// Mark a booking as paid (admin)
  Future<bool> markAsPaid(String bookingId, double amount) async {
    try {
      await _repository.markBookingAsPaid(bookingId, amount);
      // Refresh bookings for the date
      await fetchBookingsForSelectedDate();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update booking status (admin)
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
    try {
      await _repository.updateBookingStatus(bookingId, status);
      // Refresh bookings for the date
      await fetchBookingsForSelectedDate();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reset state
  void reset() {
    _state = BookingState.initial;
    _selectedDate = DateTime.now();
    _slots = [];
    _selectedSlot = null;
    _errorMessage = null;
    _lastBooking = null;
    notifyListeners();
  }

  // ============ Slot Configuration Methods ============

  /// Fetch slot configuration
  Future<void> fetchSlotConfig() async {
    _slotConfigState = SlotConfigState.loading;
    _slotConfigError = null;
    notifyListeners();

    try {
      _slotConfig = await _repository.getSlotConfig();
      _slotConfigState = SlotConfigState.loaded;
    } catch (e) {
      _slotConfigError = e.toString().replaceAll('Exception: ', '');
      _slotConfigState = SlotConfigState.error;
    }

    notifyListeners();
  }

  /// Toggle a slot hour on/off
  Future<bool> toggleSlotHour(int hour, String adminId) async {
    if (_slotConfig == null) return false;

    _slotConfigState = SlotConfigState.saving;
    notifyListeners();

    try {
      final currentHours = List<int>.from(_slotConfig!.enabledHours);

      if (currentHours.contains(hour)) {
        currentHours.remove(hour);
      } else {
        currentHours.add(hour);
        currentHours.sort();
      }

      await _repository.updateSlotConfig(currentHours, adminId);

      // Update local state
      _slotConfig = SlotConfigEntity(
        enabledHours: currentHours,
        updatedAt: DateTime.now(),
        updatedBy: adminId,
      );
      _slotConfigState = SlotConfigState.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _slotConfigError = e.toString().replaceAll('Exception: ', '');
      _slotConfigState = SlotConfigState.error;
      notifyListeners();
      return false;
    }
  }

  /// Check if a specific hour is enabled
  bool isHourEnabled(int hour) {
    return _slotConfig?.isHourEnabled(hour) ?? true;
  }

  /// Get all possible slot hours
  List<int> get allPossibleHours => SlotConfigEntity.allPossibleHours;
}
