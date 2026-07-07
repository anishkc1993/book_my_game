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
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../monthly_plans/presentation/providers/monthly_plan_provider.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Run the same sweep the dashboard runs so any past-but-still-
      // unpaid bookings get auto-completed (+ paid regulars materialized)
      // before analytics aggregates. Without this, analytics for "today"
      // can lag the dashboard's PAID pill by however long since the
      // dashboard was last opened.
      try {
        await context.read<BookingProvider>().sweepPastBookings();
      } catch (_) {/* non-fatal */}
      if (!mounted) return;
      context.read<AnalyticsProvider>().fetchAnalytics(forceRefresh: true);
    });
  }

  /// Human-readable label for the date range covered by [period].
  String _periodRangeLabel(TimePeriod period, List<DateTime> dates) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (period == TimePeriod.today) return 'TODAY';
    if (period == TimePeriod.overall) {
      if (dates.isEmpty) return 'ALL TIME';
      dates.sort();
      final first = dates.first;
      final last = dates.last;
      if (first.year == last.year) {
        return '${months[first.month - 1]} – ${months[last.month - 1]} ${first.year} · ALL TIME';
      }
      return '${months[first.month - 1]} ${first.year} – ${months[last.month - 1]} ${last.year} · ALL TIME';
    }
    if (dates.isEmpty) return period.name.toUpperCase();
    dates.sort();
    final first = dates.first;
    final last = dates.last;
    if (first.year == last.year && first.month == last.month) {
      return '${months[first.month - 1]} ${first.year}';
    }
    if (first.year == last.year) {
      return '${months[first.month - 1]} – ${months[last.month - 1]} ${first.year}';
    }
    return '${months[first.month - 1]} ${first.year} – ${months[last.month - 1]} ${last.year}';
  }

  /// Indian-style grouping: 1,23,456 instead of 123,456. Always shows
  /// the full amount — no "k"/"L" abbreviation, even for larger numbers.
  String _formatCurrency(double amount) {
    final n = amount.round();
    final s = n.abs().toString();
    String grouped;
    if (s.length <= 3) {
      grouped = s;
    } else {
      final last3 = s.substring(s.length - 3);
      final rest = s.substring(0, s.length - 3);
      final buf = StringBuffer();
      // Group the "rest" by 2 from the right (Indian system).
      for (int i = 0; i < rest.length; i++) {
        final fromRight = rest.length - i;
        buf.write(rest[i]);
        if (fromRight > 1 && fromRight % 2 == 1) buf.write(',');
      }
      grouped = '$buf,$last3';
    }
    return 'Rs. ${n < 0 ? '-' : ''}$grouped';
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

    // Single source of truth for "today's revenue" — the dashboard's
    // BookingProvider.todayPaidRevenue + MonthlyPlanProvider.today
    // PlanRevenue. Used directly when period is Today, and used to patch
    // the today bucket inside Week/Month so aggregate totals + daily
    // charts stay consistent across screens.
    final bp = context.watch<BookingProvider>();
    final mp = context.watch<MonthlyPlanProvider>();
    final isToday = analytics.period == TimePeriod.today;
    final dashToday = bp.todayPaidRevenue + mp.todayPlanRevenue;
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    // Whatever analytics aggregated for *today's* bucket — used to
    // compute the delta we apply to Week/Month totals.
    final analyticsToday = analytics.dailyRevenue
        .where((d) => sameDay(d.date, now))
        .fold<double>(0, (s, d) => s + d.value);
    final todayDelta = dashToday - analyticsToday;

    final displayedTotal = isToday
        ? dashToday
        : (analytics.totalRevenue + todayDelta);
    final displayedPaid = isToday
        ? dashToday
        : (analytics.paidRevenue + todayDelta);

    // Replace today's bucket in the daily breakdown / chart with the
    // dashboard value. Historical days are immutable, pass through.
    final patchedDailyRevenue = analytics.dailyRevenue
        .map((d) => sameDay(d.date, now)
            ? DailyMetric(date: d.date, value: dashToday)
            : d)
        .toList();
    // Replace daily slot on the entity going forward.
    final patchedAnalytics = AnalyticsEntity(
      totalRevenue: displayedTotal,
      paidRevenue: displayedPaid,
      pendingRevenue: analytics.pendingRevenue,
      averageBookingValue: analytics.averageBookingValue,
      concessionRevenue: analytics.concessionRevenue,
      concessionSalesCount: analytics.concessionSalesCount,
      totalBookings: analytics.totalBookings,
      confirmedBookings: analytics.confirmedBookings,
      pendingBookings: analytics.pendingBookings,
      cancelledBookings: analytics.cancelledBookings,
      completedBookings: analytics.completedBookings,
      cancellationRate: analytics.cancellationRate,
      uniqueCustomers: analytics.uniqueCustomers,
      newCustomers: analytics.newCustomers,
      repeatCustomers: analytics.repeatCustomers,
      bookingsByHour: analytics.bookingsByHour,
      bookingsByWeekday: analytics.bookingsByWeekday,
      slotUtilizationRate: analytics.slotUtilizationRate,
      dailyRevenue: patchedDailyRevenue,
      dailyBookings: analytics.dailyBookings,
      period: analytics.period,
    );

    // Derive the date range covered by this period's data for the label.
    final allDates = patchedAnalytics.dailyRevenue
        .where((d) => d.value > 0)
        .map((d) => d.date)
        .toList();
    final periodLabel = _periodRangeLabel(analytics.period, allDates);

    return [
      // ── Overall Collection (full period total — all months combined) ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Overall Collection'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandGreen.withValues(alpha: 0.15),
                      AppColors.brandGreen.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.brandGreen.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(displayedTotal),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.brandGreen,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${analytics.totalBookings} booking${analytics.totalBookings == 1 ? '' : 's'} · ${analytics.uniqueCustomers} customer${analytics.uniqueCustomers == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppColors.brandGreen.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Field Revenue breakdown ───────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context,
                  icon: Icons.sports_soccer_rounded,
                  label: 'Field Revenue'),
              const SizedBox(height: 12),
              Row(
                children: [
                  MiniStatCard(
                    label: 'Collected',
                    value: _formatCurrency(displayedPaid),
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

      // Cafe revenue — tappable, goes to concessions detail.
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
      if (patchedAnalytics.dailyRevenue.length > 1)
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
                  data: patchedAnalytics.dailyRevenue,
                  period: patchedAnalytics.period,
                ),
              ],
            ),
          ),
        ),

      // Daily breakdown — Week / Month only (Today is a single number)
      if (patchedAnalytics.period != TimePeriod.today)
        SliverToBoxAdapter(
          child: _DailyBreakdown(analytics: patchedAnalytics),
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

    // Show only days with activity.
    final rows = byDate.values
        .where((d) => d.revenue > 0 || d.bookings > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group rows by year+month so the section renders as expandable
    // month headers ("June · Rs 2,08,740") with the day rows tucked
    // inside. Prevents the list from becoming a 30-row wall when Month
    // period is selected.
    final monthGroups = <String, _MonthGroupData>{};
    for (final row in rows) {
      final key = '${row.date.year}-${row.date.month}';
      final group = monthGroups.putIfAbsent(
        key,
        () => _MonthGroupData(
          year: row.date.year,
          month: row.date.month,
        ),
      );
      group.revenue += row.revenue;
      group.bookings += row.bookings;
      group.days.add(row);
    }
    final now = DateTime.now();
    final sortedGroups = monthGroups.values.toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });

    // Month period → only current calendar month.
    // Overall / Week → all groups.
    final isMonthPeriod = analytics.period == TimePeriod.month;
    final displayGroups = isMonthPeriod
        ? sortedGroups
            .where((g) => g.year == now.year && g.month == now.month)
            .toList()
        : sortedGroups;

    final sectionTitle = isMonthPeriod ? 'This Month' : 'Monthly Breakdown';
    final emptyLabel = isMonthPeriod
        ? 'No activity this month yet.'
        : 'No activity in this period yet.';

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
                sectionTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayGroups.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (int i = 0; i < displayGroups.length; i++) ...[
              _MonthGroup(
                group: displayGroups[i],
                initiallyExpanded: i == 0,
                dayRowBuilder: (day) => _DayRow(
                  date: day.date,
                  revenue: day.revenue,
                  bookings: day.bookings,
                  availableSlots: _availableSlotsFor(day.date),
                ),
              ),
              if (i < displayGroups.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _MonthGroupData {
  final int year;
  final int month; // 1..12
  double revenue = 0;
  int bookings = 0;
  final List<({DateTime date, double revenue, int bookings})> days = [];
  _MonthGroupData({required this.year, required this.month});
}

/// Expandable per-month header on the analytics page. Tap to reveal the
/// day-by-day rows inside the month.
class _MonthGroup extends StatefulWidget {
  final _MonthGroupData group;
  final bool initiallyExpanded;
  final Widget Function(
      ({DateTime date, double revenue, int bookings})) dayRowBuilder;
  const _MonthGroup({
    required this.group,
    required this.initiallyExpanded,
    required this.dayRowBuilder,
  });

  @override
  State<_MonthGroup> createState() => _MonthGroupState();
}

class _MonthGroupState extends State<_MonthGroup> {
  late bool _expanded = widget.initiallyExpanded;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatIndian(double amount) {
    final n = amount.round();
    final s = n.abs().toString();
    if (s.length <= 3) return 'Rs. ${n < 0 ? '-' : ''}$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      final fromRight = rest.length - i;
      buf.write(rest[i]);
      if (fromRight > 1 && fromRight % 2 == 1) buf.write(',');
    }
    return 'Rs. ${n < 0 ? '-' : ''}$buf,$last3';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final g = widget.group;
    final now = DateTime.now();
    final isCurrent = g.year == now.year && g.month == now.month;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.calendar_month_rounded,
                        size: 20, color: AppColors.brandGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrent
                              ? '${_monthNames[g.month - 1]} ${g.year} · this month'
                              : '${_monthNames[g.month - 1]} ${g.year}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${g.days.length} day${g.days.length == 1 ? '' : 's'} · ${g.bookings} booking${g.bookings == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Month Total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _formatIndian(g.revenue),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.brandGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  for (final day in g.days) ...[
                    widget.dayRowBuilder(day),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
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
