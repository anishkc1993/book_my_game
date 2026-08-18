import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Overflow menu for admin shortcuts that don't fit in the Quick actions
/// row. Currently hosts Cafe (concessions); future tools land here.
class MoreActionsPage extends StatelessWidget {
  const MoreActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final tiles = <_MoreEntry>[
      _MoreEntry(
        icon: Icons.card_giftcard_outlined,
        label: 'Free games',
        subtitle: 'Loyalty rewards · claim & reset',
        route: RoutePaths.rewards,
        iconColor: AppColors.brandGreen,
      ),
      _MoreEntry(
        icon: Icons.local_cafe_outlined,
        label: 'Cafe',
        subtitle: 'Water, tea, soft drinks · sales log',
        route: RoutePaths.concessions,
        iconColor: const Color(0xFF2563EB),
      ),
      _MoreEntry(
        icon: Icons.leaderboard_outlined,
        label: 'Leaderboard',
        subtitle: 'Top bookers · all-time rankings',
        route: RoutePaths.leaderboard,
        iconColor: const Color(0xFF7C3AED),
      ),
      _MoreEntry(
        icon: Icons.block_outlined,
        label: 'Block hours',
        subtitle: 'Enable or disable bookable time slots',
        route: RoutePaths.slotManagement,
        iconColor: Colors.orange,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                            'More actions',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Additional admin tools',
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList.separated(
                itemBuilder: (_, i) =>
                    _MoreTile(entry: tiles[i]),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemCount: tiles.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Color iconColor;
  const _MoreEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.iconColor,
  });
}

class _MoreTile extends StatelessWidget {
  final _MoreEntry entry;
  const _MoreTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () => context.push(entry.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(entry.icon, color: entry.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
