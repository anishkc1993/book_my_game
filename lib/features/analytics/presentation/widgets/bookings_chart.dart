import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

class BookingsHourlyChart extends StatelessWidget {
  final Map<int, int> bookingsByHour;

  const BookingsHourlyChart({
    super.key,
    required this.bookingsByHour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Generate data for all hours
    final hours = List.generate(
      AppConstants.slotEndHour - AppConstants.slotStartHour,
      (i) => AppConstants.slotStartHour + i,
    );

    final maxValue = bookingsByHour.values.isEmpty
        ? 1
        : bookingsByHour.values.reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = (maxValue * 1.2).toDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: effectiveMaxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colorScheme.inverseSurface,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = hours[group.x.toInt()];
                return BarTooltipItem(
                  '${_formatHour(hour)}\n${rod.toY.toInt()} bookings',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= hours.length) {
                    return const SizedBox.shrink();
                  }
                  // Show every 3rd hour
                  if (index % 3 != 0) {
                    return const SizedBox.shrink();
                  }
                  final hour = hours[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatHourShort(hour),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 25,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 1,
              );
            },
          ),
          barGroups: hours.asMap().entries.map((entry) {
            final hour = entry.value;
            final count = bookingsByHour[hour] ?? 0;
            final isPopular = count == maxValue && count > 0;

            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: isPopular
                      ? colorScheme.tertiary
                      : colorScheme.primary.withValues(alpha: 0.7),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatHourShort(int hour) {
    if (hour == 0) return '12A';
    if (hour < 12) return '${hour}A';
    if (hour == 12) return '12P';
    return '${hour - 12}P';
  }
}
