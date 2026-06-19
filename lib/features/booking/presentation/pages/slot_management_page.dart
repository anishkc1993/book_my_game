import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../providers/booking_provider.dart';

class SlotManagementPage extends StatefulWidget {
  const SlotManagementPage({super.key});

  @override
  State<SlotManagementPage> createState() => _SlotManagementPageState();
}

class _SlotManagementPageState extends State<SlotManagementPage> {
  final _morningCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _eveningCtrl = TextEditingController();
  final _weekendCtrl = TextEditingController();
  bool _pricingChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchSlotConfig().then((_) {
        _syncControllers();
      });
    });
  }

  void _syncControllers() {
    final config = context.read<BookingProvider>().slotConfig;
    if (config != null) {
      _morningCtrl.text = config.morningPrice.toInt().toString();
      _dayCtrl.text = config.dayPrice.toInt().toString();
      _eveningCtrl.text = config.eveningPrice.toInt().toString();
      _weekendCtrl.text = config.weekendPrice.toInt().toString();
    }
  }

  @override
  void dispose() {
    _morningCtrl.dispose();
    _dayCtrl.dispose();
    _eveningCtrl.dispose();
    _weekendCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePricing() async {
    final morning = double.tryParse(_morningCtrl.text) ?? 0;
    final day = double.tryParse(_dayCtrl.text) ?? 0;
    final evening = double.tryParse(_eveningCtrl.text) ?? 0;
    final weekend = double.tryParse(_weekendCtrl.text) ?? 0;

    if (morning <= 0 || day <= 0 || evening <= 0 || weekend <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid prices')),
      );
      return;
    }

    final adminId = context.read<AuthProvider>().user?.uid ?? '';
    final success = await context.read<BookingProvider>().updateSlotPricing(
          morningPrice: morning,
          dayPrice: day,
          eveningPrice: evening,
          weekendPrice: weekend,
          adminId: adminId,
        );

    if (mounted) {
      setState(() => _pricingChanged = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update pricing')),
        );
      }
    }
  }

  String _fmt(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _range(int h) => '${_fmt(h)} – ${_fmt(h + 1)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          // Loading / error states
          if (provider.slotConfigState == SlotConfigState.loading &&
              provider.slotConfig == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.slotConfigState == SlotConfigState.error &&
              provider.slotConfig == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: cs.error),
                  const SizedBox(height: 12),
                  Text('Failed to load configuration',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen),
                    onPressed: provider.fetchSlotConfig,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allHours = SlotConfigEntity.allPossibleHours;
          final enabledCount =
              allHours.where((h) => provider.isHourEnabled(h)).length;
          final isSaving =
              provider.slotConfigState == SlotConfigState.saving;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(Icons.arrow_back_rounded,
                              size: 26, color: cs.onSurface),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage slots',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pricing & availability',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => provider
                                  .fetchSlotConfig()
                                  .then((_) => _syncControllers()),
                          icon: isSaving
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: cs.onSurface,
                                  ),
                                )
                              : Icon(Icons.refresh_rounded,
                                  size: 26, color: cs.onSurface),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Slot Pricing Header ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.brandGreen.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(Icons.payments_outlined,
                              color: AppColors.brandGreen, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slot pricing',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Set rates for different parts of the day',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Price Cards ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        _PriceCard(
                          icon: Icons.wb_twilight_outlined,
                          iconBg: const Color(0xFFFEEFE0),
                          iconColor: const Color(0xFFE07820),
                          title: 'Morning',
                          timeRange: '6 AM – 10 AM',
                          controller: _morningCtrl,
                          onChanged: () =>
                              setState(() => _pricingChanged = true),
                        ),
                        const SizedBox(height: 10),
                        _PriceCard(
                          icon: Icons.wb_sunny_outlined,
                          iconBg: const Color(0xFFFFF3E0),
                          iconColor: const Color(0xFFE09810),
                          title: 'Day',
                          timeRange: '10 AM – 5 PM',
                          controller: _dayCtrl,
                          onChanged: () =>
                              setState(() => _pricingChanged = true),
                        ),
                        const SizedBox(height: 10),
                        _PriceCard(
                          icon: Icons.bedtime_outlined,
                          iconBg: const Color(0xFFEEEBF8),
                          iconColor: const Color(0xFF5C5BD6),
                          title: 'Evening',
                          timeRange: '5 PM – 9 PM',
                          controller: _eveningCtrl,
                          onChanged: () =>
                              setState(() => _pricingChanged = true),
                        ),
                        const SizedBox(height: 10),
                        _PriceCard(
                          icon: Icons.weekend_outlined,
                          iconBg: const Color(0xFFE3F2E0),
                          iconColor: const Color(0xFF3D6820),
                          title: 'Weekend',
                          timeRange: 'Sat & Sun · all day',
                          controller: _weekendCtrl,
                          onChanged: () =>
                              setState(() => _pricingChanged = true),
                        ),
                        const SizedBox(height: 14),
                        // Save / Pricing saved button
                        _SavePricingButton(
                          changed: _pricingChanged,
                          saving: isSaving,
                          onSave: _savePricing,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Divider ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                ),

                // ── Loyalty rewards section ─────────────────────────────────
                SliverToBoxAdapter(
                  child: _RewardsSection(
                    config: provider.slotConfig,
                    saving: isSaving,
                  ),
                ),

                // ── Divider ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                ),

                // ── Available Hours Header ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.heroCardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.limeAccent.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(Icons.access_time_rounded,
                              color: AppColors.limeAccent, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available hours',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$enabledCount of ${allHours.length} hours open today',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info Banner ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 20, color: Color(0xFF3B6DE8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Disabled hours won't appear for customers.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF3B6DE8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Slot Toggle Grid ────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.95,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final hour = allHours[index];
                        final isEnabled = provider.isHourEnabled(hour);

                        return _SlotToggleCard(
                          timeRange: _range(hour),
                          isEnabled: isEnabled,
                          isSaving: isSaving,
                          onToggle: () async {
                            final adminId =
                                context.read<AuthProvider>().user?.uid ?? '';
                            await provider.toggleSlotHour(hour, adminId);
                          },
                        );
                      },
                      childCount: allHours.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Price Card ────────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String timeRange;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _PriceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.timeRange,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          // Title + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Price chip
          _PriceChip(controller: controller, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _PriceChip({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Rs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          IntrinsicWidth(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                fontSize: 19,
                height: 1.0,
              ),
              decoration: const InputDecoration.collapsed(hintText: '0'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ hr',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Save Pricing Button ───────────────────────────────────────────────────────

class _SavePricingButton extends StatelessWidget {
  final bool changed;
  final bool saving;
  final VoidCallback onSave;

  const _SavePricingButton({
    required this.changed,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!changed && !saving) {
      // "Pricing saved" state
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded,
                size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Pricing saved',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: saving ? null : onSave,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'Save pricing',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

// ── Slot Toggle Card ──────────────────────────────────────────────────────────

class _SlotToggleCard extends StatelessWidget {
  final String timeRange;
  final bool isEnabled;
  final bool isSaving;
  final VoidCallback onToggle;

  const _SlotToggleCard({
    required this.timeRange,
    required this.isEnabled,
    required this.isSaving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: isSaving ? null : onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? cs.outlineVariant
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeRange,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isEnabled ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled ? 'AVAILABLE' : 'DISABLED',
                    style: TextStyle(
                      color: isEnabled
                          ? AppColors.brandGreen
                          : cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.82,
              alignment: Alignment.centerRight,
              child: Switch(
                value: isEnabled,
                onChanged: isSaving ? null : (_) => onToggle(),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.brandGreen,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: cs.outlineVariant,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loyalty rewards section ───────────────────────────────────────────────────

class _RewardsSection extends StatefulWidget {
  final SlotConfigEntity? config;
  final bool saving;
  const _RewardsSection({required this.config, required this.saving});

  @override
  State<_RewardsSection> createState() => _RewardsSectionState();
}

class _RewardsSectionState extends State<_RewardsSection> {
  final _ctrl = TextEditingController();
  bool _dirty = false;
  int? _hydratedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = widget.config?.freeGameThreshold ?? 0;
    if (_hydratedFor != t) {
      _ctrl.text = t.toString();
      _hydratedFor = t;
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = int.tryParse(_ctrl.text.trim()) ?? 0;
    final adminId = context.read<AuthProvider>().user?.uid ?? '';
    final ok = await context
        .read<BookingProvider>()
        .updateRewardsThreshold(threshold: n, adminId: adminId);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (n == 0
              ? 'Loyalty rewards disabled'
              : 'Free game every $n games')
          : 'Failed to save'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final threshold = widget.config?.freeGameThreshold ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.brandGreen.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.card_giftcard_outlined,
                    color: AppColors.brandGreen, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty rewards',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      threshold > 0
                          ? '1 free game every $threshold qualifying games'
                          : 'Rewards are currently disabled',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (threshold > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Counts only weekday morning + day games',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant
                              .withValues(alpha: 0.75),
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free game after',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '0 turns it off',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(
                        width: 44,
                        child: TextField(
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          decoration:
                              const InputDecoration.collapsed(hintText: '0'),
                          onChanged: (_) =>
                              setState(() => _dirty = true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'games',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (!_dirty || widget.saving) ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                disabledBackgroundColor: cs.surfaceContainerHigh,
                foregroundColor: Colors.white,
                disabledForegroundColor: cs.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _dirty ? 'Save threshold' : '✓ Rewards saved',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
