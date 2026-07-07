import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/reward_entity.dart';
import '../providers/booking_provider.dart';

/// Standalone admin page for the loyalty rewards program.
/// Lists every customer with progress, with eligible customers floated
/// to the top. Tapping Claim resets `progressCount` to 0 and bumps
/// `totalClaimed` (same call as the booking-row Claim free flow).
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Map<String, String> _nameByPhone = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BookingProvider>();
      // Pull both: reward progress + recent customers (for name lookup
      // since RewardEntity only stores phone). recentCustomers is cached
      // on the provider so this is cheap on subsequent opens.
      await bp.fetchAllRewards();
      try {
        final customers = await bp.recentCustomers();
        if (!mounted) return;
        final names = <String, String>{
          for (final c in customers)
            _normalizePhone(c.phone): c.name,
        };
        // Overlay leaderboard name overrides — they take priority over
        // whatever customerName was stored on the booking documents.
        final turfId = bp.turfId;
        if (turfId != null && turfId.isNotEmpty) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('leaderboard_overrides')
                .doc(turfId)
                .get();
            final raw =
                doc.data()?['names'] as Map<String, dynamic>? ?? {};
            raw.forEach((phone, name) {
              if (name is String && name.isNotEmpty) {
                names[phone] = name;
              }
            });
          } catch (_) {/* overrides fetch is optional */}
        }
        if (!mounted) return;
        setState(() => _nameByPhone = names);
      } catch (_) {/* name lookup is optional */}
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('977') && d.length > 10) d = d.substring(3);
    return d;
  }

  String _nameFor(String phone) {
    final norm = _normalizePhone(phone);
    final name = _nameByPhone[norm];
    return (name != null && name.isNotEmpty) ? name : phone;
  }

  Future<void> _toggleExcluded(
      BookingProvider bp, _RewardView view, bool nextExcluded) async {
    final ok = await bp.setRewardExcluded(view.phone, nextExcluded);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (nextExcluded
              ? 'Excluded from rewards'
              : 'Included in rewards')
          : 'Failed to update'),
      backgroundColor: ok
          ? AppColors.brandGreen
          : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _confirmClaim(BookingProvider bp, _RewardView view) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: AppColors.brandGreen),
            SizedBox(width: 8),
            Text('Claim free game?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_nameFor(view.phone),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(view.phone,
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(
              'This resets their count and increments total claims. '
              'To also mark a specific booking as the free game, claim '
              'it from the booking row instead.',
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await bp.claimFreeGame(view.phone);
    if (success) {
      // Reload live counts so the row drops out of "Ready to claim".
      await bp.fetchAllRewards();
    }
    if (!mounted) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Free game claimed' : 'Failed to claim'),
      backgroundColor:
          success ? AppColors.brandGreen : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, bp, _) {
            final threshold = bp.freeGameThreshold;

            // Build a unified list of customers from the live count map
            // (current cycle counts) merged with the rewards collection
            // (for totalClaimed / lastClaimedAt). Live counts are the
            // source of truth — same rule the leaderboard uses.
            final phones = <String>{
              ...bp.liveCountsByPhone.keys,
              ...bp.rewardsByPhone.values.map((r) => _normalizePhone(r.userPhone)),
            };

            String displayPhone(String norm) {
              final r = bp.rewardsByPhone.values.firstWhere(
                  (x) => _normalizePhone(x.userPhone) == norm,
                  orElse: () => RewardEntity(userPhone: '+977$norm'));
              return r.userPhone.isEmpty ? '+977$norm' : r.userPhone;
            }

            final all = phones.map((norm) {
              final r = bp.rewardsByPhone.values.firstWhere(
                  (x) => _normalizePhone(x.userPhone) == norm,
                  orElse: () => const RewardEntity(userPhone: ''));
              return _RewardView(
                phone: displayPhone(norm),
                normalizedPhone: norm,
                progress: bp.liveCountsByPhone[norm] ?? 0,
                totalClaimed: r.totalClaimed,
                lastClaimedAt: r.lastClaimedAt,
                excluded: r.excluded,
              );
            }).toList();

            // Filter by search.
            final q = _query.toLowerCase();
            final filtered = q.isEmpty
                ? all
                : all.where((r) {
                    final name = _nameByPhone[r.normalizedPhone]
                            ?.toLowerCase() ??
                        '';
                    return r.phone.contains(q) || name.contains(q);
                  }).toList();

            // Partition: eligible first, in-progress, already-claimed,
            // and excluded (admin-opted-out) at the bottom.
            final eligible = filtered
                .where((r) =>
                    !r.excluded &&
                    threshold > 0 &&
                    r.progress >= threshold)
                .toList()
              ..sort((a, b) => b.progress.compareTo(a.progress));
            final inProgress = filtered
                .where((r) =>
                    !r.excluded &&
                    r.progress > 0 &&
                    (threshold <= 0 || r.progress < threshold))
                .toList()
              ..sort((a, b) => b.progress.compareTo(a.progress));
            final claimedOnly = filtered
                .where((r) =>
                    !r.excluded &&
                    r.progress == 0 &&
                    r.totalClaimed > 0)
                .toList()
              ..sort((a, b) => b.totalClaimed.compareTo(a.totalClaimed));
            final excluded = filtered.where((r) => r.excluded).toList()
              ..sort((a, b) =>
                  b.progress.compareTo(a.progress));

            return RefreshIndicator(
              color: AppColors.brandGreen,
              onRefresh: bp.fetchAllRewards,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 26),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Free games',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  threshold > 0
                                      ? 'Reward after every $threshold games'
                                      : 'Loyalty rewards disabled',
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

                  // Eligible-count banner (only when there are any).
                  if (eligible.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
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
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.limeAccent
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppColors.limeAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${eligible.length} customer${eligible.length == 1 ? '' : 's'} earned a free game',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Claim resets their counter to 0',
                                      style: TextStyle(
                                        color: Color(0xFF9FBA8B),
                                        fontSize: 12,
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

                  // Search.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by name or number',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sections.
                  if (eligible.isNotEmpty) ...[
                    _sectionHeader(context, 'Ready to claim',
                        Icons.celebration_rounded, AppColors.brandGreen),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList.separated(
                        itemCount: eligible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _RewardRow(
                          view: eligible[i],
                          customerName: _nameFor(eligible[i].phone),
                          threshold: threshold,
                          canClaim: true,
                          onClaim: () => _confirmClaim(bp, eligible[i]),
                          onToggleExcluded: (v) =>
                              _toggleExcluded(bp, eligible[i], v),
                        ),
                      ),
                    ),
                  ],

                  if (inProgress.isNotEmpty) ...[
                    _sectionHeader(context, 'In progress',
                        Icons.timeline_rounded, cs.onSurfaceVariant),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList.separated(
                        itemCount: inProgress.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _RewardRow(
                          view: inProgress[i],
                          customerName: _nameFor(inProgress[i].phone),
                          threshold: threshold,
                          canClaim: false,
                          onToggleExcluded: (v) =>
                              _toggleExcluded(bp, inProgress[i], v),
                        ),
                      ),
                    ),
                  ],

                  if (excluded.isNotEmpty) ...[
                    _sectionHeader(context, 'Excluded',
                        Icons.block_rounded, cs.error),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList.separated(
                        itemCount: excluded.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _RewardRow(
                          view: excluded[i],
                          customerName: _nameFor(excluded[i].phone),
                          threshold: threshold,
                          canClaim: false,
                          onToggleExcluded: (v) =>
                              _toggleExcluded(bp, excluded[i], v),
                        ),
                      ),
                    ),
                  ],

                  if (claimedOnly.isNotEmpty) ...[
                    _sectionHeader(context, 'Already claimed',
                        Icons.history_rounded, cs.onSurfaceVariant),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.separated(
                        itemCount: claimedOnly.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _RewardRow(
                          view: claimedOnly[i],
                          customerName: _nameFor(claimedOnly[i].phone),
                          threshold: threshold,
                          canClaim: false,
                          onToggleExcluded: (v) =>
                              _toggleExcluded(bp, claimedOnly[i], v),
                        ),
                      ),
                    ),
                  ],

                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                        child: Center(
                          child: Text(
                            q.isEmpty
                                ? 'No reward records yet'
                                : 'No match for "$_query"',
                            style:
                                TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext context, String label, IconData icon, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final _RewardView view;
  final String customerName;
  final int threshold;
  final bool canClaim;
  final VoidCallback? onClaim;
  /// Toggles the admin-controlled `excluded` flag. Receives the new
  /// state (true → opt-out, false → opt back in).
  final ValueChanged<bool>? onToggleExcluded;
  const _RewardRow({
    required this.view,
    required this.customerName,
    required this.threshold,
    required this.canClaim,
    this.onClaim,
    this.onToggleExcluded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = view.progress;
    final ratio = threshold > 0 ? (progress / threshold).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: canClaim
            ? AppColors.brandGreen.withValues(alpha: 0.08)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canClaim
              ? AppColors.brandGreen.withValues(alpha: 0.5)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded,
                    color: AppColors.brandGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      view.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (view.totalClaimed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${view.totalClaimed}× claimed',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (onToggleExcluded != null)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_vert_rounded,
                      color: cs.onSurfaceVariant, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onSelected: (v) {
                    if (v == 'toggle_excluded') {
                      onToggleExcluded!(!view.excluded);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'toggle_excluded',
                      child: Row(
                        children: [
                          Icon(
                            view.excluded
                                ? Icons.add_task_rounded
                                : Icons.block_rounded,
                            size: 18,
                            color: view.excluded
                                ? AppColors.brandGreen
                                : cs.error,
                          ),
                          const SizedBox(width: 10),
                          Text(view.excluded
                              ? 'Include in rewards'
                              : 'Exclude from rewards'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      canClaim ? AppColors.brandGreen : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                threshold > 0 ? '$progress / $threshold' : '$progress',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: canClaim ? AppColors.brandGreen : cs.onSurface,
                ),
              ),
            ],
          ),
          if (canClaim) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.card_giftcard_rounded, size: 15),
                label: const Text('Claim & reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Merged view of a customer's reward state — live progress from
/// the bookings count + bookkeeping from the rewards doc.
class _RewardView {
  final String phone;
  final String normalizedPhone;
  final int progress;
  final int totalClaimed;
  final DateTime? lastClaimedAt;
  final bool excluded;
  const _RewardView({
    required this.phone,
    required this.normalizedPhone,
    required this.progress,
    required this.totalClaimed,
    required this.lastClaimedAt,
    this.excluded = false,
  });
}
