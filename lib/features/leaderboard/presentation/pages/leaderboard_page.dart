import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Mirror the analytics page pattern: sweep past bookings first so
      // any CONFIRMED-but-already-ended games get marked COMPLETED, then
      // force-refresh the leaderboard so it picks up those just-completed
      // games + any new cycle starts from claimed free games.
      try {
        await context.read<BookingProvider>().sweepPastBookings();
      } catch (_) {/* non-fatal */}
      if (!mounted) return;
      context.read<LeaderboardProvider>().fetchLeaderboard(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LeaderboardEntry> _filter(List<LeaderboardEntry> entries) {
    if (_query.isEmpty) return entries;
    final q = _query.toLowerCase();
    return entries.where((e) {
      final name = (e.customerName ?? '').toLowerCase();
      return e.phoneNumber.contains(q) || name.contains(q);
    }).toList();
  }

  Future<void> _editName(LeaderboardEntry entry) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditNameDialog(entry: entry),
    );
    if (newName == null || !mounted) return;
    final provider = context.read<LeaderboardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.setNameOverride(
        phone: entry.phoneNumber,
        name: newName,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Name updated'),
          backgroundColor: AppColors.brandGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _mergePhones(LeaderboardEntry entry) async {
    final result = await showDialog<_MergeResult>(
      context: context,
      builder: (ctx) => _MergePhoneDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final provider = context.read<LeaderboardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await provider.mergePhoneNumbers(
        sourcePhones: result.sources,
        targetPhone: result.target,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? 'No matching records found'
              : 'Merged $count record${count == 1 ? '' : 's'} into +977${result.target}'),
          backgroundColor:
              count == 0 ? Colors.orange : AppColors.brandGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<LeaderboardProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 18, color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Leaderboard',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (provider.state != LeaderboardState.loading)
                          GestureDetector(
                            onTap: provider.refresh,
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Icon(Icons.refresh_rounded,
                                  size: 18, color: cs.onSurface),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Hero card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.heroCardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.brandGreen
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.limeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    const Text(
                                      'ALL TIME',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Top\nBookers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Updated ${provider.lastUpdateDisplay}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '🏆',
                          style: TextStyle(fontSize: 52),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Search ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Search by number or name',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: cs.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: cs.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                if (provider.state == LeaderboardState.loading &&
                    provider.entries.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.state == LeaderboardState.error)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 48, color: cs.error),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load leaderboard',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.errorMessage ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandGreen),
                            onPressed: provider.fetchLeaderboard,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (provider.entries.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 64,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No games played yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Builder(builder: (_) {
                    final filtered = _filter(provider.entries);
                    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                          child: Center(
                            child: Text(
                              'No match for "$_query"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = filtered[index];
                            return _LeaderboardTile(
                              rank: entry.rank,
                              displayName: entry.displayName,
                              phoneNumber: entry.phoneNumber,
                              bookingCount: entry.bookingCount,
                              medalOrRank:
                                  provider.getMedalForRank(entry.rank),
                              isTopThree: entry.rank <= 3,
                              canEdit: isAdmin,
                              onEdit: isAdmin ? () => _mergePhones(entry) : null,
                              onEditName: isAdmin ? () => _editName(entry) : null,
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  }),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String displayName;
  final String phoneNumber;
  final int bookingCount;
  final String medalOrRank;
  final bool isTopThree;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onEditName;

  const _LeaderboardTile({
    required this.rank,
    required this.displayName,
    required this.phoneNumber,
    required this.bookingCount,
    required this.medalOrRank,
    required this.isTopThree,
    this.canEdit = false,
    this.onEdit,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isTopThree
            ? AppColors.brandGreen.withValues(alpha: 0.08)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTopThree
              ? AppColors.brandGreen.withValues(alpha: 0.25)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank / medal
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTopThree
                  ? AppColors.brandGreen.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: isTopThree
                ? Text(medalOrRank, style: const TextStyle(fontSize: 22))
                : Text(
                    medalOrRank,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phoneNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Booking count badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isTopThree
                  ? AppColors.brandGreen.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  size: 14,
                  color: isTopThree
                      ? AppColors.brandGreen
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$bookingCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isTopThree ? AppColors.brandGreen : cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onEditName,
              tooltip: 'Edit name',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.edit_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Merge phones',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.merge_type_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Returned by [_MergePhoneDialog] on confirm. All values are 10-digit
/// normalized phone strings (no `+977` prefix).
class _MergeResult {
  final String target;
  final List<String> sources;
  _MergeResult({required this.target, required this.sources});
}

/// Dialog: admin sets a target phone and adds one or more "other"
/// numbers that should be rewritten to the target. Used to consolidate
/// the same customer's bookings under a single phone so the leaderboard
/// count merges correctly.
class _MergePhoneDialog extends StatefulWidget {
  final LeaderboardEntry entry;
  const _MergePhoneDialog({required this.entry});

  @override
  State<_MergePhoneDialog> createState() => _MergePhoneDialogState();
}

class _MergePhoneDialogState extends State<_MergePhoneDialog> {
  late final TextEditingController _targetCtrl;
  final TextEditingController _sourceCtrl = TextEditingController();
  final List<String> _sources = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetCtrl =
        TextEditingController(text: _to10Digits(widget.entry.phoneNumber));
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  /// Strip non-digits + leading 977 country code → 10-digit form.
  static String _to10Digits(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('977') && d.length > 10) d = d.substring(3);
    return d;
  }

  void _addSource() {
    final d = _to10Digits(_sourceCtrl.text);
    if (d.length != 10) {
      setState(() => _error = 'Enter a 10-digit number');
      return;
    }
    final target = _to10Digits(_targetCtrl.text);
    if (d == target) {
      setState(() => _error = 'Already the target number');
      return;
    }
    if (_sources.contains(d)) {
      setState(() => _error = 'Already added');
      return;
    }
    setState(() {
      _sources.add(d);
      _sourceCtrl.clear();
      _error = null;
    });
  }

  void _submit() {
    final target = _to10Digits(_targetCtrl.text);
    if (target.length != 10) {
      setState(() => _error = 'Target must be 10 digits');
      return;
    }
    if (_sources.isEmpty) {
      setState(() => _error = 'Add at least one number to merge');
      return;
    }
    Navigator.of(context).pop(
      _MergeResult(target: target, sources: List.of(_sources)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;

    return AlertDialog(
      title: const Text('Merge phones'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.customerName != null &&
                  entry.customerName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.customerName!,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                'Currently: ${entry.phoneNumber}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              // ── Target ──────────────────────────────────────────
              TextField(
                controller: _targetCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+\s-]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: const InputDecoration(
                  labelText: 'Keep this number',
                  helperText: 'All others will be rewritten to this',
                  prefixText: '+977 ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              // ── Sources to merge in ─────────────────────────────
              Text(
                'Merge these in (add one at a time):',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sourceCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d+\s-]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Other number',
                        hintText: '98XXXXXXXX',
                        errorText: _error,
                        prefixText: '+977 ',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addSource(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addSource,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.add_rounded,
                        color: Colors.white),
                  ),
                ],
              ),
              if (_sources.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _sources)
                      Chip(
                        label: Text('+977 $s'),
                        onDeleted: () =>
                            setState(() => _sources.remove(s)),
                        backgroundColor:
                            AppColors.brandGreen.withValues(alpha: 0.12),
                        side: BorderSide(
                            color: AppColors.brandGreen
                                .withValues(alpha: 0.4)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Every booking, regular, and plan with any of these numbers will be rewritten to the target.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandGreen),
          onPressed: _submit,
          child: Text(_sources.isEmpty
              ? 'Merge'
              : 'Merge ${_sources.length}'),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final LeaderboardEntry entry;
  const _EditNameDialog({required this.entry});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.customerName ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Edit display name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.entry.phoneNumber,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandGreen),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}
