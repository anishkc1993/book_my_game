import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/concession_item_entity.dart';
import '../../domain/entities/concession_sale_entity.dart';
import '../providers/concession_provider.dart';

class ConcessionsPage extends StatefulWidget {
  const ConcessionsPage({super.key});

  @override
  State<ConcessionsPage> createState() => _ConcessionsPageState();
}

class _ConcessionsPageState extends State<ConcessionsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConcessionProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// One-tap record at qty=1, default price. Long-press opens the full
  /// sheet for custom qty/amount. Undo SnackBar gives admin a way out
  /// if they fat-finger an item.
  Future<void> _quickRecord(ConcessionItemEntity item) async {
    final provider = context.read<ConcessionProvider>();
    final auth = context.read<AuthProvider>();
    final ok = await provider.quickSale(
      item: item,
      markedBy: auth.user?.uid ?? 'admin',
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to record sale'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final lastSale = provider.sales.firstOrNull;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('1 × ${item.name} · Rs. ${item.defaultPrice.toInt()}'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: lastSale == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () => provider.deleteSale(lastSale),
            ),
    ));
  }

  Future<void> _openRecordSheet([ConcessionItemEntity? preselect]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecordSaleSheet(preselect: preselect),
    );
  }

  Future<void> _openEditSheet(ConcessionSaleEntity sale) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecordSaleSheet(editing: sale),
    );
  }

  Future<void> _openItemEditor([ConcessionItemEntity? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ItemEditorSheet(existing: existing),
    );
  }

  Future<void> _confirmDeleteSale(ConcessionSaleEntity sale) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
          '${sale.quantity} × ${sale.itemName} · '
          'Rs. ${sale.amount.toInt()}\n\nThis cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ConcessionProvider>().deleteSale(sale);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Consumer<ConcessionProvider>(
          builder: (context, provider, _) {
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cafe',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Water, tea, soft drinks',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Icon-only header actions — stay roomy on narrow
                          // phones; tooltips clarify each.
                          IconButton(
                            onPressed: () =>
                                context.push(RoutePaths.concessionCollections),
                            tooltip: 'Collections',
                            icon: const Icon(Icons.insights_rounded),
                          ),
                          IconButton(
                            onPressed: () => _openItemEditor(null),
                            tooltip: 'Manage items',
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Today's collection card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1F3712),
                              Color(0xFF2C4E1A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.limeAccent
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.local_cafe_rounded,
                                color: AppColors.limeAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Today's collection",
                                    style: TextStyle(
                                      color: Color(0xFF9FBA8B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${provider.todayTotal.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 26,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (provider.todayExpense > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Expense Rs. ${provider.todayExpense.toInt()} · '
                                      'Net Rs. ${provider.todayNet.toInt()}',
                                      style: TextStyle(
                                        color: provider.todayNet >= 0
                                            ? const Color(0xFF9FBA8B)
                                            : const Color(0xFFE05757),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Expenses entry — sub-section button taking admin to
                  // the dedicated expense ledger.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: InkWell(
                        onTap: () =>
                            context.push(RoutePaths.concessionExpenses),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE05757)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFFE05757),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cafe expenses',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      'This month: Rs. ${provider.monthExpense.toInt()} · '
                                      'Week: Rs. ${provider.weekExpense.toInt()}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Quick-add item chips. Search + popularity ordering
                  // becomes important as the catalog grows past a
                  // handful of items.
                  if (provider.activeItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Quick record',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                Text(
                                  '· tap = sell 1, hold for custom',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Search — instant filter over the chip list.
                            TextField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                              decoration: InputDecoration(
                                hintText: 'Search items',
                                prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.clear_rounded, size: 16),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _query = '');
                                        },
                                      ),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Builder(builder: (_) {
                              final q = _query.toLowerCase();
                              final filtered = q.isEmpty
                                  ? provider.popularItems
                                  : provider.popularItems
                                      .where((it) => it.name
                                          .toLowerCase()
                                          .contains(q))
                                      .toList();
                              if (filtered.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: Text(
                                    'No items match "$_query"',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: cs.onSurfaceVariant),
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final item in filtered)
                                    InkWell(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      onTap: () => _quickRecord(item),
                                      onLongPress: () =>
                                          _openRecordSheet(item),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHigh,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: cs.outlineVariant),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_rounded,
                                                size: 14,
                                                color:
                                                    AppColors.brandGreen),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.name,
                                              style: theme.textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Rs. ${item.defaultPrice.toInt()}',
                                              style: theme.textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  // Recent sales header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Text('Recent sales',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(width: 8),
                          Text(
                            '· ${provider.sales.length}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.state == ConcessionState.loading &&
                      provider.sales.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.sales.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        onRecord: () => _openRecordSheet(null),
                        hasItems: provider.activeItems.isNotEmpty,
                        onAddItem: () => _openItemEditor(null),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemBuilder: (_, i) => _SaleRow(
                          sale: provider.sales[i],
                          onDelete: () =>
                              _confirmDeleteSale(provider.sales[i]),
                          onEdit: () => _openEditSheet(provider.sales[i]),
                        ),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemCount: provider.sales.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecordSheet(null),
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record sale'),
      ),
    );
  }
}

// ─── Sale row ────────────────────────────────────────────────────────────────

class _SaleRow extends StatelessWidget {
  final ConcessionSaleEntity sale;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _SaleRow({
    required this.sale,
    required this.onDelete,
    required this.onEdit,
  });

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${sale.quantity}',
              style: const TextStyle(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.itemName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _timeAgo(sale.soldAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs. ${sale.amount.toInt()}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.brandGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close_rounded,
                size: 18, color: cs.onSurfaceVariant),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final VoidCallback onRecord;
  final VoidCallback onAddItem;
  final bool hasItems;
  const _Empty({
    required this.onRecord,
    required this.onAddItem,
    required this.hasItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 80),
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
              ),
            ),
            child: const Icon(Icons.local_cafe_outlined,
                color: AppColors.brandGreen, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            hasItems ? 'No sales yet' : 'Start your cafe',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            hasItems
                ? 'Tap a quick-record chip above or use the Record sale button.'
                : 'Add items like drinking water, tea, soft drinks — then record sales as customers buy them.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: hasItems ? onRecord : onAddItem,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(hasItems ? 'Record first sale' : 'Add first item'),
          ),
        ],
      ),
    );
  }
}

// ─── Record sale sheet ───────────────────────────────────────────────────────

class _RecordSaleSheet extends StatefulWidget {
  final ConcessionItemEntity? preselect;
  /// If set, the sheet runs in edit mode and updates this sale instead of
  /// recording a new one.
  final ConcessionSaleEntity? editing;
  const _RecordSaleSheet({this.preselect, this.editing});

  @override
  State<_RecordSaleSheet> createState() => _RecordSaleSheetState();
}

class _RecordSaleSheetState extends State<_RecordSaleSheet> {
  ConcessionItemEntity? _picked;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  bool _amountTouched = false;
  bool _submitting = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _qtyCtrl = TextEditingController(
        text: editing?.quantity.toString() ?? '1');
    _amountCtrl = TextEditingController(
        text: editing != null ? editing.amount.toInt().toString() : '');
    _notesCtrl = TextEditingController(text: editing?.notes ?? '');
    _picked = widget.preselect;
    if (editing != null) {
      // Editing: try to resolve the originally-picked catalog item by id.
      // If the item was deleted or unknown, leave _picked null and fall
      // back to displaying the denormalized itemName.
      _amountTouched = true; // don't auto-recompute from default price.
      final items = context.read<ConcessionProvider>().activeItems;
      ConcessionItemEntity? match;
      for (final it in items) {
        if (it.id == editing.itemId) {
          match = it;
          break;
        }
      }
      _picked = match;
    }
    _refreshAmountFromDefault();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Pre-fill amount = qty × item.defaultPrice when admin hasn't typed
  /// a custom value yet.
  void _refreshAmountFromDefault() {
    if (_amountTouched) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final unit = _picked?.defaultPrice ?? 0;
    final total = qty * unit;
    if (total > 0) {
      _amountCtrl.text = total.toInt().toString();
    }
  }

  bool get _canSave {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final hasName = _picked != null ||
        (widget.editing?.itemName.isNotEmpty ?? false);
    // 0 amount is allowed (complimentary / free item).
    return hasName && qty > 0 && amount >= 0 && !_submitting;
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (qty <= 0 || amount < 0) return;

    final editing = widget.editing;
    // Edit mode: catalog item may have been deleted since — fall back to
    // the denormalized itemName from the original sale.
    final itemName = _picked?.name ?? editing?.itemName ?? '';
    if (itemName.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<ConcessionProvider>();
    setState(() => _submitting = true);
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final bool ok;
    if (_isEditing) {
      ok = await provider.updateSale(
        original: editing!,
        item: _picked,
        itemName: itemName,
        quantity: qty,
        amount: amount,
        notes: notes,
      );
    } else {
      if (_picked == null) {
        setState(() => _submitting = false);
        return;
      }
      ok = await provider.recordSale(
        item: _picked,
        itemName: _picked!.name,
        quantity: qty,
        amount: amount,
        notes: notes,
        markedBy: auth.user?.uid ?? 'admin',
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isEditing
              ? 'Updated: $qty × $itemName · Rs. ${amount.toInt()}'
              : '$qty × $itemName · Rs. ${amount.toInt()} recorded',
        ),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ??
            (_isEditing ? 'Failed to update sale' : 'Failed to record sale')),
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isEditing ? 'Edit sale' : 'Record a sale',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _Label('Item'),
            const SizedBox(height: 8),
            Consumer<ConcessionProvider>(
              builder: (context, provider, _) {
                final items = provider.activeItems;
                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      'No items yet — tap "Manage" on the previous screen to add Drinking Water, Tea, Soft Drink, etc.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      ChoiceChip(
                        label: Text(
                            '${item.name} · Rs. ${item.defaultPrice.toInt()}'),
                        selected: _picked?.id == item.id,
                        onSelected: (_) {
                          setState(() {
                            _picked = item;
                            _amountTouched = false;
                            _refreshAmountFromDefault();
                          });
                        },
                        selectedColor: AppColors.brandGreen,
                        labelStyle: TextStyle(
                          color: _picked?.id == item.id
                              ? Colors.white
                              : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Quantity'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) {
                          _refreshAmountFromDefault();
                          setState(() {});
                        },
                        decoration: const InputDecoration(hintText: 'e.g. 5'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Amount (Rs.)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) {
                          _amountTouched = true;
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                            hintText: 'e.g. 100', prefixText: 'Rs. '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Label('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 1,
              decoration: const InputDecoration(
                hintText: 'e.g. Cash · paid by Anup',
              ),
            ),
            const SizedBox(height: 22),
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
                    : Text(_isEditing ? 'Save changes' : 'Record sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item editor sheet (catalog management) ──────────────────────────────────

class _ItemEditorSheet extends StatelessWidget {
  final ConcessionItemEntity? existing;
  const _ItemEditorSheet({this.existing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Consumer<ConcessionProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Manage items',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Catalog of items you sell. Disabled items hide from quick record but their past sales stay in the log.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                _AddItemForm(),
                const SizedBox(height: 18),
                if (provider.items.isNotEmpty) ...[
                  Text(
                    '${provider.items.length} item${provider.items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in provider.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ItemTile(item: item),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddItemForm extends StatefulWidget {
  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(name.isEmpty
            ? 'Enter an item name'
            : 'Enter a valid price (Rs.)'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final auth = context.read<AuthProvider>();
    final provider = context.read<ConcessionProvider>();
    setState(() => _saving = true);
    final ok = await provider.saveItem(ConcessionItemEntity(
      name: name,
      defaultPrice: price,
      createdByAdmin: auth.user?.uid,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _nameCtrl.clear();
      _priceCtrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added "$name"'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Failed to add item: ${provider.error ?? "unknown error"}'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Drinking Water',
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Price (Rs.)',
              prefixText: 'Rs. ',
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(46, 48),
              padding: EdgeInsets.zero,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ConcessionItemEntity item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.isActive
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Rs. ${item.defaultPrice.toInt()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'DISABLED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          if (item.isActive)
            IconButton(
              onPressed: () {
                if (item.id != null) {
                  context.read<ConcessionProvider>().deleteItem(item.id!);
                }
              },
              icon: Icon(Icons.visibility_off_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              tooltip: 'Hide from quick record',
            ),
        ],
      ),
    );
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
      style: theme.textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
    );
  }
}

