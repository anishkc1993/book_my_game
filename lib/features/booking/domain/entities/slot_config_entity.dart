import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Time period for slot pricing
enum SlotPeriod {
  morning, // 6 AM - 10 AM
  day, // 10 AM - 5 PM
  evening; // 5 PM - 9 PM

  String get displayName {
    switch (this) {
      case SlotPeriod.morning:
        return 'Morning';
      case SlotPeriod.day:
        return 'Day';
      case SlotPeriod.evening:
        return 'Evening';
    }
  }

  String get timeRange {
    switch (this) {
      case SlotPeriod.morning:
        return '6 AM - 10 AM';
      case SlotPeriod.day:
        return '10 AM - 5 PM';
      case SlotPeriod.evening:
        return '5 PM - 9 PM';
    }
  }
}

class SlotConfigEntity extends Equatable {
  final List<int> enabledHours;
  final double morningPrice;
  final double dayPrice;
  final double eveningPrice;
  /// Flat price for any hour booked on Saturday or Sunday. Overrides the
  /// time-of-day brackets above on weekend days.
  final double weekendPrice;
  /// Flat price for any hour booked on a marked holiday date. Overrides
  /// all other pricing tiers including weekend.
  final double holidayPrice;
  /// First hour (0-23) that counts as "Day" — anything before is "Morning".
  /// Defaults to 10 (10 AM), matching the legacy hard-coded behavior.
  final int dayStartHour;
  /// First hour (0-23) that counts as "Evening" — anything before
  /// (but after [dayStartHour]) is "Day". Defaults to 17 (5 PM).
  final int eveningStartHour;
  final DateTime? updatedAt;
  final String? updatedBy;
  /// Number of completed bookings a customer must play before they earn one
  /// free game. 0 = rewards disabled.
  final int freeGameThreshold;

  const SlotConfigEntity({
    required this.enabledHours,
    this.morningPrice = 1000.0,
    this.dayPrice = 1000.0,
    this.eveningPrice = 1200.0,
    this.weekendPrice = 1500.0,
    this.holidayPrice = 1500.0,
    this.dayStartHour = 10,
    this.eveningStartHour = 17,
    this.updatedAt,
    this.updatedBy,
    this.freeGameThreshold = 0,
  });

  /// Default configuration with all hours enabled and default prices
  factory SlotConfigEntity.defaultConfig() {
    return SlotConfigEntity(
      enabledHours: List.generate(
        AppConstants.slotEndHour - AppConstants.slotStartHour,
        (index) => AppConstants.slotStartHour + index,
      ),
      morningPrice: 1000.0,
      dayPrice: 1000.0,
      eveningPrice: 1200.0,
      weekendPrice: 1500.0,
      holidayPrice: 1500.0,
    );
  }

  /// Check if a specific hour is enabled
  bool isHourEnabled(int hour) => enabledHours.contains(hour);

  /// Get the time period for a given hour. Bands are dynamic: anything
  /// before [dayStartHour] is Morning, before [eveningStartHour] is Day,
  /// the rest is Evening.
  SlotPeriod getPeriodForHour(int hour) {
    if (hour < dayStartHour) return SlotPeriod.morning;
    if (hour < eveningStartHour) return SlotPeriod.day;
    return SlotPeriod.evening;
  }

  /// Human-readable range for a band ("6 AM – 10 AM").
  String rangeForPeriod(SlotPeriod period) {
    String fmt(int h) {
      if (h == 0) return '12 AM';
      if (h < 12) return '$h AM';
      if (h == 12) return '12 PM';
      return '${h - 12} PM';
    }

    final start = period == SlotPeriod.morning
        ? AppConstants.slotStartHour
        : (period == SlotPeriod.day ? dayStartHour : eveningStartHour);
    final end = period == SlotPeriod.morning
        ? dayStartHour
        : (period == SlotPeriod.day
            ? eveningStartHour
            : AppConstants.slotEndHour);
    return '${fmt(start)} – ${fmt(end)}';
  }

  /// Whether the given weekday (1=Mon ... 7=Sun) is a weekend day.
  static bool isWeekendDay(int weekday) =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  /// Get the price for a given hour based on time period.
  /// Holiday dates override all other pricing.
  /// If [date] falls on Sat/Sun, returns the flat weekend price.
  /// [isHoliday] — pass true when the date has been marked as a holiday.
  double getPriceForHour(int hour, {DateTime? date, bool isHoliday = false}) {
    if (isHoliday) return holidayPrice;
    if (date != null && isWeekendDay(date.weekday)) return weekendPrice;
    final period = getPeriodForHour(hour);
    switch (period) {
      case SlotPeriod.morning:
        return morningPrice;
      case SlotPeriod.day:
        return dayPrice;
      case SlotPeriod.evening:
        return eveningPrice;
    }
  }

  /// Get price for a specific period
  double getPriceForPeriod(SlotPeriod period) {
    switch (period) {
      case SlotPeriod.morning:
        return morningPrice;
      case SlotPeriod.day:
        return dayPrice;
      case SlotPeriod.evening:
        return eveningPrice;
    }
  }

  /// Get all possible hours based on app constants
  static List<int> get allPossibleHours => List.generate(
        AppConstants.slotEndHour - AppConstants.slotStartHour,
        (index) => AppConstants.slotStartHour + index,
      );

  bool get rewardsEnabled => freeGameThreshold > 0;

  @override
  List<Object?> get props => [
        enabledHours,
        morningPrice,
        dayPrice,
        eveningPrice,
        weekendPrice,
        holidayPrice,
        dayStartHour,
        eveningStartHour,
        updatedAt,
        updatedBy,
        freeGameThreshold,
      ];
}
