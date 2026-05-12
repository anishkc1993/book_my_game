import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/analytics_entity.dart';

class RevenueChart extends StatelessWidget {
  final List<DailyMetric> data;
  final TimePeriod period;

  const RevenueChart({
    super.key,
    required this.data,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (data.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No revenue data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = maxValue > 0 ? maxValue * 1.2 : 1000.0;

    return Container(
      height: 200,
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
                return BarTooltipItem(
                  'Rs. ${rod.toY.toInt()}',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final date = data[index].date;
                  String label;
                  if (period == TimePeriod.today) {
                    label = 'Today';
                  } else if (period == TimePeriod.week) {
                    label = _getWeekdayShort(date.weekday);
                  } else {
                    // Show every 5th day for month
                    if (index % 5 == 0 || index == data.length - 1) {
                      label = '${date.day}';
                    } else {
                      return const SizedBox.shrink();
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _formatAmount(value),
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
          barGroups: data.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  color: colorScheme.primary,
                  width: period == TimePeriod.month ? 6 : 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _formatAmount(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toInt().toString();
  }
}
