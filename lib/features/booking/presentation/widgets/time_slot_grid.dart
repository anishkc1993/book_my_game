import 'package:flutter/material.dart';

import '../../domain/entities/slot_entity.dart';

class TimeSlotGrid extends StatelessWidget {
  final List<SlotEntity> slots;
  final SlotEntity? selectedSlot;
  final Function(SlotEntity) onSlotSelected;

  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No slots available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return TimeSlotCard(
          slot: slot,
          isSelected: selectedSlot?.id == slot.id,
          onTap: () => onSlotSelected(slot),
        );
      },
    );
  }
}

class TimeSlotCard extends StatelessWidget {
  final SlotEntity slot;
  final bool isSelected;
  final VoidCallback onTap;

  const TimeSlotCard({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isAvailable = slot.isAvailable;
    final isBooked = slot.isBooked;
    final isUnavailable = slot.isUnavailable;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    String statusText;
    IconData statusIcon;

    if (isSelected) {
      backgroundColor = colorScheme.primary;
      borderColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
      iconColor = colorScheme.onPrimary;
      statusText = 'Selected';
      statusIcon = Icons.check_circle_rounded;
    } else if (isUnavailable) {
      // Past time slots
      backgroundColor = colorScheme.surfaceContainerLow.withValues(alpha: 0.5);
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
      textColor = colorScheme.onSurface.withValues(alpha: 0.4);
      iconColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
      statusText = 'Passed';
      statusIcon = Icons.history_rounded;
    } else if (isBooked) {
      backgroundColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      borderColor = colorScheme.error.withValues(alpha: 0.3);
      textColor = colorScheme.onSurface.withValues(alpha: 0.5);
      iconColor = colorScheme.error.withValues(alpha: 0.5);
      statusText = 'Booked';
      statusIcon = Icons.event_busy_rounded;
    } else if (isAvailable) {
      backgroundColor = colorScheme.surfaceContainerLow;
      borderColor = Colors.green.withValues(alpha: 0.3);
      textColor = colorScheme.onSurface;
      iconColor = Colors.green;
      statusText = 'Available';
      statusIcon = Icons.access_time_rounded;
    } else {
      backgroundColor = colorScheme.surfaceContainerLow;
      borderColor = colorScheme.outlineVariant;
      textColor = colorScheme.onSurface.withValues(alpha: 0.5);
      iconColor = colorScheme.onSurfaceVariant;
      statusText = 'Blocked';
      statusIcon = Icons.block_rounded;
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              // Time Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.timeRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
