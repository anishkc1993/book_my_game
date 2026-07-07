import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/yearly_revenue_entity.dart';
import '../providers/analytics_provider.dart';

class YearlyRevenuePage extends StatefulWidget {
  const YearlyRevenuePage({super.key});

  @override
  State<YearlyRevenuePage> createState() => _YearlyRevenuePageState();
}

class _YearlyRevenuePageState extends State<YearlyRevenuePage> {
  /// First year BMG was live — no point listing years before launch.
  static const int _launchYear = 2026;

  late int _selectedYear;
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _selectedYear = currentYear < _launchYear ? _launchYear : currentYear;
    // Auto-extends as the calendar year ticks over — e.g., comes 2027,
    // the list becomes [2027, 2026] without any code change.
    _years = [
      for (int y = _selectedYear; y >= _launchYear; y--) y,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always force-refresh on entry. The in-memory cache only
      // invalidates on a mutation event; without that, opening the page
      // on a later calendar day shows the snapshot from the previous
      // session.
      context
          .read<AnalyticsProvider>()
          .fetchYearly(_selectedYear, forceRefresh: true);
    });
  }

  void _pickYear(int year) {
    if (year == _selectedYear) return;
    setState(() => _selectedYear = year);
    // Same reasoning — fresh data for the newly-selected year.
    context
        .read<AnalyticsProvider>()
        .fetchYearly(year, forceRefresh: true);
  }

  Future<void> _refresh() async {
    await context
        .read<AnalyticsProvider>()
        .fetchYearly(_selectedYear, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<AnalyticsProvider>(
          builder: (context, provider, _) {
            final data = provider.yearlyFor(_selectedYear);
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.brandGreen,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ───────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: cs.outlineVariant),
                              ),
                              child: Icon(Icons.arrow_back_rounded,
                                  size: 18, color: cs.onSurface),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analytics',
                                  style:
                                      theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Revenue · month by month',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Year selector ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _years.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final y = _years[i];
                            return _YearChip(
                              year: y,
                              selected: y == _selectedYear,
                              isCurrentYear: y == DateTime.now().year,
                              onTap: () => _pickYear(y),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // ── Loading / content ───────────────────────────────────
                  if (data == null &&
                      provider.yearlyState == AnalyticsState.loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            provider.yearlyError ?? 'No data',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _TotalCard(data: data)),
                    SliverToBoxAdapter(child: _StatsRow(data: data)),
                    SliverToBoxAdapter(child: _MonthChart(data: data)),
                    SliverToBoxAdapter(child: _MonthList(data: data)),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Year chip ────────────────────────────────────────────────────────────────

class _YearChip extends StatelessWidget {
  final int year;
  final bool selected;
  final bool isCurrentYear;
  final VoidCallback onTap;
  const _YearChip({
    required this.year,
    required this.selected,
    required this.isCurrentYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? cs.outline : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$year',
              style: theme.textTheme.titleMedium?.copyWith(
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isCurrentYear) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.limeAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'YTD',
                  style: TextStyle(
                    color: Color(0xFF0F2B06),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Total card ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final YearlyRevenueEntity data;
  const _TotalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final yoy = data.yoyChangePercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL REVENUE · ${data.year}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs. ${_formatIndian(data.totalRevenue)}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (yoy != null) ...[
                  _YoyPill(percent: yoy, previousYear: data.year - 1),
                  const SizedBox(width: 12),
                ],
                Text(
                  '${data.totalBookings} bookings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YoyPill extends StatelessWidget {
  final double percent;
  final int previousYear;
  const _YoyPill({required this.percent, required this.previousYear});

  @override
  Widget build(BuildContext context) {
    final positive = percent >= 0;
    final color = positive
        ? AppColors.brandGreen
        : const Color(0xFFE05757);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '${positive ? "+" : ""}${percent.toStringAsFixed(0)} % vs $previousYear',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row (Avg / Best) ──────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final YearlyRevenueEntity data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final best = data.bestMonth;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFF2563EB).withValues(alpha: 0.15),
              value: 'Rs. ${_formatShort(data.averageMonthly)}',
              label: 'Avg / month',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.emoji_events_outlined,
              iconColor: AppColors.brandGreen,
              iconBg: AppColors.brandGreen.withValues(alpha: 0.15),
              value: best == null ? '—' : _monthShort(best.month),
              label: 'Best month',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month-wise bar chart ────────────────────────────────────────────────────

class _MonthChart extends StatelessWidget {
  final YearlyRevenueEntity data;
  const _MonthChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxVal = data.monthly
        .map((m) => m.revenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month-wise division',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal <= 0 ? 1 : maxVal * 1.1,
                  // Faint horizontal grid lines at each Y-axis tick so the
                  // axis labels have something to anchor to.
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        maxVal <= 0 ? 1 : (maxVal * 1.1) / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval:
                            maxVal <= 0 ? 1 : (maxVal * 1.1) / 4,
                        getTitlesWidget: (value, _) {
                          if (value <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              'Rs.${_formatShort(value)}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, _) {
                          final m = value.toInt() + 1;
                          if (m < 1 || m > 12) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _monthLetter(m),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      getTooltipItem: (group, _, rod, __) {
                        final m = group.x + 1;
                        return BarTooltipItem(
                          '${_monthShort(m)}\nRs. ${_formatIndian(rod.toY)}',
                          TextStyle(
                            color: cs.onInverseSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(12, (i) {
                    final m = data.monthly[i];
                    final hasValue = m.revenue > 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hasValue ? m.revenue : 0,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: hasValue
                              ? AppColors.brandGreen
                              : cs.surfaceContainerHighest,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Monthly breakdown list ──────────────────────────────────────────────────

class _MonthList extends StatelessWidget {
  final YearlyRevenueEntity data;
  const _MonthList({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final m in data.monthly.where((x) => x.revenue > 0)) ...[
            _MonthRow(
              month: m,
              year: data.year,
              total: data.totalRevenue,
            ),
            const SizedBox(height: 10),
          ],
          if (data.monthly.every((m) => m.revenue <= 0))
            _MonthRow(
              month: data.monthly[DateTime.now().month - 1],
              year: data.year,
              total: 0,
              emptyHint: 'No revenue recorded yet for ${data.year}',
            ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final MonthlyRevenue month;
  final int year;
  final double total;
  final String? emptyHint;
  const _MonthRow({
    required this.month,
    required this.year,
    required this.total,
    this.emptyHint,
  });

  /// Slots that were actually bookable in this month, capped at "today"
  /// for the current month (so YTD months don't get penalized for days
  /// that haven't happened yet).
  int _availableSlots() {
    final hoursPerDay =
        AppConstants.slotEndHour - AppConstants.slotStartHour;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month.month == now.month;
    final isFutureMonth = year > now.year ||
        (year == now.year && month.month > now.month);
    if (isFutureMonth) return 0;
    final daysInMonth = DateTime(year, month.month + 1, 0).day;
    final days = isCurrentMonth ? now.day : daysInMonth;
    return days * hoursPerDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final available = _availableSlots();
    final occupancyPct = (available > 0)
        ? (month.bookings / available * 100).clamp(0, 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Left: month name only. The selected year is already shown
          // prominently in the page header — repeating it here as a
          // 2-digit suffix (e.g. "26") read like a date and confused
          // admins into thinking they were looking at June 26th.
          SizedBox(
            width: 56,
            child: Text(
              _monthShort(month.month),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Middle: amount + slot-occupancy progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        emptyHint ??
                            'Rs. ${_formatIndian(month.revenue)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (emptyHint == null)
                      Text(
                        available > 0
                            ? '${month.bookings} / $available'
                            : '${month.bookings} bookings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (emptyHint == null && available > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: occupancyPct / 100,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandGreen),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (emptyHint == null && available > 0) ...[
            const SizedBox(width: 10),
            Text(
              '${occupancyPct.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brandGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _monthShort(int m) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  if (m < 1 || m > 12) return '?';
  return names[m - 1];
}

String _monthLetter(int m) {
  const letters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  if (m < 1 || m > 12) return '?';
  return letters[m - 1];
}

/// Indian-style grouping: 13,09,800 (lakh/crore commas).
String _formatIndian(double amount) {
  final n = amount.round();
  final s = n.toString();
  if (s.length <= 3) return s;
  final lastThree = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  for (var i = rest.length; i > 0;) {
    final start = (i - 2).clamp(0, rest.length);
    if (buf.isNotEmpty) buf.write(',');
    buf.write(rest.substring(start, i).split('').reversed.join());
    i = start;
  }
  return '${buf.toString().split('').reversed.join()},$lastThree';
}

/// Compact "Rs. 2.2L" style for stat tiles.
String _formatShort(double amount) {
  if (amount >= 10000000) {
    return '${(amount / 10000000).toStringAsFixed(1)}Cr';
  }
  if (amount >= 100000) {
    return '${(amount / 100000).toStringAsFixed(1)}L';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}k';
  }
  return amount.toStringAsFixed(0);
}
