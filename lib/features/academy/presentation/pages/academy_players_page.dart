import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/academy_player_entity.dart';
import '../../domain/entities/squad_entity.dart';
import '../providers/academy_provider.dart';

class AcademyPlayersPage extends StatefulWidget {
  const AcademyPlayersPage({super.key});

  @override
  State<AcademyPlayersPage> createState() => _AcademyPlayersPageState();
}

class _AcademyPlayersPageState extends State<AcademyPlayersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final turfId = auth.user?.turfId;
    if (turfId == null) return;
    await context.read<AcademyProvider>().load(turfId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final academy = context.watch<AcademyProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: cs.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(theme: theme)),
              if (academy.state == AcademyState.loading &&
                  academy.squads.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (academy.squads.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    onCreate: () => _openSquadEditor(context, null),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _SquadTabs(academy: academy)),
                SliverToBoxAdapter(
                  child: _SquadInfoCard(
                    squad: academy.selectedSquad!,
                    onEdit: () =>
                        _openSquadEditor(context, academy.selectedSquad!),
                  ),
                ),
                SliverToBoxAdapter(child: _StatsRow(academy: academy)),
                SliverToBoxAdapter(child: _FeeProgressCard(academy: academy)),
                SliverToBoxAdapter(
                  child: _QuickActions(
                    onAttendance: () => _comingSoon(context, 'Attendance'),
                    onAddPlayer: () => _openPlayerEditor(context, null),
                    onCollectFee: () => _openCollectFee(context),
                    onMessageParents: () => _comingSoon(context, 'Messaging'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RosterSection(
                    academy: academy,
                    onTap: (p) => _openPlayerEditor(context, p),
                    onMarkPaid: (p) => _markPaid(context, p),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: academy.squads.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openPlayerEditor(context, null),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add player'),
            ),
    );
  }

  // ── Player editor ────────────────────────────────────────────────────────
  Future<void> _openPlayerEditor(
      BuildContext context, AcademyPlayerEntity? existing) async {
    final academy = context.read<AcademyProvider>();
    final squad = academy.selectedSquad;
    if (squad == null || squad.id == null) return;
    final saved = await showModalBottomSheet<AcademyPlayerEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _PlayerEditorSheet(existing: existing, squadId: squad.id!),
    );
    if (saved != null) {
      await academy.savePlayer(saved);
    }
  }

  // ── Squad editor ─────────────────────────────────────────────────────────
  Future<void> _openSquadEditor(
      BuildContext context, SquadEntity? existing) async {
    final saved = await showModalBottomSheet<SquadEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SquadEditorSheet(existing: existing),
    );
    if (saved != null && context.mounted) {
      await context.read<AcademyProvider>().saveSquad(saved);
    }
  }

  // ── Collect fee picker ───────────────────────────────────────────────────
  Future<void> _openCollectFee(BuildContext context) async {
    final academy = context.read<AcademyProvider>();
    final unpaid = academy.playersForSelectedSquad
        .where((p) => !p.isPaidFor(academy.currentMonth))
        .toList();
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Everyone has paid this month 🎉')),
      );
      return;
    }
    final picked = await showModalBottomSheet<AcademyPlayerEntity>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CollectFeeSheet(unpaid: unpaid),
    );
    if (picked != null && context.mounted) await _markPaid(context, picked);
  }

  Future<void> _markPaid(
      BuildContext context, AcademyPlayerEntity p) async {
    final academy = context.read<AcademyProvider>();
    final auth = context.read<AuthProvider>();
    if (p.id == null) return;
    final ok = await academy.markFeePaid(
      playerId: p.id!,
      amount: p.monthlyFee,
      markedBy: auth.user?.uid ?? 'admin',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Marked ${p.name} as paid for ${academy.currentMonth}'
          : 'Could not mark paid: ${academy.error ?? 'unknown error'}'),
    ));
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Header (back arrow + ACADEMY label + title + bell)
// ════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACADEMY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.2,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Players',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Squad tabs (U-13 / U-16 …)
// ════════════════════════════════════════════════════════════════════════════
class _SquadTabs extends StatelessWidget {
  const _SquadTabs({required this.academy});
  final AcademyProvider academy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: academy.squads.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = academy.squads[i];
          final selected = s.id == academy.selectedSquadId;
          return GestureDetector(
            onTap: () => academy.selectSquad(s.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                ),
              ),
              child: Text(
                s.shortLabel.isEmpty ? s.name : s.shortLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Squad info card (coach + schedule)
// ════════════════════════════════════════════════════════════════════════════
class _SquadInfoCard extends StatelessWidget {
  const _SquadInfoCard({required this.squad, required this.onEdit});
  final SquadEntity squad;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = _formatDays(squad.daysOfWeek);
    final schedule = squad.scheduleRange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              child: Text(
                squad.coachInitials ?? '—',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    squad.coachName?.isNotEmpty == true
                        ? 'Coach ${squad.coachName}'
                        : 'No coach assigned',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    squad.name +
                        (squad.description != null &&
                                squad.description!.isNotEmpty
                            ? ' · ${squad.description}'
                            : ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [days, schedule]
                              .where((v) => v != null && v.isNotEmpty)
                              .join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDays(List<int> days) {
    if (days.isEmpty) return null;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...days]..sort();
    return sorted.map((d) => labels[(d - 1).clamp(0, 6)]).join(', ');
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Stat cards row (Players / Attendance / Fees due)
// ════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.academy});
  final AcademyProvider academy;

  @override
  Widget build(BuildContext context) {
    final fees = academy.feeSummary;
    final unpaid = fees.totalCount - fees.paidCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.groups_2_outlined,
              label: 'Players',
              value: '${fees.totalCount}',
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _StatCard(
              icon: Icons.event_available_outlined,
              label: 'Attendance',
              value: '—',
              hint: 'Soon',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.payments_outlined,
              label: 'Unpaid',
              value: '$unpaid',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Fee progress card
// ════════════════════════════════════════════════════════════════════════════
class _FeeProgressCard extends StatelessWidget {
  const _FeeProgressCard({required this.academy});
  final AcademyProvider academy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fees = academy.feeSummary;
    final progress = fees.expected <= 0
        ? 0.0
        : (fees.collected / fees.expected).clamp(0.0, 1.0);
    final monthLabel = _humanMonth(academy.currentMonth);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.tertiary],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fees · $monthLabel',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${fees.paidCount}/${fees.totalCount} paid',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Rs ${fees.collected.toStringAsFixed(0)} / Rs ${fees.expected.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.onPrimary.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.limeAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanMonth(String yyyymm) {
    final parts = yyyymm.split('-');
    if (parts.length != 2) return yyyymm;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
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
    return '${names[(m - 1).clamp(0, 11)]} $y';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Quick actions grid (Take attendance / Add player / Collect fee / Message)
// ════════════════════════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAttendance,
    required this.onAddPlayer,
    required this.onCollectFee,
    required this.onMessageParents,
  });
  final VoidCallback onAttendance;
  final VoidCallback onAddPlayer;
  final VoidCallback onCollectFee;
  final VoidCallback onMessageParents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.fact_check_outlined,
                  label: 'Take\nattendance',
                  onTap: onAttendance,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Add\nplayer',
                  onTap: onAddPlayer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Collect\nfee',
                  onTap: onCollectFee,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.sms_outlined,
                  label: 'Message\nparents',
                  onTap: onMessageParents,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Roster preview
// ════════════════════════════════════════════════════════════════════════════
class _RosterSection extends StatelessWidget {
  const _RosterSection({
    required this.academy,
    required this.onTap,
    required this.onMarkPaid,
  });
  final AcademyProvider academy;
  final ValueChanged<AcademyPlayerEntity> onTap;
  final ValueChanged<AcademyPlayerEntity> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final roster = academy.playersForSelectedSquad;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Roster · ${roster.length}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (roster.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.group_outlined, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'No players in this squad yet',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            for (final p in roster) ...[
              _PlayerRow(
                player: p,
                month: academy.currentMonth,
                onTap: () => onTap(p),
                onMarkPaid: () => onMarkPaid(p),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.month,
    required this.onTap,
    required this.onMarkPaid,
  });
  final AcademyPlayerEntity player;
  final String month;
  final VoidCallback onTap;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paid = player.isPaidFor(month);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Text(
                _initials(player.name),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (player.age != null) '${player.age} yrs',
                      if (player.position != null) player.position!,
                      'Rs ${player.monthlyFee.toStringAsFixed(0)}/mo',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (paid)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: cs.onSecondaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      'Paid',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: onMarkPaid,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Mark paid'),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Empty state — no squads yet
// ════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Start your academy',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a squad (e.g., U-13) to start tracking players, fees, and training schedules.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create first squad'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Squad editor bottom sheet
// ════════════════════════════════════════════════════════════════════════════
class _SquadEditorSheet extends StatefulWidget {
  const _SquadEditorSheet({required this.existing});
  final SquadEntity? existing;

  @override
  State<_SquadEditorSheet> createState() => _SquadEditorSheetState();
}

class _SquadEditorSheetState extends State<_SquadEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _short;
  late final TextEditingController _coach;
  late final TextEditingController _description;
  late List<int> _days;
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _short = TextEditingController(text: e?.shortLabel ?? '');
    _coach = TextEditingController(text: e?.coachName ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _days = [...?e?.daysOfWeek];
    if (e?.startMinutes != null) {
      _start = TimeOfDay(
          hour: e!.startMinutes! ~/ 60, minute: e.startMinutes! % 60);
    }
    if (e?.endMinutes != null) {
      _end = TimeOfDay(
          hour: e!.endMinutes! ~/ 60, minute: e.endMinutes! % 60);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _coach.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'New squad' : 'Edit squad',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _short,
              decoration: const InputDecoration(
                labelText: 'Tab label (e.g. U-13)',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Squad name (e.g. Junior Squad)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Born 2013-14',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coach,
              decoration: const InputDecoration(labelText: 'Coach name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text('Training days',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_dayLabel(d)),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _days.add(d);
                      } else {
                        _days.remove(d);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _start ?? const TimeOfDay(hour: 16, minute: 0),
                      );
                      if (t != null) setState(() => _start = t);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_start == null
                        ? 'Start time'
                        : _start!.format(context)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _end ?? const TimeOfDay(hour: 17, minute: 30),
                      );
                      if (t != null) setState(() => _end = t);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label:
                        Text(_end == null ? 'End time' : _end!.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save squad'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty || _short.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and tab label are required')),
      );
      return;
    }
    final e = widget.existing;
    final saved = SquadEntity(
      id: e?.id,
      name: _name.text.trim(),
      shortLabel: _short.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      coachName: _coach.text.trim().isEmpty ? null : _coach.text.trim(),
      daysOfWeek: _days,
      startMinutes: _start == null ? null : _start!.hour * 60 + _start!.minute,
      endMinutes: _end == null ? null : _end!.hour * 60 + _end!.minute,
      isActive: e?.isActive ?? true,
      createdAt: e?.createdAt,
    );
    Navigator.of(context).pop(saved);
  }

  String _dayLabel(int d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(d - 1).clamp(0, 6)];
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Player editor bottom sheet
// ════════════════════════════════════════════════════════════════════════════
class _PlayerEditorSheet extends StatefulWidget {
  const _PlayerEditorSheet({required this.existing, required this.squadId});
  final AcademyPlayerEntity? existing;
  final String squadId;

  @override
  State<_PlayerEditorSheet> createState() => _PlayerEditorSheetState();
}

class _PlayerEditorSheetState extends State<_PlayerEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _fee;
  late final TextEditingController _position;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.parentPhone ?? '');
    _fee = TextEditingController(
        text: e?.monthlyFee != null && e!.monthlyFee > 0
            ? e.monthlyFee.toStringAsFixed(0)
            : '');
    _position = TextEditingController(text: e?.position ?? '');
    _dob = e?.dob;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _fee.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'New player' : 'Edit player',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ??
                      DateTime(now.year - 12, now.month, now.day),
                  firstDate: DateTime(now.year - 25),
                  lastDate: now,
                );
                if (picked != null) setState(() => _dob = picked);
              },
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _dob == null
                    ? 'Date of birth'
                    : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Parent phone'),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _position,
              decoration: const InputDecoration(
                labelText: 'Position (optional)',
                hintText: 'Forward / Midfielder / Defender / Goalkeeper',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fee,
              decoration: const InputDecoration(
                labelText: 'Monthly fee (Rs)',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save player'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final e = widget.existing;
    final fee = double.tryParse(_fee.text.trim()) ?? 0;
    final saved = AcademyPlayerEntity(
      id: e?.id,
      name: _name.text.trim(),
      dob: _dob,
      parentPhone:
          _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      position:
          _position.text.trim().isEmpty ? null : _position.text.trim(),
      monthlyFee: fee,
      enrolledAt: e?.enrolledAt,
      isActive: e?.isActive ?? true,
      lastPaidMonth: e?.lastPaidMonth,
      squadId: widget.squadId,
    );
    Navigator.of(context).pop(saved);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Collect fee bottom sheet (pick an unpaid player)
// ════════════════════════════════════════════════════════════════════════════
class _CollectFeeSheet extends StatelessWidget {
  const _CollectFeeSheet({required this.unpaid});
  final List<AcademyPlayerEntity> unpaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Collect fee',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Pick a player to mark as paid for this month',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: unpaid.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = unpaid[i];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                      style: TextStyle(color: cs.onPrimaryContainer),
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Text('Rs ${p.monthlyFee.toStringAsFixed(0)}/mo'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
