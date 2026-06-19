import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tournaments/presentation/widgets/tournaments_tab.dart';
import '../../domain/entities/regular_booking_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../providers/booking_provider.dart';

class RegularBookingsPage extends StatefulWidget {
  const RegularBookingsPage({super.key});

  @override
  State<RegularBookingsPage> createState() => _RegularBookingsPageState();
}

class _RegularBookingsPageState extends State<RegularBookingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<BookingProvider>();
      p.fetchSlotConfig();
      p.fetchRegularBookings();
    });
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddRegularBookingSheet(),
    );
  }

  Future<void> _openEditSheet(RegularBookingEntity reg) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRegularBookingSheet(existing: reg),
    );
  }

  Future<void> _confirmDelete(RegularBookingEntity reg) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove regular?'),
        content: Text(
          '${reg.customerName} · ${reg.daysSummary} · ${reg.timeRange}\n\n'
          'This will free up those slots for new bookings.',
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
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || reg.id == null) return;
    if (!mounted) return;
    final ok = await context.read<BookingProvider>().deleteRegularBooking(reg.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Regular removed' : 'Failed to remove regular'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ── Page header (shared across tabs) ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded,
                          size: 26, color: cs.onSurface),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recurring & events',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Weekly slots and one-off tournaments',
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
              const SizedBox(height: 8),
              TabBar(
                indicatorColor: AppColors.brandGreen,
                indicatorWeight: 3,
                labelColor: cs.onSurface,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: const [
                  Tab(text: 'Regulars'),
                  Tab(text: 'Tournaments'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // ── Regulars tab (original list) ────────────────────────
                    Consumer<BookingProvider>(
                      builder: (context, provider, _) {
                        final regulars = provider.regulars;
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 12, 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        regulars.isEmpty
                                            ? '0 regulars'
                                            : '${regulars.where((r) => r.isActive).length} active · '
                                                '${regulars.length} total',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _openAddSheet,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
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
                            if (provider.regularsLoading && regulars.isEmpty)
                              const SliverFillRemaining(
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (regulars.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyState(onAdd: _openAddSheet),
                              )
                            else
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                sliver: SliverList.separated(
                                  itemBuilder: (_, i) => _RegularCard(
                                    regular: regulars[i],
                                    onToggle: (active) {
                                      final id = regulars[i].id;
                                      if (id == null) return;
                                      context
                                          .read<BookingProvider>()
                                          .setRegularBookingActive(
                                              id, active);
                                    },
                                    onDelete: () =>
                                        _confirmDelete(regulars[i]),
                                    onEdit: () =>
                                        _openEditSheet(regulars[i]),
                                  ),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemCount: regulars.length,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    // ── Tournaments tab ─────────────────────────────────────
                    const TournamentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: const Icon(Icons.event_repeat_outlined,
                color: AppColors.brandGreen, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'No regulars yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up weekly recurring slots for regular bookers — '
            'they\'ll auto-block on every matching day.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add regular booking'),
          ),
        ],
      ),
    );
  }
}

// ── List card ────────────────────────────────────────────────────────────────

class _RegularCard extends StatelessWidget {
  final RegularBookingEntity regular;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RegularCard({
    required this.regular,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = regular.isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Top: avatar + name + phone + amount + toggle
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
                  _initials(regular.customerName),
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
                    Text(
                      regular.customerName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      regular.userPhone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.82,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: active,
                  onChanged: onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.brandGreen,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 12),
          // Row: days + time + amount
          Row(
            children: [
              Icon(Icons.event_repeat_outlined,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  regular.daysSummary,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule_rounded,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                regular.timeRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Rs. ${regular.basePrice.toInt()}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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

// ── Add sheet ────────────────────────────────────────────────────────────────

class _AddRegularBookingSheet extends StatefulWidget {
  /// When non-null, the sheet opens in edit mode and updates the existing
  /// regular booking instead of creating a new one.
  final RegularBookingEntity? existing;

  const _AddRegularBookingSheet({this.existing});

  @override
  State<_AddRegularBookingSheet> createState() =>
      _AddRegularBookingSheetState();
}

class _AddRegularBookingSheetState extends State<_AddRegularBookingSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _priceCtrl;
  late final Set<int> _selectedDays;
  int? _selectedHour;
  DateTime _startDate = DateTime.now();
  String? _nameError;
  String? _phoneError;
  bool _submitting = false;
  // Once admin types in the price, stop auto-updating it from day/hour
  // changes — they've expressed an intentional override.
  bool _priceTouched = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    // Strip the country code prefix for the input — saved with +977 when new.
    final phoneStripped = e?.userPhone
            .replaceFirst(RegExp(r'^\+?977'), '')
            .replaceAll(RegExp(r'\D'), '') ??
        '';
    _phoneCtrl = TextEditingController(text: phoneStripped);
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _selectedDays = {...?e?.daysOfWeek};
    _selectedHour = e?.startHour;
    _startDate = e?.startDate ?? DateTime.now();
    _priceCtrl = TextEditingController(
        text: e?.basePrice != null && e!.basePrice > 0
            ? e.basePrice.toInt().toString()
            : '');
    // When editing, the stored price is the source of truth — treat it as
    // already overridden so it doesn't get auto-rewritten on first build.
    _priceTouched = _isEdit;
  }

  /// Auto-populate the price field from slot config when admin hasn't
  /// manually edited it yet.
  void _maybeAutoFillPrice(BookingProvider provider) {
    if (_priceTouched) return;
    if (_selectedHour == null || _selectedDays.isEmpty) return;
    final derived =
        provider.getPriceForRegular(_selectedHour!, _selectedDays.toList());
    if (derived == null) return;
    final newText = derived.toInt().toString();
    if (_priceCtrl.text != newText) {
      _priceCtrl.text = newText;
      _priceCtrl.selection =
          TextSelection.collapsed(offset: _priceCtrl.text.length);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final priceVal = double.tryParse(_priceCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
        _phoneCtrl.text.trim().length == 10 &&
        _selectedDays.isNotEmpty &&
        _selectedHour != null &&
        priceVal != null &&
        priceVal > 0 &&
        !_submitting;
  }

  Future<void> _save() async {
    final nameErr = _nameCtrl.text.trim().isEmpty ? 'Name required' : null;
    final phoneErr = Validators.validatePhoneNumber(_phoneCtrl.text);
    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
    });
    if (nameErr != null || phoneErr != null) return;
    if (_selectedDays.isEmpty || _selectedHour == null) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<BookingProvider>();
    final adminId = auth.user?.uid ?? '';

    setState(() => _submitting = true);
    final formattedPhone = Validators.formatPhoneNumber(
      _phoneCtrl.text,
      countryCode: AppConstants.defaultCountryCode,
    );
    final daysSorted = _selectedDays.toList()..sort();
    final notesText =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final priceVal = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    final bool ok;
    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        customerName: _nameCtrl.text.trim(),
        userPhone: formattedPhone,
        daysOfWeek: daysSorted,
        startHour: _selectedHour!,
        startDate: _startDate,
        notes: notesText,
        basePrice: priceVal,
      );
      ok = await provider.updateRegularBooking(updated);
    } else {
      ok = await provider.createRegularBooking(
        customerName: _nameCtrl.text.trim(),
        userPhone: formattedPhone,
        daysOfWeek: daysSorted,
        startHour: _selectedHour!,
        startDate: _startDate,
        notes: notesText,
        adminId: adminId,
        basePriceOverride: priceVal,
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Regular updated' : 'Regular booking added'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.regularsError ?? 'Failed to save'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
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
    final provider = context.watch<BookingProvider>();
    final config = provider.slotConfig;
    final enabledHours = (config?.enabledHours ?? SlotConfigEntity.allPossibleHours)
        .toList()
      ..sort();

    final derivedPrice = _selectedHour != null
        ? provider.getPriceForRegular(_selectedHour!, _selectedDays.toList())
        : null;
    // Side-effect on build is fine here — _maybeAutoFillPrice no-ops once
    // the user has touched the price field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoFillPrice(provider);
    });

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New regular',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Weekly recurring · auto-blocks slots',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      size: 22, color: cs.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Customer name
            const _FieldLabel(label: 'Customer name'),
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

            // Phone
            const _FieldLabel(label: 'Phone'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                      Text(
                        '+977',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                        setState(() {}); // refresh canSave
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

            // Days of week
            const _FieldLabel(label: 'Repeat on'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final selected = _selectedDays.contains(dayNum);
                return _DayChip(
                  letter: dayLabels[i],
                  tooltip: dayNames[i],
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedDays.remove(dayNum);
                      } else {
                        _selectedDays.add(dayNum);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 22),

            // Time slot
            const _FieldLabel(label: 'Time slot'),
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
              itemCount: enabledHours.length,
              itemBuilder: (_, i) {
                final h = enabledHours[i];
                final selected = _selectedHour == h;
                return _HourChip(
                  label: _fmtHour(h),
                  selected: selected,
                  onTap: () => setState(() => _selectedHour = h),
                );
              },
            ),
            const SizedBox(height: 22),

            // Price (editable override)
            Row(
              children: [
                const _FieldLabel(label: 'Price per session'),
                if (derivedPrice != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _priceTouched = false;
                        _priceCtrl.text = derivedPrice.toInt().toString();
                        _priceCtrl.selection = TextSelection.collapsed(
                            offset: _priceCtrl.text.length);
                      });
                    },
                    child: Text(
                      'Auto: Rs. ${derivedPrice.toInt()}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                _priceTouched = true;
                setState(() {}); // refresh canSave
              },
              decoration: InputDecoration(
                hintText: 'e.g. 1200',
                prefixText: 'Rs. ',
                prefixIcon: Icon(Icons.payments_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                helperText: 'Applies to this regular only. '
                    'Tap "Auto" to reset to the slot rate.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 22),

            // Start date
            const _FieldLabel(label: 'Starting from'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                      _formatDate(_startDate),
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
            const SizedBox(height: 18),

            // Notes (optional)
            const _FieldLabel(label: 'Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Friday league team',
              ),
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  disabledBackgroundColor:
                      AppColors.brandGreen.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Builder(builder: (_) {
                        final p = double.tryParse(_priceCtrl.text.trim());
                        final label = (p != null &&
                                p > 0 &&
                                _selectedDays.isNotEmpty)
                            ? 'Save · Rs. ${p.toInt()} × ${_selectedDays.length} day${_selectedDays.length == 1 ? '' : 's'}/wk'
                            : 'Save regular';
                        return Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == t) return 'Today · ${d.day} ${months[d.month - 1]} ${d.year}';
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String letter;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.letter,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandGreen
                : cs.surfaceContainerLow,
            border: Border.all(
              color: selected
                  ? AppColors.brandGreen
                  : cs.outlineVariant,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : cs.onSurface,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HourChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandGreen : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brandGreen : cs.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : cs.onSurface,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

