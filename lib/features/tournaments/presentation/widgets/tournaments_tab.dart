import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/tournament_entity.dart';
import '../providers/tournament_provider.dart';

/// Tournaments tab — embedded inside the Regulars page so admins manage
/// recurring + one-off tournament bookings from a single screen.
class TournamentsTab extends StatefulWidget {
  const TournamentsTab({super.key});

  @override
  State<TournamentsTab> createState() => _TournamentsTabState();
}

class _TournamentsTabState extends State<TournamentsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TournamentProvider>().load();
    });
  }

  Future<void> _openEditor(TournamentEntity? existing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TournamentEditorSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(TournamentEntity t) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel tournament?'),
        content: Text(
          '${t.name}\n${t.datesSummary} · ${t.timeRange}\n\n'
          'Those slots will free up immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || t.id == null || !mounted) return;
    final ok = await context.read<TournamentProvider>().delete(t.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Tournament cancelled' : 'Failed to cancel'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _markPaid(TournamentEntity t) async {
    if (t.id == null) return;
    final auth = context.read<AuthProvider>();
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _MarkPaidDialog(tournament: t),
    );
    if (result == null || !mounted) return;
    final ok = await context.read<TournamentProvider>().markPaid(
          tournamentId: t.id!,
          amount: result,
          markedBy: auth.user?.uid ?? 'admin',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Tournament marked paid' : 'Failed to mark paid'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<TournamentProvider>(
      builder: (context, provider, _) {
        final tournaments = provider.tournaments;
        return RefreshIndicator(
          onRefresh: provider.load,
          color: AppColors.brandGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tournaments.length} tournament${tournaments.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openEditor(null),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
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
              if (provider.state == TournamentState.loading &&
                  tournaments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tournaments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(onAdd: () => _openEditor(null)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: tournaments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TournamentCard(
                      tournament: tournaments[i],
                      onEdit: () => _openEditor(tournaments[i]),
                      onMarkPaid: () => _markPaid(tournaments[i]),
                      onDelete: () => _confirmDelete(tournaments[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

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
            child: const Icon(Icons.emoji_events_outlined,
                color: AppColors.brandGreen, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'No tournaments scheduled',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Block a date range for a tournament — overlapping bookings '
            'on that day will hide while it runs.',
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
            label: const Text('Add tournament'),
          ),
        ],
      ),
    );
  }
}

// ─── Tournament card ─────────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final TournamentEntity tournament;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;
  const _TournamentCard({
    required this.tournament,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paid = tournament.isPaid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — name + paid pill
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07820).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        size: 14, color: Color(0xFFE07820)),
                    SizedBox(width: 4),
                    Text('TOURNAMENT',
                        style: TextStyle(
                          color: Color(0xFFE07820),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        )),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paid
                      ? cs.secondaryContainer
                      : cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paid ? 'PAID' : 'UNPAID',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: paid
                        ? cs.onSecondaryContainer
                        : cs.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tournament.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${tournament.organizerName} · ${tournament.organizerPhone}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_outlined,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tournament.datesSummary,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.schedule_rounded,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                tournament.timeRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 10),
          // Row: amount + day/hour subtitle (subtitle ellipsizes on narrow widths)
          Row(
            children: [
              Text(
                'Rs. ${tournament.totalAmount.toInt()}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '· ${tournament.dates.length} day${tournament.dates.length == 1 ? '' : 's'} · '
                  '${tournament.totalHours} hr/day',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Action row — right-aligned, fits without overflow.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _CardAction(
                icon: Icons.payments_outlined,
                label: paid ? 'Paid ✓' : 'Mark paid',
                color: AppColors.brandGreen,
                onTap: onMarkPaid,
              ),
              const SizedBox(width: 4),
              _CardAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: cs.onSurfaceVariant,
                onTap: onEdit,
              ),
              const SizedBox(width: 4),
              _CardAction(
                icon: Icons.delete_outline_rounded,
                label: 'Cancel',
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

// ─── Editor sheet ────────────────────────────────────────────────────────────

class _TournamentEditorSheet extends StatefulWidget {
  final TournamentEntity? existing;
  const _TournamentEditorSheet({this.existing});

  @override
  State<_TournamentEditorSheet> createState() =>
      _TournamentEditorSheetState();
}

class _TournamentEditorSheetState extends State<_TournamentEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _organizerNameCtrl;
  late final TextEditingController _organizerPhoneCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late List<DateTime> _dates;
  int _startHour = AppConstants.slotStartHour;
  int _endHour = AppConstants.slotEndHour;
  String? _nameError;
  String? _phoneError;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _organizerNameCtrl =
        TextEditingController(text: e?.organizerName ?? '');
    final phoneStripped = e?.organizerPhone
            .replaceFirst(RegExp(r'^\+?977'), '')
            .replaceAll(RegExp(r'\D'), '') ??
        '';
    _organizerPhoneCtrl = TextEditingController(text: phoneStripped);
    _amountCtrl = TextEditingController(
        text: e?.totalAmount != null && e!.totalAmount > 0
            ? e.totalAmount.toInt().toString()
            : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _dates = [...?e?.dates];
    if (e != null) {
      _startHour = e.startHour;
      _endHour = e.endHour;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _organizerNameCtrl.dispose();
    _organizerPhoneCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final amt = double.tryParse(_amountCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
        _organizerNameCtrl.text.trim().isNotEmpty &&
        _organizerPhoneCtrl.text.trim().length == 10 &&
        _dates.isNotEmpty &&
        _endHour > _startHour &&
        amt != null &&
        amt > 0 &&
        !_submitting;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    if (_dates.any((d) =>
        d.year == day.year && d.month == day.month && d.day == day.day)) {
      return;
    }
    setState(() => _dates = [..._dates, day]..sort());
  }

  void _removeDate(DateTime d) {
    setState(() {
      _dates.removeWhere((x) =>
          x.year == d.year && x.month == d.month && x.day == d.day);
    });
  }

  Future<void> _save() async {
    final nameErr =
        _nameCtrl.text.trim().isEmpty ? 'Tournament name required' : null;
    final phoneErr =
        Validators.validatePhoneNumber(_organizerPhoneCtrl.text);
    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
    });
    if (nameErr != null || phoneErr != null) return;
    if (_dates.isEmpty) return;
    if (_endHour <= _startHour) return;
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;

    final adminId = context.read<AuthProvider>().user?.uid ?? '';
    final provider = context.read<TournamentProvider>();
    setState(() => _submitting = true);
    final phone = Validators.formatPhoneNumber(
      _organizerPhoneCtrl.text,
      countryCode: AppConstants.defaultCountryCode,
    );
    final entity = (widget.existing ??
            TournamentEntity(
              name: '',
              organizerName: '',
              organizerPhone: '',
              dates: const [],
              startHour: 0,
              endHour: 0,
              totalAmount: 0,
              createdByAdmin: adminId,
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      organizerName: _organizerNameCtrl.text.trim(),
      organizerPhone: phone,
      dates: _dates,
      startHour: _startHour,
      endHour: _endHour,
      totalAmount: amt,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    final ok = await provider.save(entity);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(_isEdit ? 'Tournament updated' : 'Tournament added'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to save'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
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
                        _isEdit ? 'Edit tournament' : 'New tournament',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Blocks all bookings inside the time window',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
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
            _Label('Tournament name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) =>
                  setState(() => _nameError = null),
              decoration: InputDecoration(
                hintText: 'e.g. Friday Night Cup',
                errorText: _nameError,
                prefixIcon: Icon(Icons.emoji_events_outlined,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 18),
            _Label('Organizer name'),
            const SizedBox(height: 8),
            TextField(
              controller: _organizerNameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Contact person',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 18),
            _Label('Organizer phone'),
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
                    controller: _organizerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (_) => setState(() => _phoneError = null),
                    decoration: InputDecoration(
                      hintText: '98XX XXXXXX',
                      errorText: _phoneError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _Label('Tournament dates'),
                const Spacer(),
                Text(
                  _dates.isEmpty
                      ? 'Add at least one'
                      : '${_dates.length} day${_dates.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_dates.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _dates)
                    InputChip(
                      label: Text(_dateChip(d)),
                      onDeleted: () => _removeDate(d),
                      backgroundColor:
                          AppColors.brandGreen.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add date'),
            ),
            const SizedBox(height: 22),
            _Label('Time window'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _HourField(
                    label: 'Start',
                    hour: _startHour,
                    onChanged: (h) => setState(() {
                      _startHour = h;
                      if (_endHour <= _startHour) {
                        _endHour = (_startHour + 1)
                            .clamp(0, AppConstants.slotEndHour);
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HourField(
                    label: 'End',
                    hour: _endHour,
                    minHour: _startHour + 1,
                    onChanged: (h) => setState(() => _endHour = h),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Label('Total amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. 25000',
                prefixText: 'Rs. ',
                prefixIcon: Icon(Icons.payments_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                helperText:
                    'Lump-sum for the whole tournament. Counts as revenue when marked paid.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 22),
            _Label('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Payment via eSewa, 50% deposit received',
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
                    : Text(_isEdit ? 'Save changes' : 'Add tournament'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateChip(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wkd[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _HourField extends StatelessWidget {
  final String label;
  final int hour;
  final int minHour;
  final ValueChanged<int> onChanged;
  const _HourField({
    required this.label,
    required this.hour,
    required this.onChanged,
    this.minHour = 0,
  });

  String _fmt(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hours = <int>[
      for (var h = minHour; h <= AppConstants.slotEndHour; h++) h,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: hour.clamp(minHour, AppConstants.slotEndHour),
              isExpanded: true,
              items: [
                for (final h in hours)
                  DropdownMenuItem(
                    value: h,
                    child: Text(_fmt(h)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mark paid dialog ────────────────────────────────────────────────────────

class _MarkPaidDialog extends StatefulWidget {
  final TournamentEntity tournament;
  const _MarkPaidDialog({required this.tournament});

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.tournament.totalAmount.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark ${widget.tournament.name} paid'),
      content: TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Amount received (Rs.)',
          prefixText: 'Rs. ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amountCtrl.text);
            if (amt == null || amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid amount'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            Navigator.pop(context, amt);
          },
          child: const Text('Mark paid'),
        ),
      ],
    );
  }
}
