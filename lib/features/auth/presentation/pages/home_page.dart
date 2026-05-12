import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/widgets/theme_selector.dart';
import '../providers/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.user;

            return CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  actions: [
                    // Theme Selector Button
                    IconButton(
                      onPressed: () => ThemeSelector.show(context),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                      icon: Icon(
                        Icons.palette_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Logout Button
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        onPressed: () => _signOut(context),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                        icon: Icon(
                          Icons.logout_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),

                      // Welcome Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.sports_esports_rounded,
                                size: 32,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Welcome Back!',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            if (user?.phoneNumber != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_rounded,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user!.phoneNumber!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Status Card - Shows role
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: user?.isAdmin == true
                                    ? colorScheme.primary.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                user?.isAdmin == true
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.verified_rounded,
                                color: user?.isAdmin == true
                                    ? colorScheme.primary
                                    : Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.isAdmin == true ? 'Admin' : 'Verified',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user?.isAdmin == true
                                        ? 'Full access to manage bookings'
                                        : 'Phone number successfully authenticated',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick Actions - Different for Admin vs Customer
                      Text(
                        user?.isAdmin == true ? 'Admin Actions' : 'Quick Actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Admin Actions
                      if (user?.isAdmin == true) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.admin_panel_settings_rounded,
                                label: 'Bookings',
                                color: colorScheme.primary,
                                onTap: () {
                                  context.push(RoutePaths.adminBooking);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.schedule_rounded,
                                label: 'Slots',
                                color: colorScheme.tertiary,
                                onTap: () {
                                  context.push(RoutePaths.slotManagement);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.analytics_rounded,
                                label: 'Analytics',
                                color: Colors.teal,
                                onTap: () {
                                  context.push(RoutePaths.adminAnalytics);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.leaderboard_rounded,
                                label: 'Leaders',
                                color: colorScheme.secondary,
                                onTap: () {
                                  context.push(RoutePaths.leaderboard);
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Customer Actions
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.calendar_month_rounded,
                                label: 'Book',
                                color: colorScheme.primary,
                                onTap: () {
                                  context.push(RoutePaths.booking);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.history_rounded,
                                label: 'History',
                                color: colorScheme.tertiary,
                                onTap: () {
                                  // TODO: Navigate to history
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.palette_rounded,
                                label: 'Theme',
                                color: colorScheme.secondary,
                                onTap: () => ThemeSelector.show(context),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Current Theme Info
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    themeProvider.themeMode == ThemeMode.dark
                                        ? Icons.dark_mode_rounded
                                        : themeProvider.themeMode == ThemeMode.light
                                            ? Icons.light_mode_rounded
                                            : Icons.brightness_auto_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Theme',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        themeProvider.currentThemeType.displayName,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ThemeSelector.show(context),
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Sign Out Button
                      OutlinedButton.icon(
                        onPressed: () => _signOut(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.logout_rounded,
            color: colorScheme.error,
          ),
        ),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
