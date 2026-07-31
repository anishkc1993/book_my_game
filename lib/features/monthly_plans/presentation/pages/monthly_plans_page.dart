import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/pages/admin_booking_page.dart'
    show PastCustomersSheet;
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../domain/entities/monthly_plan_entity.dart';
import '../providers/monthly_plan_provider.dart';

class MonthlyPlansPage extends StatefulWidget {
  const MonthlyPlansPage({super.key});

  @override
  State<MonthlyPlansPage> createState() => _MonthlyPlansPageState();
}

class _MonthlyPlansPageState extends State<MonthlyPlansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonthlyPlanProvider>().load();
    });
  }

  Future<void> _openEditor(MonthlyPlanEntity? existing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlanEditorSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(MonthlyPlanEntity plan) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove monthly plan?'),
        content: Text(
          '${plan.customerName} · ${plan.daysSummary} · ${plan.timeRange}\n\n'
          'Those slots will free up immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || plan.id == null || !mounted) return;
    final ok = await context.read<MonthlyPlanProvider>().delete(plan.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Plan removed' : 'Failed to remove plan'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _markPaid(MonthlyPlanEntity plan) async {
    if (plan.id == null) return;
    final provider = context.read<MonthlyPlanProvider>();
    final auth = context.read<AuthProvider>();
    final result = await showDialog<({String month, double amount})>(
      context: context,
      builder: (_) => _MarkPaidDialog(
        plan: plan,
        initialMonth: provider.currentMonth,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await provider.markPaid(
      planId: plan.id!,
      month: result.month,
      amount: result.amount,
      markedBy: auth.user?.uid ?? 'admin',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Marked ${plan.customerName} paid for ${result.month}'
          : 'Failed: ${provider.error ?? "unknown"}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<MonthlyPlanProvider>(
          builder: (context, provider, _) {
            final plans = provider.plans;
            final currentMonth = provider.currentMonth;
            return RefreshIndicator(
              onRefresh: provider.load,
              color: AppColors.brandGreen,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                size: 26),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly plans',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fixed monthly fee · auto-blocks slots',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _openEditor(null),
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.brandGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.state == MonthlyPlanState.loading &&
                      plans.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (plans.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(onAdd: () => _openEditor(null)),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          '${plans.where((p) => p.isActive).length} active · '
                          '${plans.length} total · '
                          'this month: $currentMonth',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      sliver: SliverList.separated(
                        itemBuilder: (_, i) {
                          final p = plans[i];
                          return _PlanCard(
                            plan: p,
                            currentMonth: currentMonth,
                            onToggle: (active) async {
                              if (p.id == null) return;
                              final ok =
                                  await provider.setActive(p.id!, active);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Toggle failed: ${provider.error ?? "unknown error"}'),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            },
                            onEdit: () => _openEditor(p),
                            onMarkPaid: () => _markPaid(p),
                            onDelete: () => _confirmDelete(p),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemCount: plans.length,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final MonthlyPlanEntity plan;
  final String currentMonth;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;
  const _PlanCard({
    required this.plan,
    required this.currentMonth,
    required this.onToggle,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onDelete,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paid = plan.isPaidFor(currentMonth);
    final active = plan.isActive;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.brandGreen.withValues(alpha: 0.15)
                      : cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(plan.customerName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: active
                        ? AppColors.brandGreen
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.customerName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: paid
                                ? cs.secondaryContainer
                                : cs.errorContainer
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            paid ? 'PAID · $currentMonth' : 'UNPAID',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: paid
                                  ? cs.onSecondaryContainer
                                  : cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.userPhone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ActiveToggle(
                active: active,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 12),
          // Row 1: days + price
          Row(
            children: [
              Icon(Icons.event_repeat_outlined,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  plan.daysSummary,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rs. ${plan.monthlyFee.toInt()}/mo',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: hours — wrap when there are many.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.schedule_rounded,
                    size: 16, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final h in ([...plan.startHours]..sort()))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          _fmtHourLabel(h),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _CardAction(
                icon: Icons.payments_outlined,
                label: paid ? 'Paid ✓' : 'Mark paid',
                color: AppColors.brandGreen,
                onTap: onMarkPaid,
              ),
              const SizedBox(width: 6),
              _CardAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: cs.onSurfaceVariant,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _CardAction(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                color: cs.error.withValues(alpha: 0.85),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom on/off toggle — explicit GestureDetector instead of [Switch] so
/// the hit area is guaranteed on Web (where Material Switch can miss
/// pointer events inside scaled / scrolled containers).
class _ActiveToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;
  const _ActiveToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!active),
      child: Container(
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandGreen
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.brandGreen
                : cs.outlineVariant,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brandGreen.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: AppColors.brandGreen, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'No monthly plans yet',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Subscribe regulars to a flat monthly fee for fixed slots. '
            'Plan sessions show on the day view but skip the leaderboard.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add monthly plan'),
          ),
        ],
      ),
    );
  }
}

// ─── Editor sheet ─────────────────────────────────────────────────────────────

class _PlanEditorSheet extends StatefulWidget {
  final MonthlyPlanEntity? existing;
  const _PlanEditorSheet({this.existing});

  @override
  State<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<_PlanEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _notesCtrl;
  late final Set<int> _selectedDays;
  late final Set<int> _selectedHours;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _nameError;
  String? _phoneError;
  bool _submitting = false;
  Future<List<({String name, String phone})>>? _customersFuture;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _customersFuture =
        context.read<BookingProvider>().recentCustomers();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    final phoneStripped = e?.userPhone
            .replaceFirst(RegExp(r'^\+?977'), '')
            .replaceAll(RegExp(r'\D'), '') ??
        '';
    _phoneCtrl = TextEditingController(text: phoneStripped);
    _feeCtrl = TextEditingController(
        text: e?.monthlyFee != null && e!.monthlyFee > 0
            ? e.monthlyFee.toInt().toString()
            : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _selectedDays = {...?e?.daysOfWeek};
    _selectedHours = {...?e?.startHours};
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _feeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPastCustomer() async {
    List<({String name, String phone})> suggestions;
    try {
      suggestions = await (_customersFuture ??
          context.read<BookingProvider>().recentCustomers());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not load past customers: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!mounted) return;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No past customers yet'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final picked = await showModalBottomSheet<({String name, String phone})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => PastCustomersSheet(customers: suggestions),
    );
    if (picked == null || !mounted) return;
    final stripped = picked.phone.startsWith('+977')
        ? picked.phone.substring(4)
        : picked.phone;
    setState(() {
      _nameCtrl.text = picked.name;
      _phoneCtrl.text = stripped;
      _nameError = null;
      _phoneError = null;
    });
  }

  bool get _canSave {
    final fee = double.tryParse(_feeCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
        _phoneCtrl.text.trim().length == 10 &&
        _selectedDays.isNotEmpty &&
        _selectedHours.isNotEmpty &&
        fee != null &&
        fee > 0 &&
        !_submitting;
  }

  Future<void> _save() async {
    final nameErr =
        _nameCtrl.text.trim().isEmpty ? 'Name required' : null;
    final phoneErr = Validators.validatePhoneNumber(_phoneCtrl.text);
    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
    });
    if (nameErr != null || phoneErr != null) return;
    if (_selectedDays.isEmpty || _selectedHours.isEmpty) return;
    final fee = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    if (fee <= 0) return;

    final adminId = context.read<AuthProvider>().user?.uid ?? '';
    final provider = context.read<MonthlyPlanProvider>();
    setState(() => _submitting = true);

    final phone = Validators.formatPhoneNumber(
      _phoneCtrl.text,
      countryCode: AppConstants.defaultCountryCode,
    );
    final daysSorted = _selectedDays.toList()..sort();
    final hoursSorted = _selectedHours.toList()..sort();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final entity = (widget.existing ??
            MonthlyPlanEntity(
              customerName: '',
              userPhone: '',
              daysOfWeek: const [],
              startHours: const [],
              monthlyFee: 0,
              startDate: DateTime.now(),
              createdByAdmin: adminId,
            ))
        .copyWith(
      customerName: _nameCtrl.text.trim(),
      userPhone: phone,
      daysOfWeek: daysSorted,
      startHours: hoursSorted,
      monthlyFee: fee,
      startDate: _startDate,
      endDate: _endDate,
      notes: notes,
    );

    final ok = await provider.save(entity);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Plan updated' : 'Plan added'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to save'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  String _fmtHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = List<int>.generate(
        AppConstants.slotEndHour - AppConstants.slotStartHour,
        (i) => AppConstants.slotStartHour + i);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit plan' : 'New monthly plan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fixed fee · runs every week',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: _Label('Customer name')),
                TextButton.icon(
                  onPressed: _pickPastCustomer,
                  icon: const Icon(Icons.contacts_outlined, size: 16),
                  label: const Text('Pick past customer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandGreen,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Aakash Rai',
                errorText: _nameError,
                prefixIcon: Icon(Icons.person_outline_rounded,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 18),
            const _Label('Phone'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇳🇵', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text('+977',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '98XX XXXXXX',
                      errorText: _phoneError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _Label('Days of the week'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final selected = _selectedDays.contains(dayNum);
                return Tooltip(
                  message: dayNames[i],
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedDays.remove(dayNum);
                        } else {
                          _selectedDays.add(dayNum);
                        }
                      });
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.brandGreen
                            : cs.surfaceContainerLow,
                        border: Border.all(
                          color: selected
                              ? AppColors.brandGreen
                              : cs.outlineVariant,
                        ),
                      ),
                      child: Text(
                        dayLabels[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const _Label('Hours'),
                const Spacer(),
                Text(
                  _selectedHours.isEmpty
                      ? 'Tap to add'
                      : '${_selectedHours.length} selected',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: hours.length,
              itemBuilder: (_, i) {
                final h = hours[i];
                final selected = _selectedHours.contains(h);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedHours.remove(h);
                    } else {
                      _selectedHours.add(h);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandGreen
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.brandGreen
                            : cs.outlineVariant,
                      ),
                    ),
                    child: Text(
                      _fmtHour(h),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : cs.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            const _Label('Monthly fee'),
            const SizedBox(height: 8),
            TextField(
              controller: _feeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. 8000',
                prefixText: 'Rs. ',
                prefixIcon: Icon(Icons.payments_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                helperText: 'Customer pays this amount per month.',
              ),
            ),
            const SizedBox(height: 22),
            const _Label('Starting from'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Ending on (optional)'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickEndDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _endDate != null
                        ? cs.outlineVariant
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 18,
                        color: _endDate != null
                            ? cs.onSurface
                            : cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'No end date — runs indefinitely',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: _endDate != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _endDate != null
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_endDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _endDate = null),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                      )
                    else
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _Label('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Pays via eSewa on the 1st',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Add plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ─── Mark-paid dialog ─────────────────────────────────────────────────────────

class _MarkPaidDialog extends StatefulWidget {
  final MonthlyPlanEntity plan;
  final String initialMonth;
  const _MarkPaidDialog({required this.plan, required this.initialMonth});

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  late String _month;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _amountCtrl = TextEditingController(
        text: widget.plan.monthlyFee.toInt().toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  /// Build the 3 most recent months (this month, prev, prev-prev) for the
  /// admin to pick from — covers backfill scenarios.
  List<String> _recentMonths() {
    final now = DateTime.now();
    return List.generate(3, (i) {
      final m = DateTime(now.year, now.month - i, 1);
      return MonthlyPlanEntity.monthKey(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AlertDialog(
      title: Text('Mark ${widget.plan.customerName} paid'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Records a payment row and counts toward dashboard revenue '
            'for the selected month.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: _recentMonths()
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _month = v);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Amount received (Rs.)',
              prefixText: 'Rs. ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amountCtrl.text);
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid amount'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            Navigator.pop(context, (month: _month, amount: amount));
          },
          child: const Text('Mark paid'),
        ),
      ],
    );
  }
}

String _fmtHourLabel(int h) {
  if (h == 0) return '12 AM';
  if (h < 12) return '$h AM';
  if (h == 12) return '12 PM';
  return '${h - 12} PM';
}
