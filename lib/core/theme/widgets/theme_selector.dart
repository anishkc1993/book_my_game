import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../theme_provider.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ThemeSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Appearance',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Theme Mode Section
              Text(
                'Mode',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _ThemeModeSelector(
                currentMode: themeProvider.themeMode,
                onModeChanged: themeProvider.setThemeMode,
              ),

              const SizedBox(height: 28),

              // Color Theme Section
              Text(
                'Color Theme',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _ColorThemeGrid(
                currentTheme: themeProvider.currentThemeType,
                onThemeSelected: themeProvider.setThemeType,
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeChanged;

  const _ThemeModeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ModeButton(
            icon: Icons.brightness_auto_rounded,
            label: 'System',
            isSelected: currentMode == ThemeMode.system,
            onTap: () => onModeChanged(ThemeMode.system),
          ),
          _ModeButton(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            isSelected: currentMode == ThemeMode.light,
            onTap: () => onModeChanged(ThemeMode.light),
          ),
          _ModeButton(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => onModeChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorThemeGrid extends StatelessWidget {
  final AppThemeType currentTheme;
  final ValueChanged<AppThemeType> onThemeSelected;

  const _ColorThemeGrid({
    required this.currentTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppThemeType.values.map((themeType) {
        return _ColorThemeCard(
          themeType: themeType,
          isSelected: themeType == currentTheme,
          onTap: () => onThemeSelected(themeType),
        );
      }).toList(),
    );
  }
}

class _ColorThemeCard extends StatelessWidget {
  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorThemeCard({
    required this.themeType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Generate colors from the theme's seed color
    final themeColors = ColorScheme.fromSeed(
      seedColor: themeType.seedColor,
      brightness: theme.brightness,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColors.primaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: themeColors.primary, width: 2)
                : null,
          ),
          child: Column(
            children: [
              // Color preview circles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ColorCircle(color: themeColors.primary),
                  const SizedBox(width: 4),
                  _ColorCircle(color: themeColors.secondary),
                  const SizedBox(width: 4),
                  _ColorCircle(color: themeColors.tertiary),
                ],
              ),
              const SizedBox(height: 10),
              // Theme name
              Text(
                themeType.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? themeColors.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Checkmark for selected
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: themeColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;

  const _ColorCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
    );
  }
}
