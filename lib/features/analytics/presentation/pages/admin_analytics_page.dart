import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_provider.dart';
import '../widgets/bookings_chart.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/time_period_selector.dart';

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
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
