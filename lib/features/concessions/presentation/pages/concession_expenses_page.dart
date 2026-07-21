import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/concession_expense_entity.dart';
import '../../domain/entities/concession_sale_entity.dart';
import '../providers/concession_provider.dart';
import 'concessions_page.dart' show ConcessionRecordSaleSheet;

/// Combined cafe ledger — sales (income) and expenses (cost) in one view,
/// grouped by month. Admin can add both sales and expenses from here.
class ConcessionExpensesPage extends StatefulWidget {
  const ConcessionExpensesPage({super.key});

  @override
  State<ConcessionExpensesPage> createState() =>
      _ConcessionExpensesPageState();
}

class _ConcessionExpensesPageState extends State<ConcessionExpensesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConcessionProvider>().loadLedger();
    });
  }

  Future<void> _openAddSale() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const ConcessionRecordSaleSheet(),
    );
  }

  Future<void> _openAddExpense() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _AddExpenseSheet(),
    );
  }

  Future<void> _confirmDeleteExpense(ConcessionExpenseEntity e) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e.itemName} · Rs. ${e.amount.toInt()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<ConcessionProvider>().deleteExpense(e);
  }

  Future<void> _confirmDeleteSale(ConcessionSaleEntity s) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text('${s.quantity}× ${s.itemName} · Rs. ${s.amount.toInt()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<ConcessionProvider>().deleteSale(s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<ConcessionProvider>(
          builder: (context, provider, _) {
            final sales = provider.ledgerSales;
            final expenses = provider.ledgerExpenses;
            final totalSales =
                sales.fold<double>(0, (s, e) => s + e.amount);
            final totalExpenses =
                expenses.fold<double>(0, (s, e) => s + e.amount);
            final net = totalSales - totalExpenses;

            return RefreshIndicator(
              color: AppColors.brandGreen,
              onRefresh: provider.loadLedger,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                                  'Cafe ledger',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Sales & expenses — all time',
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
                  ),

                  // Summary cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: 'TOTAL SALES',
                              value: totalSales.toInt(),
                              color: AppColors.brandGreen,
                              icon: Icons.arrow_upward_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryCard(
                              label: 'TOTAL EXPENSES',
                              value: totalExpenses.toInt(),
                              color: const Color(0xFFE05757),
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryCard(
                              label: 'NET',
                              value: net.toInt(),
                              color: net >= 0
                                  ? AppColors.brandGreen
                                  : const Color(0xFFE05757),
                              icon: net >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openAddSale,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add sale'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brandGreen,
                                side: BorderSide(
                                    color: AppColors.brandGreen
                                        .withValues(alpha: 0.6)),
                                minimumSize: const Size(0, 42),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openAddExpense,
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              label: const Text('Add expense'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE05757),
                                side: const BorderSide(
                                    color: Color(0xFFE05757)),
                                minimumSize: const Size(0, 42),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Monthly breakdown header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                      child: Text(
                        'Monthly breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  if (provider.state == ConcessionState.loading &&
                      sales.isEmpty &&
                      expenses.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (sales.isEmpty && expenses.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Text(
                          'No records yet.\nUse the buttons above to add sales or expenses.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _buildMonthGroups(
                              context, sales, expenses, theme, cs),
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

  List<Widget> _buildMonthGroups(
    BuildContext context,
    List<ConcessionSaleEntity> sales,
    List<ConcessionExpenseEntity> expenses,
    ThemeData theme,
    ColorScheme cs,
  ) {
    // Collect all unique month keys from both lists.
    final monthKeys = <String>{};
    for (final s in sales) {
      monthKeys.add(
          '${s.soldAt.year}-${s.soldAt.month.toString().padLeft(2, '0')}');
    }
    for (final e in expenses) {
      monthKeys.add(
          '${e.spentAt.year}-${e.spentAt.month.toString().padLeft(2, '0')}');
    }
    final sortedKeys = monthKeys.toList()..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final currentKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return [
      for (int i = 0; i < sortedKeys.length; i++) ...[
        _MonthLedgerGroup(
          key: ValueKey(sortedKeys[i]),
          monthKey: sortedKeys[i],
          sales: sales
              .where((s) =>
                  '${s.soldAt.year}-${s.soldAt.month.toString().padLeft(2, '0')}' ==
                  sortedKeys[i])
              .toList(),
          expenses: expenses
              .where((e) =>
                  '${e.spentAt.year}-${e.spentAt.month.toString().padLeft(2, '0')}' ==
                  sortedKeys[i])
              .toList(),
          isCurrentMonth: sortedKeys[i] == currentKey,
          initiallyExpanded: i == 0,
          onDeleteSale: _confirmDeleteSale,
          onDeleteExpense: _confirmDeleteExpense,
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${value.abs()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Monthly ledger group ──────────────────────────────────────────────────────

class _MonthLedgerGroup extends StatefulWidget {
  final String monthKey;
  final List<ConcessionSaleEntity> sales;
  final List<ConcessionExpenseEntity> expenses;
  final bool isCurrentMonth;
  final bool initiallyExpanded;
  final Future<void> Function(ConcessionSaleEntity) onDeleteSale;
  final Future<void> Function(ConcessionExpenseEntity) onDeleteExpense;

  const _MonthLedgerGroup({
    super.key,
    required this.monthKey,
    required this.sales,
    required this.expenses,
    required this.isCurrentMonth,
    required this.initiallyExpanded,
    required this.onDeleteSale,
    required this.onDeleteExpense,
  });

  @override
  State<_MonthLedgerGroup> createState() => _MonthLedgerGroupState();
}

class _MonthLedgerGroupState extends State<_MonthLedgerGroup> {
  late bool _expanded;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  String _fmtDate(DateTime t) =>
      '${_wkd[t.weekday - 1]}, ${t.day} · '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parts = widget.monthKey.split('-');
    final month = int.parse(parts[1]);
    final year = int.parse(parts[0]);
    final monthLabel = _monthNames[month - 1];

    final totalSales =
        widget.sales.fold<double>(0, (s, e) => s + e.amount);
    final totalExpenses =
        widget.expenses.fold<double>(0, (s, e) => s + e.amount);
    final net = totalSales - totalExpenses;

    final sortedSales = [...widget.sales]
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    final sortedExpenses = [...widget.expenses]
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Month header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCurrentMonth
                              ? '$monthLabel $year · this month'
                              : '$monthLabel $year',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '+Rs. ${totalSales.toInt()}',
                              style: const TextStyle(
                                color: AppColors.brandGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '−Rs. ${totalExpenses.toInt()}',
                              style: const TextStyle(
                                color: Color(0xFFE05757),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Net: Rs. ${net.toInt()}',
                              style: TextStyle(
                                color: net >= 0
                                    ? AppColors.brandGreen
                                    : const Color(0xFFE05757),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sales sub-tile ───────────────────────────────────
                  Expanded(
                    child: _SubTile(
                      label: 'SALES',
                      total: '+Rs. ${totalSales.toInt()}',
                      totalColor: AppColors.brandGreen,
                      color: AppColors.brandGreen,
                      emptyText: 'No sales',
                      items: sortedSales.map((s) => _SubItem(
                        qty: s.quantity,
                        name: s.itemName,
                        date: _fmtDate(s.soldAt),
                        amount: '+Rs. ${s.amount.toInt()}',
                        onDelete: () => widget.onDeleteSale(s),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Expenses sub-tile ────────────────────────────────
                  Expanded(
                    child: _SubTile(
                      label: 'EXPENSES',
                      total: '−Rs. ${totalExpenses.toInt()}',
                      totalColor: const Color(0xFFE05757),
                      color: const Color(0xFFE05757),
                      emptyText: 'No expenses',
                      items: sortedExpenses.map((e) => _SubItem(
                        qty: e.quantity,
                        name: e.itemName,
                        date: _fmtDate(e.spentAt),
                        amount: '−Rs. ${e.amount.toInt()}',
                        onDelete: () => widget.onDeleteExpense(e),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-tile data ─────────────────────────────────────────────────────────────

class _SubItem {
  final int qty;
  final String name;
  final String date;
  final String amount;
  final VoidCallback onDelete;
  const _SubItem({
    required this.qty,
    required this.name,
    required this.date,
    required this.amount,
    required this.onDelete,
  });
}

class _SubTile extends StatelessWidget {
  final String label;
  final String total;
  final Color totalColor;
  final Color color;
  final String emptyText;
  final List<_SubItem> items;

  const _SubTile({
    required this.label,
    required this.total,
    required this.totalColor,
    required this.color,
    required this.emptyText,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tile header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  total,
                  style: TextStyle(
                    color: totalColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withValues(alpha: 0.2)),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                emptyText,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            ...items.map((item) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.qty}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.date,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item.amount,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          GestureDetector(
                            onTap: item.onDelete,
                            child: Icon(Icons.close_rounded,
                                size: 14, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (item != items.last)
                      Divider(
                        height: 1,
                        indent: 8,
                        endIndent: 8,
                        color: color.withValues(alpha: 0.15),
                      ),
                  ],
                )),
        ],
      ),
    );
  }
}

// ── Add expense sheet ─────────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return name.isNotEmpty && qty > 0 && amount >= 0 && !_submitting;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty <= 0 || amount < 0) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<ConcessionProvider>();
    setState(() => _submitting = true);
    final ok = await provider.recordExpense(
      itemName: name,
      quantity: qty,
      amount: amount,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      markedBy: auth.user?.uid ?? 'admin',
      date: _date,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Expense recorded · Rs. ${amount.toInt()}'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to record expense'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
              'Add expense',
              style:
                  theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item / purpose',
                hintText: 'e.g. Cold drinks, Tea leaves, Plates',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total amount',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(
                      isToday
                          ? 'Today · ${_date.day}/${_date.month}/${_date.year}'
                          : '${_date.day}/${_date.month}/${_date.year}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE05757),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
