import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/regular_booking_entity.dart';
import '../../domain/entities/reward_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../../domain/repositories/booking_repository.dart';

enum BookingState { initial, loading, loaded, error, creating, success }
enum SlotConfigState { initial, loading, loaded, error, saving }

class BookingProvider extends ChangeNotifier {
  final BookingRepository _repository;

  BookingProvider({required BookingRepository repository})
      : _repository = repository;

  // ── Multi-tenant: current turf scope ───────────────────────────────────────
  String? _turfId;
  String? get turfId => _turfId;

  /// Called by app glue (e.g., on AuthProvider user changes) to set the
  /// active turf. Resetting the turf clears all cached state and refetches
  /// the data the dashboard cares about (so the UI doesn't get stuck empty
  /// from a race between page initState and the auth → turf sync).
  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _slots = [];
    _selectedSlot = null;
    _userBookings = [];
    _dateBookings = [];
    _todayBookings = [];
    _regulars = [];
    _slotConfig = null;
    _slotConfigState = SlotConfigState.initial;
    notifyListeners();

    if (newTurfId != null && newTurfId.isNotEmpty) {
      // Fire-and-forget: refresh today's data and slot config for the new turf.
      // The provider notifies listeners as each completes.
      fetchSlotConfig();
      fetchTodayBookings();
    }
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

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

  // Admin home: today's bookings — independent of any selected date.
  List<BookingEntity> _todayBookings = [];
  List<BookingEntity> get todayBookings => _todayBookings;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Monotonic counter bumped after any *mutation* that changes booking
  /// state (create / mark paid / status change / sweep). Other providers
  /// (analytics, leaderboard) listen for this to invalidate their caches.
  /// Listening to plain `notifyListeners()` is too noisy — that fires for
  /// every loading state change too.
  final ValueNotifier<int> mutations = ValueNotifier<int>(0);
  void _bumpMutation() => mutations.value = mutations.value + 1;

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
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedSlot = null;
    await fetchSlotsForSelectedDate();
  }

  /// Fetch slots for the selected date.
  ///
  /// [includePast] — admin override. When true, past hours on today are
  /// returned as available instead of being marked unavailable, so admins
  /// can backfill bookings for slots that have already started.
  Future<void> fetchSlotsForSelectedDate({bool includePast = false}) async {
    if (!_hasTurf) return;
    _state = BookingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _slots = (await _repository.getSlotsForDate(
        _turfId!,
        _selectedDate,
        includePast: includePast,
      ))
          .cast<SlotEntity>();
      _state = BookingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = BookingState.error;
    }

    notifyListeners();
  }

  void selectSlot(SlotEntity slot) {
    if (slot.isAvailable) {
      _selectedSlot = slot;
      notifyListeners();
    }
  }

  void clearSlotSelection() {
    _selectedSlot = null;
    notifyListeners();
  }

  /// Create a booking with auto-calculated price based on time period
  Future<bool> createBooking({
    required String userId,
    required String userPhone,
    String? remarks,
  }) async {
    if (!_hasTurf) {
      _errorMessage = 'No turf selected';
      notifyListeners();
      return false;
    }
    if (_selectedSlot == null) {
      _errorMessage = 'Please select a time slot';
      notifyListeners();
      return false;
    }

    _state = BookingState.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      final basePrice = _slotConfig?.getPriceForHour(
        _selectedSlot!.startTime.hour,
        date: _selectedSlot!.startTime,
      );

      final booking = BookingEntity(
        userId: userId,
        userPhone: userPhone,
        date: _selectedDate,
        startTime: _selectedSlot!.startTime,
        endTime: _selectedSlot!.endTime,
        remarks: remarks,
        status: BookingStatus.confirmed,
        basePrice: basePrice,
        turfId: _turfId,
      );

      _lastBooking = await _repository.createBooking(booking);
      _state = BookingState.success;

      await fetchSlotsForSelectedDate();
      _selectedSlot = null;

      notifyListeners();
      _bumpMutation();
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
    if (!_hasTurf) return;
    try {
      _userBookings = (await _repository.getUserBookings(_turfId!, userId))
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

  bool isDateSelectable(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return !normalizedDate.isBefore(normalizedToday);
  }

  // ============ Admin Methods ============

  Future<void> fetchTodayBookings() async {
    if (!_hasTurf) return;
    try {
      final today = DateTime.now();
      _todayBookings = (await _repository.getBookingsForDate(
              _turfId!, DateTime(today.year, today.month, today.day)))
          .cast<BookingEntity>();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching today bookings: $e');
    }
  }

  /// Auto-mark any past, non-cancelled, unpaid bookings as paid + completed.
  /// Returns the number of bookings updated.
  Future<int> sweepPastBookings() async {
    if (!_hasTurf) return 0;
    final updated = await _repository.sweepPastBookings(_turfId!);
    if (updated > 0) {
      // Refresh views that may have been affected.
      await fetchTodayBookings();
      if (_dateBookings.isNotEmpty) await fetchBookingsForSelectedDate();
      _bumpMutation();
    }
    return updated;
  }

  Future<void> fetchBookingsForSelectedDate() async {
    if (!_hasTurf) return;
    _state = BookingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _dateBookings =
          (await _repository.getBookingsForDate(_turfId!, _selectedDate))
              .cast<BookingEntity>();
      _state = BookingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = BookingState.error;
    }

    notifyListeners();
  }

  Future<bool> createAdminBooking(BookingEntity booking) async {
    if (!_hasTurf) return false;
    _state = BookingState.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      // Force turfId on the booking — admins create within their own turf.
      final scoped =
          booking.turfId == _turfId ? booking : _withTurf(booking, _turfId!);
      _lastBooking = await _repository.createAdminBooking(scoped);
      _state = BookingState.success;

      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();
      await fetchTodayBookings();

      notifyListeners();
      _bumpMutation();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = BookingState.error;
      notifyListeners();
      return false;
    }
  }

  BookingEntity _withTurf(BookingEntity b, String turfId) {
    return BookingEntity(
      id: b.id,
      userId: b.userId,
      userPhone: b.userPhone,
      customerName: b.customerName,
      date: b.date,
      startTime: b.startTime,
      endTime: b.endTime,
      remarks: b.remarks,
      status: b.status,
      isPaid: b.isPaid,
      basePrice: b.basePrice,
      amountPaid: b.amountPaid,
      paidAt: b.paidAt,
      createdByAdmin: b.createdByAdmin,
      createdAt: b.createdAt,
      isRegular: b.isRegular,
      regularBookingId: b.regularBookingId,
      turfId: turfId,
    );
  }

  Future<bool> markAsPaid(String bookingId, double amount) async {
    try {
      await _repository.markBookingAsPaid(bookingId, amount);
      await fetchBookingsForSelectedDate();
      await fetchTodayBookings();
      _bumpMutation();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    try {
      await _repository.updateBookingStatus(bookingId, status);
      await fetchBookingsForSelectedDate();
      await fetchTodayBookings();
      _bumpMutation();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

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

  Future<void> fetchSlotConfig() async {
    if (!_hasTurf) return;
    _slotConfigState = SlotConfigState.loading;
    _slotConfigError = null;
    notifyListeners();

    try {
      _slotConfig = await _repository.getSlotConfig(_turfId!);
      _slotConfigState = SlotConfigState.loaded;
    } catch (e) {
      _slotConfigError = e.toString().replaceAll('Exception: ', '');
      _slotConfigState = SlotConfigState.error;
    }

    notifyListeners();
  }

  Future<bool> toggleSlotHour(int hour, String adminId) async {
    if (!_hasTurf || _slotConfig == null) return false;

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

      await _repository.updateSlotConfig(_turfId!, currentHours, adminId);

      _slotConfig = SlotConfigEntity(
        enabledHours: currentHours,
        morningPrice: _slotConfig!.morningPrice,
        dayPrice: _slotConfig!.dayPrice,
        eveningPrice: _slotConfig!.eveningPrice,
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

  Future<bool> updateSlotPricing({
    required double morningPrice,
    required double dayPrice,
    required double eveningPrice,
    required double weekendPrice,
    required String adminId,
  }) async {
    if (!_hasTurf || _slotConfig == null) return false;

    _slotConfigState = SlotConfigState.saving;
    notifyListeners();

    try {
      await _repository.updateSlotPricing(
        turfId: _turfId!,
        morningPrice: morningPrice,
        dayPrice: dayPrice,
        eveningPrice: eveningPrice,
        weekendPrice: weekendPrice,
        updatedBy: adminId,
      );

      _slotConfig = SlotConfigEntity(
        enabledHours: _slotConfig!.enabledHours,
        morningPrice: morningPrice,
        dayPrice: dayPrice,
        eveningPrice: eveningPrice,
        weekendPrice: weekendPrice,
        updatedAt: DateTime.now(),
        updatedBy: adminId,
        freeGameThreshold: _slotConfig!.freeGameThreshold,
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

  double? getPriceForHour(int hour, {DateTime? date}) =>
      _slotConfig?.getPriceForHour(hour, date: date);

  /// Resolve the right price for a regular booking. If any of the selected
  /// weekly days is Sat/Sun, the flat weekend rate applies.
  double? getPriceForRegular(int hour, List<int> daysOfWeek) {
    if (_slotConfig == null) return null;
    if (daysOfWeek.any(SlotConfigEntity.isWeekendDay)) {
      return _slotConfig!.weekendPrice;
    }
    return _slotConfig!.getPriceForHour(hour);
  }
  SlotPeriod? getPeriodForHour(int hour) => _slotConfig?.getPeriodForHour(hour);
  bool isHourEnabled(int hour) => _slotConfig?.isHourEnabled(hour) ?? true;
  List<int> get allPossibleHours => SlotConfigEntity.allPossibleHours;

  // ============ Regular Bookings ============

  List<RegularBookingEntity> _regulars = [];
  List<RegularBookingEntity> get regulars => _regulars;

  bool _regularsLoading = false;
  bool get regularsLoading => _regularsLoading;

  String? _regularsError;
  String? get regularsError => _regularsError;

  Future<void> fetchRegularBookings() async {
    if (!_hasTurf) return;
    _regularsLoading = true;
    _regularsError = null;
    notifyListeners();
    try {
      _regulars = await _repository.getRegularBookings(_turfId!);
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _regularsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRegularBooking({
    required String customerName,
    required String userPhone,
    required List<int> daysOfWeek,
    required int startHour,
    required DateTime startDate,
    String? notes,
    required String adminId,
    /// When set (>0), use this price verbatim instead of deriving from
    /// slot config. Lets admins negotiate custom rates with regulars.
    double? basePriceOverride,
  }) async {
    if (!_hasTurf) return false;
    try {
      double basePrice;
      if (basePriceOverride != null && basePriceOverride > 0) {
        basePrice = basePriceOverride;
      } else {
        // If any of the selected days is Sat/Sun, charge the flat weekend rate.
        final hasWeekend =
            daysOfWeek.any(SlotConfigEntity.isWeekendDay);
        basePrice = hasWeekend
            ? (_slotConfig?.weekendPrice ?? 0)
            : (_slotConfig?.getPriceForHour(startHour) ?? 0);
      }
      final entity = RegularBookingEntity(
        customerName: customerName,
        userPhone: userPhone,
        daysOfWeek: daysOfWeek,
        startHour: startHour,
        basePrice: basePrice,
        startDate: DateTime(startDate.year, startDate.month, startDate.day),
        isActive: true,
        notes: notes,
        createdByAdmin: adminId,
        turfId: _turfId,
      );
      final created = await _repository.createRegularBooking(entity);
      _regulars = [created, ..._regulars];
      if (created.appliesTo(_selectedDate)) {
        await fetchBookingsForSelectedDate();
        await fetchSlotsForSelectedDate();
      }
      if (created.appliesTo(DateTime.now())) {
        await fetchTodayBookings();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRegularBooking(String id) async {
    try {
      await _repository.deleteRegularBooking(id);
      _regulars = _regulars.where((r) => r.id != id).toList();
      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();
      await fetchTodayBookings();
      notifyListeners();
      return true;
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> setRegularBookingActive(String id, bool isActive) async {
    try {
      await _repository.setRegularBookingActive(id, isActive);
      _regulars = _regulars
          .map((r) => r.id == id ? r.copyWith(isActive: isActive) : r)
          .toList();
      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();
      await fetchTodayBookings();
      notifyListeners();
      return true;
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Edit an existing regular booking template. The caller supplies the
  /// price on [updated] — admins can set custom rates from the edit sheet.
  Future<bool> updateRegularBooking(RegularBookingEntity updated) async {
    if (!_hasTurf || updated.id == null) return false;
    try {
      final scoped = updated.copyWith(turfId: _turfId);
      final saved = await _repository.updateRegularBooking(scoped);
      _regulars =
          _regulars.map((r) => r.id == saved.id ? saved : r).toList();
      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();
      await fetchTodayBookings();
      notifyListeners();
      return true;
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Materialize a regular's occurrence on [date] as a real, paid booking.
  /// Use this when admin collects payment from a regular customer for a
  /// specific session — the materialized booking flows into analytics,
  /// leaderboard, and rewards just like a normal walk-in.
  Future<bool> markRegularPaidForDate({
    required RegularBookingEntity regular,
    required DateTime date,
    required double amount,
    required String adminId,
  }) async {
    if (!_hasTurf) return false;
    try {
      final day = DateTime(date.year, date.month, date.day);
      final start = DateTime(day.year, day.month, day.day, regular.startHour);
      final end = start.add(const Duration(hours: 1));
      final booking = BookingEntity(
        userId: '',
        userPhone: regular.userPhone,
        customerName: regular.customerName,
        date: day,
        startTime: start,
        endTime: end,
        status: BookingStatus.completed,
        isPaid: true,
        basePrice: regular.basePrice,
        amountPaid: amount,
        paidAt: DateTime.now(),
        createdByAdmin: adminId,
        createdAt: DateTime.now(),
        isRegular: true,
        regularBookingId: regular.id,
        turfId: _turfId,
      );
      await _repository.createAdminBooking(booking);
      await fetchBookingsForSelectedDate();
      await fetchSlotsForSelectedDate();
      await fetchTodayBookings();
      _bumpMutation();
      return true;
    } catch (e) {
      _regularsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ============ Loyalty Rewards ============

  /// Current user's reward progress (refreshed via [fetchMyReward]).
  RewardEntity? _myReward;
  RewardEntity? get myReward => _myReward;

  /// All rewards in the current turf (admin view).
  Map<String, RewardEntity> _rewardsByPhone = {};
  Map<String, RewardEntity> get rewardsByPhone => _rewardsByPhone;

  /// Lookup a reward for a specific phone from the cached admin map.
  RewardEntity? rewardFor(String phone) => _rewardsByPhone[phone];

  int get freeGameThreshold => _slotConfig?.freeGameThreshold ?? 0;
  bool get rewardsEnabled => freeGameThreshold > 0;

  Future<void> fetchMyReward(String phone) async {
    if (!_hasTurf) return;
    try {
      _myReward = await _repository.getReward(_turfId!, phone);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching reward: $e');
    }
  }

  Future<void> fetchAllRewards() async {
    if (!_hasTurf) return;
    try {
      final list = await _repository.listRewards(_turfId!);
      _rewardsByPhone = {for (final r in list) r.userPhone: r};
      notifyListeners();
    } catch (e) {
      debugPrint('Error listing rewards: $e');
    }
  }

  Future<bool> claimFreeGame(String phone) async {
    if (!_hasTurf) return false;
    try {
      await _repository.claimFreeGame(_turfId!, phone);
      // Refresh local view.
      _rewardsByPhone = {
        ..._rewardsByPhone,
        phone: RewardEntity(
          userPhone: phone,
          progressCount: 0,
          totalClaimed: (_rewardsByPhone[phone]?.totalClaimed ?? 0) + 1,
          lastClaimedAt: DateTime.now(),
        ),
      };
      // If it was the current user, refresh personal copy too.
      if (_myReward?.userPhone == phone) {
        _myReward = _rewardsByPhone[phone];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Persist a new free-game threshold (admin-only).
  Future<bool> updateRewardsThreshold({
    required int threshold,
    required String adminId,
  }) async {
    if (!_hasTurf || _slotConfig == null) return false;
    _slotConfigState = SlotConfigState.saving;
    notifyListeners();
    try {
      await _repository.updateSlotPricing(
        turfId: _turfId!,
        morningPrice: _slotConfig!.morningPrice,
        dayPrice: _slotConfig!.dayPrice,
        eveningPrice: _slotConfig!.eveningPrice,
        weekendPrice: _slotConfig!.weekendPrice,
        updatedBy: adminId,
        freeGameThreshold: threshold,
      );
      _slotConfig = SlotConfigEntity(
        enabledHours: _slotConfig!.enabledHours,
        morningPrice: _slotConfig!.morningPrice,
        dayPrice: _slotConfig!.dayPrice,
        eveningPrice: _slotConfig!.eveningPrice,
        weekendPrice: _slotConfig!.weekendPrice,
        updatedAt: DateTime.now(),
        updatedBy: adminId,
        freeGameThreshold: threshold,
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
}
