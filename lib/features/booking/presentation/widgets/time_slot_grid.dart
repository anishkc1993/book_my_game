import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/entities/slot_entity.dart';

class TimeSlotGrid extends StatelessWidget {
  final List<SlotEntity> slots;
  final SlotEntity? selectedSlot;
  final Function(SlotEntity) onSlotSelected;
  final SlotConfigEntity? slotConfig;

  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
    this.slotConfig,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No slots available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final price = slotConfig?.getPriceForHour(slot.startTime.hour,
            date: slot.startTime);
        return TimeSlotCard(
          slot: slot,
          isSelected: selectedSlot?.id == slot.id,
          onTap: () => onSlotSelected(slot),
          price: price,
        );
      },
    );
  }
}

class TimeSlotCard extends StatelessWidget {
  final SlotEntity slot;
  final bool isSelected;
  final VoidCallback onTap;
  final double? price;

  const TimeSlotCard({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onTap,
    this.price,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isPast = slot.isUnavailable;
    final isPlayed = slot.isPlayed;
    final isBooked = slot.isBooked || slot.isBlocked;
    final isAvailable = slot.isAvailable;

    // Determine visual state
    Color bgColor;
    Color borderColor;
    Widget leftIndicator;
    Color timeColor;
    Color labelColor;
    String labelText;
    Widget? rightWidget;

    if (isSelected) {
      bgColor = AppColors.brandGreen;
      borderColor = AppColors.brandGreen;
      timeColor = Colors.white;
      labelColor = Colors.white70;
      labelText = 'Selected';
      leftIndicator = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
      rightWidget = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 12,
          color: AppColors.brandGreen,
        ),
      );
    } else if (isPlayed) {
      bgColor = const Color(0xFF2563EB).withValues(alpha: 0.06);
      borderColor = const Color(0xFF2563EB).withValues(alpha: 0.25);
      timeColor = cs.onSurface.withValues(alpha: 0.45);
      labelColor = const Color(0xFF2563EB);
      labelText = 'Played';
      leftIndicator = const Icon(
        Icons.check_circle_rounded,
        size: 14,
        color: Color(0xFF2563EB),
      );
      rightWidget = null;
    } else if (isPast) {
      bgColor = AppColors.brandGreen.withValues(alpha: 0.06);
      borderColor = AppColors.brandGreen.withValues(alpha: 0.15);
      timeColor = AppColors.brandGreen.withValues(alpha: 0.5);
      labelColor = AppColors.brandGreen.withValues(alpha: 0.4);
      labelText = 'Past';
      leftIndicator = Icon(
        Icons.history_rounded,
        size: 14,
        color: AppColors.brandGreen.withValues(alpha: 0.4),
      );
      rightWidget = null;
    } else if (isBooked) {
      bgColor = cs.error.withValues(alpha: 0.06);
      borderColor = cs.error.withValues(alpha: 0.2);
      timeColor = cs.onSurface.withValues(alpha: 0.45);
      labelColor = cs.error.withValues(alpha: 0.7);
      labelText = 'Booked';
      leftIndicator = Icon(
        Icons.lock_rounded,
        size: 14,
        color: cs.error.withValues(alpha: 0.6),
      );
      rightWidget = null;
    } else if (isAvailable) {
      bgColor = cs.surfaceContainerLow;
      borderColor = cs.outlineVariant;
      timeColor = cs.onSurface;
      labelColor = AppColors.brandGreen;
      labelText = price != null ? 'Rs. ${price!.toInt()}' : 'Available';
      leftIndicator = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.brandGreen,
          shape: BoxShape.circle,
        ),
      );
      rightWidget = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.outlineVariant,
            width: 1.5,
          ),
        ),
      );
    } else {
      // Fallback (blocked)
      bgColor = cs.surfaceContainerLow.withValues(alpha: 0.5);
      borderColor = cs.outlineVariant.withValues(alpha: 0.3);
      timeColor = cs.onSurface.withValues(alpha: 0.35);
      labelColor = cs.onSurface.withValues(alpha: 0.25);
      labelText = 'Blocked';
      leftIndicator = Icon(
        Icons.block_rounded,
        size: 14,
        color: cs.onSurface.withValues(alpha: 0.25),
      );
      rightWidget = null;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Left indicator (dot or icon)
              leftIndicator,
              const SizedBox(width: 8),
              // Center: time + label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.timeRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: timeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: radio circle or check
              if (rightWidget != null) ...[
                const SizedBox(width: 6),
                rightWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
