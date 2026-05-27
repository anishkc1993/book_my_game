import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_calendar.dart';
import '../widgets/time_slot_grid.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookingProvider>();
      provider.fetchSlotConfig();
      provider.selectDate(DateTime.now());
    });
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final sel = DateTime(date.year, date.month, date.day);
    if (sel == today) return 'Today';
    if (sel == tomorrow) return 'Tomorrow';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, _) {
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // App bar
                  SliverToBoxAdapter(
                    child: SafeArea(
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
                            Text(
                              'Book a slot',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Date strip
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: BookingCalendar(
                        selectedDate: bookingProvider.selectedDate,
                        onDateSelected: (date) => bookingProvider.selectDate(date),
                      ),
                    ),
                  ),

                  // Slots section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Available slots',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Text(
                              _getDateLabel(bookingProvider.selectedDate),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Slots grid
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: bookingProvider.state == BookingState.loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : bookingProvider.state == BookingState.error
                              ? _ErrorState(
                                  message: bookingProvider.errorMessage,
                                  onRetry: bookingProvider.fetchSlotsForSelectedDate,
                                )
                              : TimeSlotGrid(
                                  slots: bookingProvider.slots,
                                  selectedSlot: bookingProvider.selectedSlot,
                                  slotConfig: bookingProvider.slotConfig,
                                  onSlotSelected: (slot) =>
                                      bookingProvider.selectSlot(slot),
                                ),
                    ),
                  ),

                  // Bottom spacing for the reserve button
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Sticky bottom reserve button
              if (bookingProvider.selectedSlot != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ReserveBar(
                    slot: bookingProvider.selectedSlot!,
                    slotConfig: bookingProvider.slotConfig,
                    dateLabel: _getDateLabel(bookingProvider.selectedDate),
                    onReserve: () => _showConfirmSheet(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showConfirmSheet(BuildContext context) async {
    final bookingProvider = context.read<BookingProvider>();
    final authProvider = context.read<AuthProvider>();
    final slot = bookingProvider.selectedSlot!;
    final price = bookingProvider.slotConfig?.getPriceForHour(slot.startTime.hour);
    final remarksController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmSheet(
        slot: slot,
        price: price,
        dateLabel: _getDateLabel(bookingProvider.selectedDate),
        remarksController: remarksController,
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = authProvider.user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book')),
        );
        remarksController.dispose();
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final success = await bookingProvider.createBooking(
        userId: user.uid,
        userPhone: user.phoneNumber ?? '',
        remarks: remarksController.text.trim().isEmpty
            ? null
            : remarksController.text.trim(),
      );

      if (context.mounted) {
        Navigator.pop(context);
        if (success) {
          _showSuccessSheet(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  bookingProvider.errorMessage ?? 'Booking failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }

    remarksController.dispose();
  }

  Future<void> _showSuccessSheet(BuildContext context) async {
    final bookingProvider = context.read<BookingProvider>();
    final booking = bookingProvider.lastBooking;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.brandGreen, size: 38),
              ),
              const SizedBox(height: 20),
              Text(
                "You're on the pitch.",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Booking confirmed. See you on the field.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (booking != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _confirmRow(theme, cs, 'Time', booking.timeRange),
                      if (booking.basePrice != null) ...[
                        Divider(
                            height: 20,
                            color: cs.outlineVariant.withValues(alpha: 0.5)),
                        _confirmRow(theme, cs, 'Amount',
                            'Rs. ${booking.basePrice!.toInt()}'),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _confirmRow(
      ThemeData theme, ColorScheme cs, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Reserve bar ────────────────────────────────────────────────────────────────

class _ReserveBar extends StatelessWidget {
  final dynamic slot;
  final dynamic slotConfig;
  final String dateLabel;
  final VoidCallback onReserve;

  const _ReserveBar({
    required this.slot,
    required this.slotConfig,
    required this.dateLabel,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final price = slotConfig?.getPriceForHour(slot.startTime.hour);

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.timeRange,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: onReserve,
            child: Text(
              price != null ? 'Reserve  Rs. ${price.toInt()}' : 'Reserve',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm bottom sheet ───────────────────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  final dynamic slot;
  final double? price;
  final String dateLabel;
  final TextEditingController remarksController;

  const _ConfirmSheet({
    required this.slot,
    required this.price,
    required this.dateLabel,
    required this.remarksController,
  });

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm booking',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  _row(theme, cs, Icons.access_time_rounded, 'Slot',
                      widget.slot.timeRange),
                  Divider(
                      height: 20,
                      color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _row(theme, cs, Icons.calendar_today_rounded, 'Date',
                      widget.dateLabel),
                  if (widget.price != null) ...[
                    Divider(
                        height: 20,
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                    _row(theme, cs, Icons.payments_rounded, 'Amount',
                        'Rs. ${widget.price!.toInt()}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Remarks
            TextField(
              controller: widget.remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Remarks (optional)...',
                hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, ColorScheme cs, IconData icon, String label,
      String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorState({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message ?? 'Failed to load slots',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
