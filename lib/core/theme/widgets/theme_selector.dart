import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';

class ThemeSelector {
  ThemeSelector._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _ThemeSelectorSheet(),
    );
  }
}

class _ThemeSelectorSheet extends StatelessWidget {
  const _ThemeSelectorSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _ModeOption(
                icon: Icons.light_mode_rounded,
                label: 'Light',
                selected: themeProvider.themeMode == ThemeMode.light,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _ModeOption(
                icon: Icons.dark_mode_rounded,
                label: 'Dark',
                selected: themeProvider.themeMode == ThemeMode.dark,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _ModeOption(
                icon: Icons.brightness_auto_rounded,
                label: 'System default',
                selected: themeProvider.themeMode == ThemeMode.system,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.system);
                  Navigator.pop(context);
                },
                colorScheme: colorScheme,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (selected) Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
