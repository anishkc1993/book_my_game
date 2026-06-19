import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/analytics_entity.dart';
import '../providers/analytics_provider.dart';
import '../widgets/bookings_chart.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/time_period_selector.dart';
import '../widgets/weekly_insights_card.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().fetchAnalytics();
    });
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return 'Rs. ${(amount / 1000).toStringAsFixed(0)}k';
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<AnalyticsProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.fetchAnalytics(forceRefresh: true),
              color: AppColors.brandGreen,
              child: CustomScrollView(
                slivers: [
                  // App bar
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
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Icon(Icons.arrow_back_rounded,
                                  size: 18, color: cs.onSurface),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Analytics',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          // Icon-only header actions — title gets the slack
                          // and the row never overflows on narrow phones.
                          _IconActionButton(
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFF2563EB),
                            tooltip: 'Hourly breakdown',
                            onTap: () =>
                                context.push(RoutePaths.hourlyBreakdown),
                          ),
                          const SizedBox(width: 6),
                          _IconActionButton(
                            icon: Icons.calendar_today_outlined,
                            color: AppColors.brandGreen,
                            tooltip: 'Yearly revenue',
                            onTap: () =>
                                context.push(RoutePaths.yearlyRevenue),
                          ),
                          const SizedBox(width: 6),
                          if (provider.state != AnalyticsState.loading)
                            GestureDetector(
                              onTap: () =>
                                  provider.fetchAnalytics(forceRefresh: true),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: cs.outlineVariant),
                                ),
                                child: Icon(Icons.refresh_rounded,
                                    size: 18, color: cs.onSurface),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Weekly AI insights (Sun → today) — shows above the
                  // period selector so it's always visible.
                  if (provider.turfId != null && provider.turfId!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
                        child: WeeklyInsightsCard(turfId: provider.turfId!),
                      ),
                    ),

                  // Period selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: TimePeriodSelector(
                        selectedPeriod: provider.selectedPeriod,
                        onPeriodChanged: provider.selectPeriod,
                      ),
                    ),
                  ),

                  // Content
                  if (provider.state == AnalyticsState.loading &&
                      provider.currentAnalytics == null)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.state == AnalyticsState.error &&
                      provider.currentAnalytics == null)
                    SliverFillRemaining(
                      child: _buildErrorState(context, provider),
                    )
                  else
                    ..._buildContent(context, provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, AnalyticsProvider provider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text('Failed to load analytics', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? '',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandGreen),
            onPressed: () => provider.fetchAnalytics(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(
      BuildContext context, AnalyticsProvider provider) {
    final analytics = provider.currentAnalytics;
    if (analytics == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: Text('No data available')),
        ),
      ];
    }

    final cs = Theme.of(context).colorScheme;

    return [
      // Revenue section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.currency_rupee_rounded,
                  label: 'Revenue'),
              const SizedBox(height: 12),
              StatCard(
                label: 'Total Revenue',
                value: _formatCurrency(analytics.totalRevenue),
                icon: Icons.account_balance_wallet_rounded,
                iconColor: AppColors.brandGreen,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  MiniStatCard(
                    label: 'Paid',
                    value: _formatCurrency(analytics.paidRevenue),
                    valueColor: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Pending',
                    value: _formatCurrency(analytics.pendingRevenue),
                    valueColor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Avg/Booking',
                    value: _formatCurrency(analytics.averageBookingValue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Cafe revenue (always visible) — NOT added to booking revenue.
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () => context.push(RoutePaths.concessions),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        const Color(0xFF2563EB).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.local_cafe_rounded,
                        size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CAFE COLLECTION',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(analytics.concessionRevenue),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${analytics.concessionSalesCount} sale${analytics.concessionSalesCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ),
      ),

      // Revenue chart
      if (analytics.dailyRevenue.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context,
                    icon: Icons.bar_chart_rounded, label: 'Revenue Trend'),
                const SizedBox(height: 12),
                RevenueChart(
                  data: analytics.dailyRevenue,
                  period: analytics.period,
                ),
              ],
            ),
          ),
        ),

      // Daily breakdown — Week / Month only (Today is a single number)
      if (analytics.period != TimePeriod.today)
        SliverToBoxAdapter(
          child: _DailyBreakdown(analytics: analytics),
        ),

      // Bookings section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.calendar_month_rounded, label: 'Bookings'),
              const SizedBox(height: 12),
              Row(
                children: [
                  MiniStatCard(
                    label: 'Total',
                    value: analytics.totalBookings.toString(),
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Active',
                    value: analytics.activeBookings.toString(),
                    valueColor: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Done',
                    value: analytics.completedBookings.toString(),
                    valueColor: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Cancel',
                    value: analytics.cancelledBookings.toString(),
                    valueColor: cs.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Busiest hours
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.schedule_rounded, label: 'Busiest Hours'),
              const SizedBox(height: 12),
              BookingsHourlyChart(bookingsByHour: analytics.bookingsByHour),
            ],
          ),
        ),
      ),

      // Customers
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.people_rounded, label: 'Customers'),
              const SizedBox(height: 12),
              Row(
                children: [
                  MiniStatCard(
                    label: 'Unique',
                    value: analytics.uniqueCustomers.toString(),
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'New',
                    value: analytics.newCustomers.toString(),
                    valueColor: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Repeat',
                    value: analytics.repeatCustomers.toString(),
                    valueColor: cs.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Utilization
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.pie_chart_rounded, label: 'Slot Utilization'),
              const SizedBox(height: 12),
              _UtilizationCard(utilization: analytics.slotUtilizationRate),
            ],
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];
  }

  Widget _sectionHeader(BuildContext context,
      {required IconData icon, required String label}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _UtilizationCard extends StatelessWidget {
  final double utilization;

  const _UtilizationCard({required this.utilization});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = utilization.clamp(0.0, 100.0);

    Color barColor;
    String status;
    if (pct >= 80) {
      barColor = AppColors.brandGreen;
      status = 'Excellent';
    } else if (pct >= 50) {
      barColor = Colors.orange;
      status = 'Good';
    } else {
      barColor = cs.error;
      status = 'Low';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Percentage of available slots booked',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily breakdown ─────────────────────────────────────────────────────────

class _DailyBreakdown extends StatelessWidget {
  final AnalyticsEntity analytics;
  const _DailyBreakdown({required this.analytics});

  /// Slots that were actually bookable on [date], capped at "today" so
  /// the current day's occupancy isn't penalized for hours still ahead.
  int _availableSlotsFor(DateTime date) {
    final hoursPerDay =
        AppConstants.slotEndHour - AppConstants.slotStartHour;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    if (isFuture) return 0;
    if (isToday) {
      // Use elapsed hours within the bookable window — clamp to [0, full].
      final elapsed = now.hour - AppConstants.slotStartHour + 1;
      return elapsed.clamp(0, hoursPerDay);
    }
    return hoursPerDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Pair revenue + bookings by date (they're parallel lists).
    final byDate = <String, ({DateTime date, double revenue, int bookings})>{};
    for (final r in analytics.dailyRevenue) {
      final key = '${r.date.year}-${r.date.month}-${r.date.day}';
      byDate[key] = (date: r.date, revenue: r.value, bookings: 0);
    }
    for (final b in analytics.dailyBookings) {
      final key = '${b.date.year}-${b.date.month}-${b.date.day}';
      final existing = byDate[key];
      if (existing != null) {
        byDate[key] = (
          date: existing.date,
          revenue: existing.revenue,
          bookings: b.value.round(),
        );
      } else {
        byDate[key] =
            (date: b.date, revenue: 0, bookings: b.value.round());
      }
    }

    // Show only days with activity, newest first.
    final rows = byDate.values
        .where((d) => d.revenue > 0 || d.bookings > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded,
                  size: 18, color: AppColors.brandGreen),
              const SizedBox(width: 8),
              Text(
                'Daily breakdown',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                'No activity in this period yet.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final row in rows) ...[
              _DayRow(
                date: row.date,
                revenue: row.revenue,
                bookings: row.bookings,
                availableSlots: _availableSlotsFor(row.date),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime date;
  final double revenue;
  final int bookings;
  final int availableSlots;
  const _DayRow({
    required this.date,
    required this.revenue,
    required this.bookings,
    required this.availableSlots,
  });

  String _label(DateTime d) {
    const wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${wkd[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final occupancy = (availableSlots > 0)
        ? (bookings / availableSlots * 100).clamp(0, 100)
        : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              _label(date),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rs. ${revenue.toInt()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      availableSlots > 0
                          ? '$bookings / $availableSlots'
                          : '$bookings bookings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (availableSlots > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: occupancy / 100,
                      minHeight: 5,
                      backgroundColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandGreen),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (availableSlots > 0) ...[
            const SizedBox(width: 10),
            Text(
              '${occupancy.toStringAsFixed(0)}%',
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

/// Compact icon-only action button used in the analytics header. Keeps
/// the title row clean on narrow phones while staying visually loud
/// thanks to a tinted background + matching border.
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
