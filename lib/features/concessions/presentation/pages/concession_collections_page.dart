import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/concession_provider.dart';

/// Dedicated page for cafe / concession collection breakdown — daily
/// totals for the last 7 days. Older dates live on the separate history
/// page reachable via the "View older history" button.
class ConcessionCollectionsPage extends StatefulWidget {
  const ConcessionCollectionsPage({super.key});

  @override
  State<ConcessionCollectionsPage> createState() =>
      _ConcessionCollectionsPageState();
}

class _ConcessionCollectionsPageState
    extends State<ConcessionCollectionsPage> {
  @override
  void initState() {
    super.initState();
    // Refresh when landing here so totals reflect the latest sales.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConcessionProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<ConcessionProvider>(
          builder: (context, provider, _) {
            final days = provider.weekBreakdown;
            final maxAmount = days.fold<double>(
                0, (a, d) => d.amount > a ? d.amount : a);
            return RefreshIndicator(
              onRefresh: provider.load,
              color: AppColors.brandGreen,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                size: 26),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Collections',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daily breakdown of cafe sales',
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                  // ── Week total card ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1F3712),
                              Color(0xFF2C4E1A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.limeAccent
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: AppColors.limeAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LAST 7 DAYS',
                                    style: TextStyle(
                                      color: Color(0xFF9FBA8B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${provider.weekTotal.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 26,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Daily breakdown list ──────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                      child: Text(
                        'Daily breakdown',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (provider.state == ConcessionState.loading &&
                      days.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      sliver: SliverList.builder(
                        itemCount: days.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DayRow(
                            day: days[i],
                            label: _dayLabel(days[i].date),
                            maxAmount: maxAmount,
                          ),
                        ),
                      ),
                    ),
                  // ── Older history (separate screen) ──────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(RoutePaths.concessionHistory),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('View older history'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(color: cs.outlineVariant),
                          foregroundColor: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d) {
    final today = DateTime.now();
    if (_isSameDay(d, today)) return 'Today';
    final yest = today.subtract(const Duration(days: 1));
    if (_isSameDay(d, yest)) return 'Yesterday';
    const wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${wkd[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }
}

class _DayRow extends StatelessWidget {
  final ConcessionDay day;
  final String label;
  final double maxAmount;
  const _DayRow({
    required this.day,
    required this.label,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ratio = maxAmount > 0 ? (day.amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    final hasActivity = day.amount > 0 || day.count > 0;
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
              width: 92,
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hasActivity ? cs.onSurface : cs.onSurfaceVariant,
                ),
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
                          hasActivity
                              ? 'Rs. ${day.amount.toInt()}'
                              : 'No sales',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: hasActivity
                                ? AppColors.brandGreen
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (hasActivity)
                        Text(
                          '${day.count} sale${day.count == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (hasActivity) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
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
          ],
        ),
      );
  }
}
