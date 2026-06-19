import 'package:equatable/equatable.dart';

/// Per-customer loyalty progress at a given turf.
///
/// Cycle:
/// - `progressCount` increments every time one of the customer's bookings is
///   marked COMPLETED.
/// - When `progressCount >= threshold` (from slot config), the customer
///   becomes eligible for one free game.
/// - Admin claims the reward → `progressCount` resets to 0,
///   `totalClaimed` increments.
class RewardEntity extends Equatable {
  final String userPhone;
  final int progressCount;
  final int totalClaimed;
  final DateTime? lastUpdated;
  final DateTime? lastClaimedAt;

  const RewardEntity({
    required this.userPhone,
    this.progressCount = 0,
    this.totalClaimed = 0,
    this.lastUpdated,
    this.lastClaimedAt,
  });

  bool isEligible(int threshold) =>
      threshold > 0 && progressCount >= threshold;

  int gamesToNextReward(int threshold) {
    if (threshold <= 0) return 0;
    final remaining = threshold - progressCount;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  List<Object?> get props => [
        userPhone,
        progressCount,
        totalClaimed,
        lastUpdated,
        lastClaimedAt,
      ];
}
