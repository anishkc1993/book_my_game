import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/turf_entity.dart';
import '../providers/turf_provider.dart';
import '../widgets/venue_google_map.dart';

class TurfSelectionPage extends StatefulWidget {
  const TurfSelectionPage({super.key});

  @override
  State<TurfSelectionPage> createState() => _TurfSelectionPageState();
}

class _TurfSelectionPageState extends State<TurfSelectionPage> {
  String? _selectedTurfId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TurfProvider>().loadActiveTurfs();
      // Pre-select the user's current turf if any, so the existing choice
      // is visible when switching.
      final currentTurfId = context.read<AuthProvider>().user?.turfId;
      if (currentTurfId != null && mounted) {
        setState(() => _selectedTurfId = currentTurfId);
      }
    });
  }

  bool get _hasExistingTurf =>
      context.read<AuthProvider>().user?.turfId != null;

  Future<void> _confirm(TurfEntity turf) async {
    final auth = context.read<AuthProvider>();
    final turfProvider = context.read<TurfProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final ok = await turfProvider.selectTurfForUser(uid, turf);
    if (!mounted) return;
    if (ok) {
      // Refresh auth user so the rest of the app picks up turfId/turfName.
      await auth.refreshCurrentUser();
      if (!mounted) return;
      context.go(RoutePaths.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(turfProvider.error ?? 'Failed to select turf'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<TurfProvider>(
          builder: (context, provider, _) {
            final isSwitching = _hasExistingTurf;
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: back button (only when switching) + logo
                  Row(
                    children: [
                      if (isSwitching)
                        IconButton(
                          onPressed: () => context.go(RoutePaths.home),
                          icon: Icon(Icons.arrow_back_rounded,
                              size: 24, color: cs.onSurface),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                      if (isSwitching) const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'BMG.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isSwitching ? 'Switch turf' : 'Pick your turf',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSwitching
                        ? 'Your bookings will follow the turf you select.'
                        : 'Choose where you play. You can switch later from Profile.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // List
                  Expanded(child: _buildBody(provider, cs, theme)),

                  // Continue button
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_selectedTurfId == null || provider.saving)
                          ? null
                          : () {
                              final turf = provider.turfs
                                  .firstWhere((t) => t.id == _selectedTurfId);
                              _confirm(turf);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        disabledBackgroundColor:
                            AppColors.brandGreen.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: provider.saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(TurfProvider provider, ColorScheme cs, ThemeData theme) {
    if (provider.state == TurfListState.loading && provider.turfs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.state == TurfListState.error && provider.turfs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 36, color: cs.error),
            const SizedBox(height: 8),
            Text(provider.error ?? 'Failed to load turfs'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: provider.loadActiveTurfs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (provider.turfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No turfs available yet. Please check back later.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemBuilder: (_, i) {
        final t = provider.turfs[i];
        final selected = t.id == _selectedTurfId;
        return _TurfCard(
          turf: t,
          selected: selected,
          onTap: () => setState(() => _selectedTurfId = t.id),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: provider.turfs.length,
    );
  }
}

class _TurfCard extends StatelessWidget {
  final TurfEntity turf;
  final bool selected;
  final VoidCallback onTap;
  const _TurfCard({
    required this.turf,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasAddress = turf.oneLineAddress.isNotEmpty;
    final hasLandmark = turf.landmark != null && turf.landmark!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGreen.withValues(alpha: 0.08)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.brandGreen
                : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map preview header (shown when location is set)
            if (turf.hasLocation)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: 110,
                  child: VenueGoogleMap(
                    latitude: turf.latitude,
                    longitude: turf.longitude,
                    height: 110,
                    interactive: false,
                  ),
                ),
              ),
            // Info row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.sports_soccer_rounded,
                        color: AppColors.brandGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turf.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasAddress) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 13,
                                  color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  turf.oneLineAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasLandmark) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.bookmark_outline_rounded,
                                  size: 13,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  turf.landmark!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandGreen
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandGreen
                            : cs.outlineVariant,
                        width: 1.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
