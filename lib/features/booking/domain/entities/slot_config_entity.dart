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
  final DateTime? updatedAt;
  final String? updatedBy;

  const SlotConfigEntity({
    required this.enabledHours,
    this.morningPrice = 1000.0,
    this.dayPrice = 1000.0,
    this.eveningPrice = 1200.0,
    this.updatedAt,
    this.updatedBy,
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
    );
  }

  /// Check if a specific hour is enabled
  bool isHourEnabled(int hour) => enabledHours.contains(hour);

  /// Get the time period for a given hour
  SlotPeriod getPeriodForHour(int hour) {
    if (hour >= 6 && hour < 10) return SlotPeriod.morning;
    if (hour >= 10 && hour < 17) return SlotPeriod.day;
    return SlotPeriod.evening; // 17-20
  }

  /// Get the price for a given hour based on time period
  double getPriceForHour(int hour) {
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

  @override
  List<Object?> get props => [
        enabledHours,
        morningPrice,
        dayPrice,
        eveningPrice,
        updatedAt,
        updatedBy,
      ];
}
