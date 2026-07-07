import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Per-hour amount breakdown for a chosen date — picks a date, fetches
/// every booking in that day, and renders the running collection for
/// each hour from 6 AM to 9 PM (last bookable slot).
class HourlyBreakdownPage extends StatefulWidget {
  const HourlyBreakdownPage({super.key});

  @override
  State<HourlyBreakdownPage> createState() => _HourlyBreakdownPageState();
}

class _HourlyBreakdownPageState extends State<HourlyBreakdownPage> {
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;
  List<_HourBucket> _buckets = const [];
  double _totalCollected = 0;
  int _totalBookings = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
      _load();
    }
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final turfId = auth.user?.turfId;
    if (turfId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateKey =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.bookingsCollection)
          .where('turfId', isEqualTo: turfId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      final byHour = <int, _HourBucket>{
        for (int h = AppConstants.slotStartHour;
            h < AppConstants.slotEndHour;
            h++)
          h: _HourBucket(hour: h),
      };

      final nowTs = DateTime.now();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status == 'CANCELLED') continue;
        final start = (data['startTime'] as Timestamp?)?.toDate();
        if (start == null) continue;
        final hour = start.hour;
        final bucket = byHour[hour];
        if (bucket == null) continue;

        final isPaid = data['isPaid'] as bool? ?? false;
        final amountPaid = (data['amountPaid'] as num?)?.toDouble();
        final basePrice = (data['basePrice'] as num?)?.toDouble();

        // Same rule as the dashboard PAID pill + analytics Total Revenue:
        // count only when the match has actually played AND it's paid.
        // Plans/tournaments excluded (they have their own payment streams).
        final endTime = (data['endTime'] as Timestamp?)?.toDate();
        final matchFinished = status == 'COMPLETED' ||
            (endTime != null && endTime.isBefore(nowTs));
        final isPlan = data['isMonthlyPlan'] as bool? ?? false;
        final isTournament = data['isTournament'] as bool? ?? false;
        final paidAmount = amountPaid ?? basePrice ?? 0;
        final collected =
            (isPaid && matchFinished && !isPlan && !isTournament)
                ? paidAmount
                : 0.0;
        final expected = basePrice ?? amountPaid ?? 0;
        bucket.collected += collected;
        bucket.expected += expected;
        bucket.entries.add(_HourEntry(
          customer:
              (data['customerName'] as String?) ?? (data['userPhone'] as String? ?? ''),
          phone: data['userPhone'] as String? ?? '',
          status: status ?? 'PENDING',
          isPaid: isPaid,
          amount: collected,
          isRegular: data['isRegular'] as bool? ?? false,
          isMonthlyPlan: data['isMonthlyPlan'] as bool? ?? false,
          isTournament: data['isTournament'] as bool? ?? false,
        ));
      }

      final buckets = byHour.values.toList()
        ..sort((a, b) => a.hour.compareTo(b.hour));
      double total = 0;
      int totalBookings = 0;
      for (final b in buckets) {
        total += b.collected;
        totalBookings += b.entries.length;
      }

      setState(() {
        _buckets = buckets;
        _totalCollected = total;
        _totalBookings = totalBookings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ HourlyBreakdown.load: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brandGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 26),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hourly breakdown',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Per-hour collection for the chosen date',
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
              // Date picker chip + summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1F3712),
                            Color(0xFF2C4E1A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.limeAccent
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.event_rounded,
                              size: 22,
                              color: AppColors.limeAccent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(_date),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rs. ${_totalCollected.toInt()} · '
                                  '$_totalBookings booking${_totalBookings == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Color(0xFF9FBA8B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: Color(0xFF9FBA8B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Body
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverList.separated(
                    itemBuilder: (_, i) => _HourRow(
                      bucket: _buckets[i],
                      grandTotal: _totalCollected,
                    ),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemCount: _buckets.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wkd[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _HourBucket {
  final int hour;
  double collected = 0;
  double expected = 0;
  final List<_HourEntry> entries = [];
  _HourBucket({required this.hour});

  String get label {
    final h = hour;
    final start = h == 0
        ? '12 AM'
        : (h < 12 ? '$h AM' : (h == 12 ? '12 PM' : '${h - 12} PM'));
    final endH = (h + 1) % 24;
    final end = endH == 0
        ? '12 AM'
        : (endH < 12
            ? '$endH AM'
            : (endH == 12 ? '12 PM' : '${endH - 12} PM'));
    return '$start – $end';
  }
}

class _HourEntry {
  final String customer;
  final String phone;
  final String status;
  final bool isPaid;
  final double amount;
  final bool isRegular;
  final bool isMonthlyPlan;
  final bool isTournament;
  const _HourEntry({
    required this.customer,
    required this.phone,
    required this.status,
    required this.isPaid,
    required this.amount,
    required this.isRegular,
    required this.isMonthlyPlan,
    required this.isTournament,
  });
}

class _HourRow extends StatelessWidget {
  final _HourBucket bucket;
  final double grandTotal;
  const _HourRow({required this.bucket, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasActivity = bucket.entries.isNotEmpty;
    final share =
        grandTotal > 0 ? (bucket.collected / grandTotal * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasActivity
              ? AppColors.brandGreen.withValues(alpha: 0.35)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  bucket.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hasActivity ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasActivity
                      ? 'Rs. ${bucket.collected.toInt()}'
                      : 'No bookings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: hasActivity
                        ? AppColors.brandGreen
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasActivity)
                Text(
                  '${bucket.entries.length} · ${share.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (hasActivity) ...[
            const SizedBox(height: 8),
            for (final e in bucket.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      e.isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 12,
                      color: e.isPaid
                          ? AppColors.brandGreen
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.customer.isNotEmpty ? e.customer : e.phone,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (e.isTournament)
                      _MiniBadge(
                          label: 'TOURNAMENT',
                          color: const Color(0xFFE07820)),
                    if (e.isMonthlyPlan)
                      _MiniBadge(
                          label: 'PLAN', color: const Color(0xFF5C5BD6)),
                    if (e.isRegular && !e.isMonthlyPlan && !e.isTournament)
                      _MiniBadge(
                          label: 'REGULAR', color: AppColors.brandGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Rs. ${e.amount.toInt()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: e.isPaid
                            ? AppColors.brandGreen
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
