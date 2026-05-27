import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/theme_selector.dart';
import '../../../../injection_container.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../../booking/domain/entities/slot_config_entity.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../leaderboard/domain/entities/leaderboard_entry.dart';
import '../../../leaderboard/presentation/providers/leaderboard_provider.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

// ── Home page (role router) ────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null) {
        context.read<BookingProvider>().fetchUserBookings(user.uid);
        if (user.isAdmin) {
          final bp = context.read<BookingProvider>();
          // Sweep first so today's list reflects the auto-completion.
          bp.sweepPastBookings().then((_) => bp.fetchTodayBookings());
          bp.fetchSlotConfig();
          context.read<LeaderboardProvider>().fetchLeaderboard();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user?.isAdmin == true) {
          return _AdminHome(onSignOut: () => _signOut(context));
        }
        return _CustomerHome(onSignOut: () => _signOut(context));
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to book slots.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

// ─── Admin Home ───────────────────────────────────────────────────────────────

class _AdminHome extends StatefulWidget {
  final VoidCallback onSignOut;
  const _AdminHome({required this.onSignOut});

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  static const _revenueHiddenKey = 'bmg_admin_revenue_hidden';

  bool _revenueHidden = false;

  @override
  void initState() {
    super.initState();
    _revenueHidden =
        injector.sharedPreferences.getBool(_revenueHiddenKey) ?? false;
  }

  void _toggleRevenue() {
    setState(() => _revenueHidden = !_revenueHidden);
    injector.sharedPreferences.setBool(_revenueHiddenKey, _revenueHidden);
  }

  VoidCallback get onSignOut => widget.onSignOut;

  String _dateLine(DateTime d, int firstHour, int lastHour) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String fmt(int h) {
      if (h == 0) return '12 AM';
      if (h < 12) return '$h AM';
      if (h == 12) return '12 PM';
      return '${h - 12} PM';
    }
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} · '
        '${fmt(firstHour)} – ${fmt(lastHour + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, bp, _) {
            final today = DateTime.now();
            final liveBookings = bp.todayBookings;

            // Revenue split
            final paidRevenue = liveBookings
                .where((b) => b.isPaid)
                .fold<double>(
                    0, (s, b) => s + (b.amountPaid ?? b.basePrice ?? 0));

            final pendingRevenue = liveBookings
                .where((b) => !b.isPaid && !b.isCancelled)
                .fold<double>(0, (s, b) => s + (b.basePrice ?? 0));

            final totalRevenue = paidRevenue + pendingRevenue;

            // Slot data
            final enabledHours = (bp.slotConfig?.enabledHours ??
                    SlotConfigEntity.allPossibleHours)
                .toList()
              ..sort();
            final firstHour =
                enabledHours.isEmpty ? 6 : enabledHours.first;
            final lastHour =
                enabledHours.isEmpty ? 19 : enabledHours.last;

            final bookedHours = liveBookings
                .where((b) => !b.isCancelled)
                .map((b) => b.startTime.hour)
                .toSet();
            final totalEnabled = enabledHours.length;
            final bookedCount = bookedHours.length;
            final fillPercent = totalEnabled > 0
                ? (bookedCount * 100 / totalEnabled).round()
                : 0;

            // Walk-in count = admin-created bookings today
            final walkInsCount =
                liveBookings.where((b) => b.isAdminBooking).length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Top bar: ADMIN · VENUE + theme + bell ─────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RoleVenueLine(
                            venue: context
                                    .watch<AuthProvider>()
                                    .user
                                    ?.turfName
                                    ?.toUpperCase() ??
                                'TURF',
                          ),
                        ),
                        _IconButtonCircle(
                          icon: Theme.of(context).brightness == Brightness.dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          onTap: () => ThemeSelector.show(context),
                          tooltip: 'Theme',
                        ),
                        const SizedBox(width: 8),
                        _IconButtonCircle(
                          icon: Icons.location_on_outlined,
                          onTap: () =>
                              context.push(RoutePaths.venueLocation),
                          tooltip: 'Venue location',
                        ),
                        const SizedBox(width: 8),
                        _BellBadge(
                          count: 0,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notifications coming soon'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Title: Today's pitch ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's pitch",
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dateLine(today, firstHour, lastHour),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Revenue + Bookings row ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: SizedBox(
                      height: 152,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _RevenueCard(
                              amount: totalRevenue,
                              delta: null,
                              hidden: _revenueHidden,
                              onToggleVisibility: _toggleRevenue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _BookingsCard(
                              booked: bookedCount,
                              total: totalEnabled,
                              fillPercent: fillPercent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Stat tiles row (Paid / Pending / Walk-ins) ─────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            icon: Icons.verified_outlined,
                            iconColor: AppColors.brandGreen,
                            iconBg: AppColors.brandGreen
                                .withValues(alpha: 0.18),
                            value: _revenueHidden
                                ? 'Rs. ••••'
                                : 'Rs. ${paidRevenue.toInt()}',
                            label: 'PAID',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatPill(
                            icon: Icons.hourglass_bottom_rounded,
                            iconColor: const Color(0xFFE6A020),
                            iconBg: const Color(0xFFE6A020)
                                .withValues(alpha: 0.18),
                            value: _revenueHidden
                                ? 'Rs. ••••'
                                : 'Rs. ${pendingRevenue.toInt()}',
                            label: 'PENDING',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatPill(
                            icon: Icons.group_outlined,
                            iconColor: cs.onSurfaceVariant,
                            iconBg: cs.surfaceContainerHighest,
                            value: '$walkInsCount',
                            label: 'WALK-INS',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Today's pitch slot visualization ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's pitch",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.push(RoutePaths.slotManagement),
                              child: Text(
                                'Manage',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brandGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _PitchBarsRow(
                          hours: enabledHours,
                          bookedHours: bookedHours,
                          nowHour: today.hour,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _LegendDot(
                                color: cs.outlineVariant,
                                label: 'Available'),
                            const SizedBox(width: 18),
                            _LegendDot(
                                // Match the actual booked bar fill (theme-aware).
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.limeAccent
                                    : AppColors.brandGreen,
                                label: 'Booked'),
                            const SizedBox(width: 18),
                            _LegendDot(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.45),
                                label: 'Past'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Quick actions ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick actions',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PitchActionTile(
                                icon: Icons.calendar_month_outlined,
                                label: 'New booking',
                                active: true,
                                onTap: () =>
                                    context.push(RoutePaths.adminBooking),
                              ),
                              const SizedBox(width: 10),
                              _PitchActionTile(
                                icon: Icons.event_repeat_outlined,
                                label: 'Regulars',
                                onTap: () =>
                                    context.push(RoutePaths.regularBookings),
                              ),
                              const SizedBox(width: 10),
                              _PitchActionTile(
                                icon: Icons.block_outlined,
                                label: 'Block hours',
                                onTap: () =>
                                    context.push(RoutePaths.slotManagement),
                              ),
                              const SizedBox(width: 10),
                              _PitchActionTile(
                                icon: Icons.bar_chart_rounded,
                                label: 'Reports',
                                onTap: () =>
                                    context.push(RoutePaths.adminAnalytics),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Top bookers (this month) ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top bookers',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(RoutePaths.leaderboard),
                          child: Text(
                            'View all',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _TopBookersCard(),
                  ),
                ),

                // ── Live bookings header ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Live bookings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(RoutePaths.adminBooking),
                          child: Text(
                            'View all',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Booking cards ──────────────────────────────────────────
                if (liveBookings.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _LiveBookingsEmpty(
                        onAdd: () => context.push(RoutePaths.adminBooking),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _LiveBookingCard.fromBooking(liveBookings[i]),
                        );
                      },
                      childCount: liveBookings.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomBar(onSignOut: onSignOut, isAdmin: true),
    );
  }
}

// ─── Admin Home widgets (new) ─────────────────────────────────────────────────

class _RoleVenueLine extends StatelessWidget {
  final String venue;
  const _RoleVenueLine({required this.venue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.limeAccent
                : AppColors.brandGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'ADMIN · $venue',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? AppColors.limeAccent
                  : AppColors.brandGreen,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconButtonCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconButtonCircle({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: cs.onSurface),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

class _BellBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _BellBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.notifications_outlined,
                  size: 20, color: cs.onSurface),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  decoration: BoxDecoration(
                    color: AppColors.limeAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF0F2B06),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double amount;
  final String? delta;
  final bool hidden;
  final VoidCallback? onToggleVisibility;
  const _RevenueCard({
    required this.amount,
    this.delta,
    this.hidden = false,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF1E4A10)
        : AppColors.brandGreen;
    final accent =
        isDark ? AppColors.limeAccent : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.limeAccent.withValues(alpha: isDark ? 0.35 : 0.0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.limeAccent
                .withValues(alpha: isDark ? 0.18 : 0.0),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'REVENUE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              if (onToggleVisibility != null)
                GestureDetector(
                  onTap: onToggleVisibility,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? 'Rs. ••••••' : 'Rs. ${amount.toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
          if (delta != null)
            Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 16, color: accent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$delta vs last week',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BookingsCard extends StatelessWidget {
  final int booked;
  final int total;
  final int fillPercent;
  const _BookingsCard({
    required this.booked,
    required this.total,
    required this.fillPercent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'BOOKINGS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$booked',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                  height: 1.0,
                ),
              ),
              Text(
                '/$total',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$fillPercent% filled',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  const _StatPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 9.5,
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

class _PitchBarsRow extends StatelessWidget {
  final List<int> hours;
  final Set<int> bookedHours;
  final int nowHour;
  const _PitchBarsRow({
    required this.hours,
    required this.bookedHours,
    required this.nowHour,
  });

  String _hourLabel(int h) {
    if (h == 0) return '12';
    if (h <= 12) return '$h';
    return '${h - 12}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in hours) ...[
            Expanded(
              child: _PitchBar(
                hour: h,
                label: _hourLabel(h),
                isBooked: bookedHours.contains(h),
                isPast: h < nowHour,
                isNow: h == nowHour,
              ),
            ),
            if (h != hours.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _PitchBar extends StatelessWidget {
  final int hour;
  final String label;
  final bool isBooked;
  final bool isPast;
  final bool isNow;
  const _PitchBar({
    required this.hour,
    required this.label,
    required this.isBooked,
    required this.isPast,
    required this.isNow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bookedFill =
        isDark ? AppColors.limeAccent : AppColors.brandGreen;
    final emptyFill = isPast
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerLow;
    final emptyBorder = isPast
        ? cs.outlineVariant.withValues(alpha: 0.5)
        : cs.outlineVariant;
    final dotInsideColor =
        isDark ? const Color(0xFF0F2B06) : Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 76,
          decoration: BoxDecoration(
            color: isBooked ? bookedFill : emptyFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isBooked ? bookedFill : emptyBorder,
              width: 1,
            ),
            boxShadow: isBooked
                ? [
                    BoxShadow(
                      color: bookedFill.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          // Booked: small white dot near top. Now (unbooked): subtle muted
          // dot to mark current hour.
          alignment: isBooked ? Alignment.topCenter : Alignment.center,
          padding: isBooked
              ? const EdgeInsets.only(top: 8)
              : EdgeInsets.zero,
          child: isBooked
              ? Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dotInsideColor,
                    shape: BoxShape.circle,
                  ),
                )
              : isNow
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isPast
                ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                : cs.onSurfaceVariant,
            fontSize: 11,
            fontWeight: isBooked ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PitchActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PitchActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = isDark
        ? AppColors.limeAccent
        : AppColors.brandGreen;
    final activeFg = isDark
        ? const Color(0xFF0F2B06)
        : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            color: active ? activeBg : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? activeBg
                  : cs.outlineVariant.withValues(alpha: 0.7),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeBg.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 22,
                  color: active ? activeFg : cs.onSurface),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  color: active ? activeFg : cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBookersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<LeaderboardProvider>(
      builder: (context, lb, _) {
        final loading = lb.state == LeaderboardState.loading && lb.entries.isEmpty;
        final entries = lb.entries.take(3).toList();

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: loading
              ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              : entries.isEmpty
                  ? _emptyState(theme, cs)
                  : Column(
                      children: [
                        for (int i = 0; i < entries.length; i++) ...[
                          _TopBookerRow(entry: entries[i]),
                          if (i != entries.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                color: cs.outlineVariant
                                    .withValues(alpha: 0.5),
                                height: 1,
                              ),
                            ),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.emoji_events_outlined,
                color: AppColors.brandGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No bookers ranked yet this month.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBookerRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _TopBookerRow({required this.entry});

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFD4A017); // gold
      case 2:
        return const Color(0xFF9AA0A6); // silver
      case 3:
        return const Color(0xFFB87333); // bronze
      default:
        return AppColors.brandGreen;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.isEmpty ? '#' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _rankColor(entry.rank);
    final name = entry.displayName;

    return Row(
      children: [
        // Rank badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${entry.rank}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Avatar initials
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppColors.brandGreen,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.maskedPhone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Bookings count pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.bookingCount}',
                style: const TextStyle(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                entry.bookingCount == 1 ? 'booking' : 'bookings',
                style: TextStyle(
                  color: AppColors.brandGreen.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveBookingsEmpty extends StatelessWidget {
  final VoidCallback onAdd;
  const _LiveBookingsEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.event_busy_outlined,
                color: AppColors.brandGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No bookings yet today',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The pitch is wide open — tap to add one.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBookingCard extends StatelessWidget {
  final String name;
  final String phoneOrSub;
  final int amount;
  final BookingStatus status;
  final bool isPaid;
  final int startHour;
  final bool isRegular;

  const _LiveBookingCard({
    required this.name,
    required this.phoneOrSub,
    required this.amount,
    required this.status,
    required this.isPaid,
    required this.startHour,
    this.isRegular = false,
  });

  factory _LiveBookingCard.fromBooking(BookingEntity b) {
    return _LiveBookingCard(
      name: b.customerName ?? b.userPhone,
      phoneOrSub: b.userPhone,
      amount: (b.amountPaid ?? b.basePrice ?? 0).toInt(),
      status: b.status,
      isPaid: b.isPaid,
      startHour: b.startTime.hour,
      isRegular: b.isRegular,
    );
  }

  String _hourLabel(int h) {
    if (h == 0) return '12';
    if (h <= 12) return '$h';
    return '${h - 12}';
  }

  String _ampm(int h) => h >= 12 ? 'PM' : 'AM';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cancelled = status == BookingStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          // Vertical time chip
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _hourLabel(startHour),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ampm(startHour),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Name + sub
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        phoneOrSub,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (amount > 0) ...[
                      Text('  ·  ',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        'Rs. $amount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status chip
          _LiveStatusChip(
            status: status,
            isPaid: isPaid,
            isRegular: isRegular,
          ),
        ],
      ),
    );
  }
}

class _LiveStatusChip extends StatelessWidget {
  final BookingStatus status;
  final bool isPaid;
  final bool isRegular;
  const _LiveStatusChip({
    required this.status,
    required this.isPaid,
    required this.isRegular,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final Color fg;
    late final Color bg;
    late final String label;
    if (isRegular) {
      label = 'REGULAR';
      fg = isDark ? AppColors.limeAccent : AppColors.brandGreen;
      bg = (isDark ? AppColors.limeAccent : AppColors.brandGreen)
          .withValues(alpha: 0.18);
    } else if (status == BookingStatus.cancelled) {
      label = 'CANCELLED';
      fg = cs.error;
      bg = cs.error.withValues(alpha: 0.14);
    } else if (status == BookingStatus.pending) {
      label = 'PENDING';
      fg = const Color(0xFFE6A020);
      bg = const Color(0xFFE6A020).withValues(alpha: 0.18);
    } else {
      label = 'CONFIRMED';
      fg = isDark ? AppColors.limeAccent : AppColors.brandGreen;
      bg = (isDark ? AppColors.limeAccent : AppColors.brandGreen)
          .withValues(alpha: 0.18);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Customer Home ────────────────────────────────────────────────────────────

class _CustomerHome extends StatefulWidget {
  final VoidCallback onSignOut;
  const _CustomerHome({required this.onSignOut});

  @override
  State<_CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<_CustomerHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      await context.read<BookingProvider>().fetchUserBookings(user.uid);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isEmpty ? '?' : parts.first[0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;

    final displayName = (user?.displayName != null &&
            user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : (user?.phoneNumber?.length != null && user!.phoneNumber!.length >= 4
            ? user.phoneNumber!.substring(user.phoneNumber!.length - 4)
            : 'Player');
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, bookingProvider, _) {
            final now = DateTime.now();
            final upcoming = bookingProvider.userBookings
                .where((b) =>
                    !b.isCancelled &&
                    !b.isCompleted &&
                    b.startTime.isAfter(now))
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
            final nextBooking = upcoming.isNotEmpty ? upcoming.first : null;

            // Recent past bookings — preview row + count for "Rebook recent".
            final pastBookings = bookingProvider.userBookings
                .where((b) => !b.isCancelled && b.startTime.isBefore(now))
                .toList()
              ..sort((a, b) => b.startTime.compareTo(a.startTime));

            return RefreshIndicator(
              color: AppColors.brandGreen,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Greeting + avatar ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _GreetingHeader(
                        firstName: firstName,
                        initials: _initials(displayName),
                      ),
                    ),
                  ),

                  // ── Membership chip ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _MembershipChip(membership: user?.membership),
                    ),
                  ),

                  // ── UP NEXT card OR empty state ─────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: nextBooking != null
                          ? _UpNextCard(
                              booking: nextBooking,
                              turfName: user?.turfName)
                          : _NoUpcomingCard(
                              onBook: () =>
                                  context.push(RoutePaths.booking),
                            ),
                    ),
                  ),

                  // ── Quick actions ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick actions',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _QuickActionRow(
                            icon: Icons.calendar_month_outlined,
                            title: 'Book a slot',
                            subtitle: 'Pick a date & time',
                            onTap: () => context.push(RoutePaths.booking),
                          ),
                          const SizedBox(height: 10),
                          _QuickActionRow(
                            icon: Icons.group_add_outlined,
                            title: 'Invite teammates',
                            subtitle: 'Share with your squad',
                            onTap: () => _inviteTeammates(context, user),
                          ),
                          const SizedBox(height: 10),
                          _QuickActionRow(
                            icon: Icons.refresh_rounded,
                            title: 'Rebook recent',
                            subtitle: pastBookings.isEmpty
                                ? 'No past bookings yet'
                                : '${_describePattern(pastBookings)} · '
                                    '${pastBookings.length} played',
                            onTap: pastBookings.isEmpty
                                ? null
                                : () => context.push(RoutePaths.booking),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Your bookings header ────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your bookings',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (bookingProvider.userBookings.isNotEmpty)
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'See all',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brandGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Booking rows ────────────────────────────────────────
                  if (bookingProvider.userBookings.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: _EmptyBookingsHint(
                          onBook: () => context.push(RoutePaths.booking),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final b = bookingProvider.userBookings[i];
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _CompactBookingRow(booking: b),
                          );
                        },
                        childCount: bookingProvider.userBookings.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomBar(onSignOut: widget.onSignOut),
    );
  }

  String _describePattern(List<BookingEntity> bookings) {
    if (bookings.isEmpty) return '';
    // Most-common hour + most-common weekday from the user's past bookings.
    final hours = <int, int>{};
    final days = <int, int>{};
    for (final b in bookings) {
      hours[b.startTime.hour] = (hours[b.startTime.hour] ?? 0) + 1;
      days[b.startTime.weekday] = (days[b.startTime.weekday] ?? 0) + 1;
    }
    final topHour = hours.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final topDay = days.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    String fmtHour(int h) {
      if (h == 0) return '12 AM';
      if (h < 12) return '$h AM';
      if (h == 12) return '12 PM';
      return '${h - 12} PM';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${fmtHour(topHour)} ${dayNames[topDay - 1]}s';
  }

  Future<void> _inviteTeammates(BuildContext context, UserEntity? user) async {
    final turfName = user?.turfName ?? 'our turf';
    final msg = 'Join me at $turfName! Download Book My Game to grab a slot.';
    // ignore: deprecated_member_use
    await Share.share(msg);
  }
}

// ─── Greeting header (Name + avatar) ─────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String firstName;
  final String initials;
  const _GreetingHeader({required this.firstName, required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namaste,',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('👋', style: TextStyle(fontSize: 24)),
                ],
              ),
            ],
          ),
        ),
        // Avatar with check badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.limeAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF0F2B06), size: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Membership chip ─────────────────────────────────────────────────────────

class _MembershipChip extends StatelessWidget {
  final MembershipTier? membership;
  const _MembershipChip({this.membership});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tier = membership ?? MembershipTier.free;
    final label = switch (tier) {
      MembershipTier.gold => 'Gold member',
      MembershipTier.platinum => 'Platinum member',
      _ => 'Free member',
    };
    return Container(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined,
                size: 14, color: AppColors.brandGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UP NEXT hero card ───────────────────────────────────────────────────────

class _UpNextCard extends StatelessWidget {
  final BookingEntity booking;
  final String? turfName;
  const _UpNextCard({required this.booking, this.turfName});

  String _countdownLabel() {
    final now = DateTime.now();
    final diff = booking.startTime.difference(now);
    if (diff.isNegative) return 'STARTING NOW';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h >= 24) {
      final d = diff.inDays;
      return 'IN ${d}D ${h - d * 24}H';
    }
    if (h <= 0) return 'IN ${m}M';
    return 'IN ${h}H ${m}M';
  }

  String _dateLine() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(booking.date.year, booking.date.month, booking.date.day);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${booking.date.day} ${months[booking.date.month - 1]}, '
        '${days[booking.date.weekday - 1]}';
    if (d == today) return 'Today · $dateStr';
    if (d == tomorrow) return 'Tomorrow · $dateStr';
    return dateStr;
  }

  Future<void> _shareBooking() async {
    final venue = turfName ?? 'the turf';
    final msg = 'Locked in: ${booking.timeRange} at $venue. '
        'See you there!';
    // ignore: deprecated_member_use
    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.heroCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.limeAccent.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.limeAccent.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _UpNextBadge(label: 'UP NEXT · ${_countdownLabel()}'),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.limeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    booking.status.value,
                    style: const TextStyle(
                      color: AppColors.limeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            booking.timeRange,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dateLine(),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    turfName ?? 'Your turf',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HeroIconButton(
                  icon: Icons.navigation_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _HeroIconButton(
                  icon: Icons.share_rounded,
                  onTap: _shareBooking,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNextBadge extends StatelessWidget {
  final String label;
  const _UpNextBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.limeAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.limeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.limeAccent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─── No upcoming card ────────────────────────────────────────────────────────

class _NoUpcomingCard extends StatelessWidget {
  final VoidCallback onBook;
  const _NoUpcomingCard({required this.onBook});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No upcoming bookings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lock the pitch for your next match',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onBook,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Book'),
          ),
        ],
      ),
    );
  }
}

// ─── Quick action row ────────────────────────────────────────────────────────

class _QuickActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _QuickActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: cs.onSurface, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Compact booking row (Your bookings list) ────────────────────────────────

class _CompactBookingRow extends StatelessWidget {
  final BookingEntity booking;
  const _CompactBookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(booking.date.year, booking.date.month, booking.date.day);
    String dateLabel;
    if (d == today) {
      dateLabel = 'Today';
    } else if (d == today.add(const Duration(days: 1))) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = '${booking.date.day} ${months[booking.date.month - 1]}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          // Day column
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${booking.date.day}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  months[booking.date.month - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.timeRange,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel${booking.basePrice != null ? ' · Rs. ${booking.basePrice!.toInt()}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Status chip
          _BookingStatusChip(
              status: booking.status, isPaid: booking.isPaid, isDark: isDark),
        ],
      ),
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  final BookingStatus status;
  final bool isPaid;
  final bool isDark;
  const _BookingStatusChip({
    required this.status,
    required this.isPaid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final Color color;
    late final String label;
    switch (status) {
      case BookingStatus.confirmed:
        color = isDark ? AppColors.limeAccent : AppColors.brandGreen;
        label = 'CONFIRMED';
        break;
      case BookingStatus.pending:
        color = const Color(0xFFE6A020);
        label = 'PENDING';
        break;
      case BookingStatus.cancelled:
        color = cs.error;
        label = 'CANCELLED';
        break;
      case BookingStatus.completed:
        color = cs.onSurfaceVariant;
        label = 'DONE';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state hint ────────────────────────────────────────────────────────

class _EmptyBookingsHint extends StatelessWidget {
  final VoidCallback onBook;
  const _EmptyBookingsHint({required this.onBook});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.event_busy_outlined,
                color: AppColors.brandGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No bookings yet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your history will show up here',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onBook,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom navigation bar ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onSignOut;
  final bool isAdmin;

  const _BottomBar({required this.onSignOut, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightGradientBottom,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (isAdmin) ...[
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    active: true,
                    onTap: () {},
                  ),
                  _NavItem(
                    icon: Icons.event_note_rounded,
                    label: 'Bookings',
                    onTap: () => context.push(RoutePaths.adminBooking),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics',
                    onTap: () => context.push(RoutePaths.adminAnalytics),
                  ),
                ] else ...[
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    active: true,
                    onTap: () {},
                  ),
                  _NavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Book',
                    onTap: () => context.push(RoutePaths.booking),
                  ),
                ],
                _NavItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  onTap: onSignOut,
                  color: cs.error.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ??
        (active ? AppColors.brandGreen : cs.onSurfaceVariant);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
