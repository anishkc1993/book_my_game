import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

class SlotConfigEntity extends Equatable {
  final List<int> enabledHours;
  final DateTime? updatedAt;
  final String? updatedBy;

  const SlotConfigEntity({
    required this.enabledHours,
    this.updatedAt,
    this.updatedBy,
  });

  /// Default configuration with all hours enabled
  factory SlotConfigEntity.defaultConfig() {
    return SlotConfigEntity(
      enabledHours: List.generate(
        AppConstants.slotEndHour - AppConstants.slotStartHour,
        (index) => AppConstants.slotStartHour + index,
      ),
    );
  }

  /// Check if a specific hour is enabled
  bool isHourEnabled(int hour) => enabledHours.contains(hour);

  /// Get all possible hours based on app constants
  static List<int> get allPossibleHours => List.generate(
        AppConstants.slotEndHour - AppConstants.slotStartHour,
        (index) => AppConstants.slotStartHour + index,
      );

  @override
  List<Object?> get props => [enabledHours, updatedAt, updatedBy];
}
