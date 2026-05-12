import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/analytics_entity.dart';
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
    if (amount >= 100000) {
      return 'Rs. ${(amount / 1000).toStringAsFixed(0)}k';
    } else if (amount >= 1000) {
      return 'Rs. ${amount.toStringAsFixed(0)}';
    }
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          Consumer<AnalyticsProvider>(
            builder: (context, provider, _) {
              return IconButton(
                onPressed: provider.state == AnalyticsState.loading
                    ? null
                    : () => provider.fetchAnalytics(forceRefresh: true),
                icon: provider.state == AnalyticsState.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurface,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchAnalytics(forceRefresh: true),
            child: CustomScrollView(
              slivers: [
                // Time Period Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                  ..._buildAnalyticsContent(context, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AnalyticsProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load analytics',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? 'Unknown error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => provider.fetchAnalytics(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnalyticsContent(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final analytics = provider.currentAnalytics;
    if (analytics == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: Text('No data available')),
        ),
      ];
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return [
      // Revenue Section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                icon: Icons.currency_rupee_rounded,
                title: 'Revenue',
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Total Revenue',
                value: _formatCurrency(analytics.totalRevenue),
                icon: Icons.account_balance_wallet_rounded,
                iconColor: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  MiniStatCard(
                    label: 'Paid',
                    value: _formatCurrency(analytics.paidRevenue),
                    valueColor: Colors.green,
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

      // Revenue Chart
      if (analytics.dailyRevenue.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  icon: Icons.bar_chart_rounded,
                  title: 'Revenue Trend',
                  color: colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                RevenueChart(
                  data: analytics.dailyRevenue,
                  period: analytics.period,
                ),
              ],
            ),
          ),
        ),

      // Bookings Section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                icon: Icons.calendar_month_rounded,
                title: 'Bookings',
                color: colorScheme.secondary,
              ),
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
                    valueColor: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Done',
                    value: analytics.completedBookings.toString(),
                    valueColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Cancel',
                    value: analytics.cancelledBookings.toString(),
                    valueColor: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Busiest Hours Chart
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                icon: Icons.schedule_rounded,
                title: 'Busiest Hours',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              BookingsHourlyChart(bookingsByHour: analytics.bookingsByHour),
            ],
          ),
        ),
      ),

      // Customers Section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                icon: Icons.people_rounded,
                title: 'Customers',
                color: Colors.purple,
              ),
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
                    valueColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  MiniStatCard(
                    label: 'Repeat',
                    value: analytics.repeatCustomers.toString(),
                    valueColor: colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Utilization Section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                icon: Icons.pie_chart_rounded,
                title: 'Slot Utilization',
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _buildUtilizationCard(context, analytics),
            ],
          ),
        ),
      ),

      // Bottom padding
      const SliverToBoxAdapter(
        child: SizedBox(height: 32),
      ),
    ];
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildUtilizationCard(
    BuildContext context,
    AnalyticsEntity analytics,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final utilization = analytics.slotUtilizationRate.clamp(0.0, 100.0);

    Color progressColor;
    String status;
    if (utilization >= 80) {
      progressColor = Colors.green;
      status = 'Excellent';
    } else if (utilization >= 50) {
      progressColor = Colors.orange;
      status = 'Good';
    } else {
      progressColor = Colors.red;
      status = 'Low';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${utilization.toStringAsFixed(1)}%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: utilization / 100,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Percentage of available slots booked',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
