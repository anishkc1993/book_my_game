import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/regular_booking_entity.dart';
import '../../domain/entities/slot_entity.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_calendar.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookingProvider>();
      provider.fetchSlotConfig();
      provider.selectDate(DateTime.now());
      provider.fetchBookingsForSelectedDate();
      provider.fetchAllRewards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, _) {
          final bookings = bookingProvider.dateBookings;
          final activeCount =
              bookings.where((b) => b.isPending || b.isConfirmed).length;
          final paidCount = bookings.where((b) => b.isPaid).length;
          final unpaidCount = bookings
              .where((b) => !b.isPaid && (b.isPending || b.isConfirmed))
              .length;

          return CustomScrollView(
            slivers: [
              // Custom header
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
                        Expanded(
                          child: Text(
                            'Manage bookings',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showCreateBookingSheet(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.brandGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Calendar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: BookingCalendar(
                    selectedDate: bookingProvider.selectedDate,
                    onDateSelected: (date) {
                      bookingProvider.selectDate(date);
                      bookingProvider.fetchBookingsForSelectedDate();
                    },
                  ),
                ),
              ),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: [
                      _StatTile(
                        label: 'TOTAL',
                        value: '${bookings.length}',
                        valueColor: cs.onSurface,
                      ),
                      _StatTile(
                        label: 'ACTIVE',
                        value: '$activeCount',
                        valueColor: AppColors.brandGreen,
                      ),
                      _StatTile(
                        label: 'PAID',
                        value: '$paidCount',
                        valueColor: const Color(0xFF2563EB),
                      ),
                      _StatTile(
                        label: 'UNPAID',
                        value: '$unpaidCount',
                        valueColor: const Color(0xFFE6A020),
                      ),
                    ],
                  ),
                ),
              ),

              // List header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'Bookings · today',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (bookingProvider.state == BookingState.loading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      else
                        Text(
                          'Filter',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Empty state
              if (bookingProvider.dateBookings.isEmpty &&
                  bookingProvider.state != BookingState.loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No bookings for this date',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showCreateBookingSheet(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New Booking'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bookings list
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) {
                      final booking = bookingProvider.dateBookings[index];
                      final reward =
                          bookingProvider.rewardFor(booking.userPhone);
                      final eligible = bookingProvider.rewardsEnabled &&
                          reward != null &&
                          reward.isEligible(
                              bookingProvider.freeGameThreshold);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BookingCard(
                          booking: booking,
                          onMarkPaid: () => _markAsPaid(booking),
                          onCancel: () => _cancelBooking(booking),
                          freeGameEligible: eligible,
                          onClaimFreeGame: eligible
                              ? () => _claimFreeGame(booking)
                              : null,
                        ),
                      );
                    },
                    childCount: bookingProvider.dateBookings.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == tomorrow) return 'Tomorrow';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month]}';
  }

  Future<void> _markAsPaid(BookingEntity booking) async {
    final bookingProvider = context.read<BookingProvider>();
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _MarkAsPaidDialog(booking: booking),
    );
    if (result == null || !mounted) return;

    bool success;
    if (booking.isRegular && booking.regularBookingId != null) {
      // Synthetic regular entry — materialize this specific occurrence
      // as a real paid booking. Build a stand-in regular from the
      // synthetic booking's own fields so we don't depend on the regulars
      // list being preloaded on this page.
      final synth = RegularBookingEntity(
        id: booking.regularBookingId,
        customerName: booking.customerName ?? '',
        userPhone: booking.userPhone,
        daysOfWeek: const [],
        startHour: booking.startTime.hour,
        basePrice: booking.basePrice ?? result,
        startDate: booking.date,
        createdByAdmin: booking.createdByAdmin,
      );
      final adminId = context.read<AuthProvider>().user?.uid ?? '';
      success = await bookingProvider.markRegularPaidForDate(
        regular: synth,
        date: booking.date,
        amount: result,
        adminId: adminId,
      );
    } else {
      success = await bookingProvider.markAsPaid(booking.id!, result);
    }

    if (mounted) {
      final errMsg = bookingProvider.regularsError ??
          bookingProvider.errorMessage ??
          'unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Marked as paid · Rs. ${result.toStringAsFixed(0)}'
              : 'Failed: $errMsg'),
          backgroundColor: success ? AppColors.brandGreen : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration:
              Duration(seconds: success ? 3 : 8),
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _claimFreeGame(BookingEntity booking) async {
    final bookingProvider = context.read<BookingProvider>();
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim free game?'),
        content: Text(
          'Mark this booking as the free game for '
          '${booking.customerName ?? booking.userPhone}.\n\n'
          'Their reward counter will reset to 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: cs.surface,
            ),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Mark the booking paid with amount 0 (free) THEN reset the customer's
    // reward counter. Two separate writes.
    if (booking.id != null && !booking.id!.startsWith('regular_')) {
      await bookingProvider.markAsPaid(booking.id!, 0);
    }
    final ok = await bookingProvider.claimFreeGame(booking.userPhone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(ok ? 'Free game claimed' : 'Failed to claim free game'),
      backgroundColor: ok ? AppColors.brandGreen : cs.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _cancelBooking(BookingEntity booking) async {
    final bookingProvider = context.read<BookingProvider>();
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
            'Cancel booking for ${booking.customerName ?? booking.userPhone}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await bookingProvider.cancelBooking(booking.id!);
      await bookingProvider.fetchBookingsForSelectedDate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Booking cancelled' : 'Failed to cancel'),
            backgroundColor: success ? Colors.grey : Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showCreateBookingSheet(BuildContext context) async {
    final bookingProvider = context.read<BookingProvider>();
    final authProvider = context.read<AuthProvider>();

    // Admin flow — include past hours so admins can backfill bookings
    // for slots that have already started today.
    await bookingProvider.fetchSlotsForSelectedDate(includePast: true);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _NewBookingSheet(
        bookingProvider: bookingProvider,
        selectedDate: bookingProvider.selectedDate,
        dateLabel: _dateLabel(bookingProvider.selectedDate),
      ),
    );

    if (result != null && context.mounted) {
      final user = authProvider.user;
      if (user == null) return;

      final selectedDate = bookingProvider.selectedDate;
      final hours = result['hours'] as List<int>;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      int successCount = 0;
      int failCount = 0;

      for (final hour in hours) {
        final startTime = DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day, hour);
        final endTime = startTime.add(const Duration(hours: 1));
        final basePrice = bookingProvider.slotConfig
            ?.getPriceForHour(hour, date: selectedDate);

        final booking = BookingEntity(
          userId:
              'admin_walk_in_${DateTime.now().millisecondsSinceEpoch}_$hour',
          userPhone: result['phone'] as String,
          customerName: (result['name'] as String).isEmpty
              ? null
              : result['name'] as String,
          date: selectedDate,
          startTime: startTime,
          endTime: endTime,
          remarks: (result['remarks'] as String).isEmpty
              ? null
              : result['remarks'] as String,
          status: BookingStatus.confirmed,
          basePrice: basePrice,
          createdByAdmin: user.uid,
        );

        if (await bookingProvider.createAdminBooking(booking)) {
          successCount++;
        } else {
          failCount++;
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? '$successCount booking${successCount > 1 ? 's' : ''} created!'
                  : '$successCount created, $failCount failed',
            ),
            backgroundColor:
                failCount == 0 ? AppColors.brandGreen : Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ─── New Booking Bottom Sheet ────────────────────────────────────────────────

class _NewBookingSheet extends StatefulWidget {
  final BookingProvider bookingProvider;
  final DateTime selectedDate;
  final String dateLabel;

  const _NewBookingSheet({
    required this.bookingProvider,
    required this.selectedDate,
    required this.dateLabel,
  });

  @override
  State<_NewBookingSheet> createState() => _NewBookingSheetState();
}

class _NewBookingSheetState extends State<_NewBookingSheet> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _remarksController = TextEditingController();
  Set<int> _selectedHours = {};

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    final date = widget.selectedDate;
    return _selectedHours.fold(0.0, (sum, h) {
      return sum +
          (widget.bookingProvider.slotConfig
                  ?.getPriceForHour(h, date: date) ??
              0);
    });
  }

  bool get _canConfirm =>
      _selectedHours.isNotEmpty &&
      Validators.isValidPhoneNumber(_phoneController.text);

  String _timeRange() {
    if (_selectedHours.isEmpty) return '';
    final sorted = _selectedHours.toList()..sort();
    String fmt(int h) {
      final period = h >= 12 ? 'PM' : 'AM';
      final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$display $period';
    }

    final endHour = sorted.last + 1;
    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final endDisplay = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
    return '${fmt(sorted.first)} – $endDisplay $endPeriod';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allSlots = widget.bookingProvider.slots;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header: back arrow + title + subtitle + X
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 16, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New booking',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Admin · multi-slot',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // Selection banner (dark green, shown when slots selected)
            if (_selectedHours.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.heroCardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers_rounded,
                        size: 18, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedHours.length} slot${_selectedHours.length > 1 ? 's' : ''} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _timeRange(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedHours = {}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CLEAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  // Customer name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      counterText:
                          '${_phoneController.text.length}/${Validators.phoneNumberLength}',
                      errorText: _phoneController.text.isNotEmpty &&
                              !Validators.isValidPhoneNumber(
                                  _phoneController.text)
                          ? 'Enter ${Validators.phoneNumberLength} digits'
                          : null,
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: Validators.phoneNumberLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                          Validators.phoneNumberLength),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // Slot selection header
                  Text(
                    'Select time slots',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (allSlots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No slots for this date',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.9,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: allSlots.length,
                      itemBuilder: (context, index) {
                        final slot = allSlots[index];
                        final hour = slot.startTime.hour;
                        final isSelected = _selectedHours.contains(hour);
                        final price = widget.bookingProvider.slotConfig
                            ?.getPriceForHour(hour, date: widget.selectedDate);
                        return _AdminSlotCard(
                          slot: slot,
                          isSelected: isSelected,
                          price: price,
                          onTap: slot.isAvailable
                              ? () => setState(() {
                                    if (isSelected) {
                                      _selectedHours.remove(hour);
                                    } else {
                                      _selectedHours.add(hour);
                                    }
                                  })
                              : null,
                        );
                      },
                    ),

                  const SizedBox(height: 16),

                  // Remarks
                  TextField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Bottom bar: Block + Confirm
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: const Text('Block'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: cs.outline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canConfirm
                          ? () => Navigator.pop(context, {
                                'phone': _phoneController.text,
                                'name': _nameController.text,
                                'hours': _selectedHours.toList()..sort(),
                                'remarks': _remarksController.text,
                              })
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _selectedHours.isEmpty
                            ? 'Confirm'
                            : 'Confirm · Rs. ${_totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Admin Slot Card ─────────────────────────────────────────────────────────

class _AdminSlotCard extends StatelessWidget {
  final SlotEntity slot;
  final bool isSelected;
  final double? price;
  final VoidCallback? onTap;

  const _AdminSlotCard({
    required this.slot,
    required this.isSelected,
    this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isPast = slot.isUnavailable;
    final isPlayed = slot.isPlayed;
    final isBooked = slot.isBooked || slot.isBlocked;
    final isAvailable = slot.isAvailable;

    Color bgColor;
    Color borderColor;
    Widget leftIndicator;
    Color timeColor;
    Color labelColor;
    String labelText;
    Widget? rightWidget;

    if (isSelected) {
      bgColor = AppColors.brandGreen;
      borderColor = AppColors.brandGreen;
      timeColor = Colors.white;
      labelColor = Colors.white70;
      labelText = 'Selected';
      leftIndicator = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
      rightWidget = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            size: 12, color: AppColors.brandGreen),
      );
    } else if (isPlayed) {
      // Past + booked: game already happened. Distinct visual + locked.
      bgColor = const Color(0xFF2563EB).withValues(alpha: 0.06);
      borderColor = const Color(0xFF2563EB).withValues(alpha: 0.25);
      timeColor = cs.onSurface.withValues(alpha: 0.45);
      labelColor = const Color(0xFF2563EB);
      labelText = 'Played';
      leftIndicator = const Icon(Icons.check_circle_rounded,
          size: 14, color: Color(0xFF2563EB));
      rightWidget = null;
    } else if (isPast) {
      bgColor = AppColors.brandGreen.withValues(alpha: 0.06);
      borderColor = AppColors.brandGreen.withValues(alpha: 0.15);
      timeColor = AppColors.brandGreen.withValues(alpha: 0.5);
      labelColor = AppColors.brandGreen.withValues(alpha: 0.4);
      labelText = 'Past';
      leftIndicator = Icon(Icons.history_rounded,
          size: 14, color: AppColors.brandGreen.withValues(alpha: 0.4));
      rightWidget = null;
    } else if (isBooked) {
      bgColor = cs.error.withValues(alpha: 0.06);
      borderColor = cs.error.withValues(alpha: 0.2);
      timeColor = cs.onSurface.withValues(alpha: 0.45);
      labelColor = cs.error.withValues(alpha: 0.7);
      labelText = 'Booked';
      leftIndicator = Icon(Icons.lock_rounded,
          size: 14, color: cs.error.withValues(alpha: 0.6));
      rightWidget = null;
    } else if (isAvailable) {
      bgColor = cs.surfaceContainerLow;
      borderColor = cs.outlineVariant;
      timeColor = cs.onSurface;
      labelColor = AppColors.brandGreen;
      labelText = price != null ? 'Rs. ${price!.toInt()}' : 'Available';
      leftIndicator = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.brandGreen,
          shape: BoxShape.circle,
        ),
      );
      rightWidget = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
      );
    } else {
      bgColor = cs.surfaceContainerLow.withValues(alpha: 0.5);
      borderColor = cs.outlineVariant.withValues(alpha: 0.3);
      timeColor = cs.onSurface.withValues(alpha: 0.35);
      labelColor = cs.onSurface.withValues(alpha: 0.25);
      labelText = 'Blocked';
      leftIndicator = Icon(Icons.block_rounded,
          size: 14, color: cs.onSurface.withValues(alpha: 0.25));
      rightWidget = null;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              leftIndicator,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.timeRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: timeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (rightWidget != null) ...[
                const SizedBox(width: 6),
                rightWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats tile ──────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking Card ────────────────────────────────────────────────────────────

String _getInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onMarkPaid;
  final VoidCallback onCancel;
  final bool freeGameEligible;
  final VoidCallback? onClaimFreeGame;

  const _BookingCard({
    required this.booking,
    required this.onMarkPaid,
    required this.onCancel,
    this.freeGameEligible = false,
    this.onClaimFreeGame,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isActive = booking.isPending || booking.isConfirmed;
    final isCancelled = booking.isCancelled;
    final displayName = booking.customerName ?? 'Walk-in';
    final initials = _getInitials(displayName);

    return Container(
      decoration: BoxDecoration(
        color: isCancelled
            ? cs.surfaceContainerLow.withValues(alpha: 0.5)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: booking.isPaid
              ? AppColors.brandGreen.withValues(alpha: 0.4)
              : isCancelled
                  ? cs.outlineVariant.withValues(alpha: 0.4)
                  : cs.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          // Row 1: Time + status chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  booking.timeRange,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration:
                        isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const Spacer(),
                if (freeGameEligible) ...[
                  const _Chip(
                    label: '🎁 FREE GAME',
                    color: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 6),
                ],
                if (booking.isTournament) ...[
                  const _Chip(
                    label: 'TOURNAMENT',
                    color: Color(0xFFE07820),
                  ),
                  const SizedBox(width: 6),
                ] else if (booking.isMonthlyPlan) ...[
                  const _Chip(
                    label: 'PLAN',
                    color: Color(0xFF5C5BD6),
                  ),
                  const SizedBox(width: 6),
                ] else if (booking.isRegular) ...[
                  const _Chip(
                    label: 'REGULAR',
                    color: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 6),
                ],
                if (!booking.isMonthlyPlan && !booking.isTournament) ...[
                  if (booking.isPaid)
                    const _Chip(
                      label: 'PAID',
                      color: Color(0xFF2563EB),
                    )
                  else if (isActive && !booking.isRegular)
                    const _Chip(label: 'UNPAID', color: Color(0xFFE6A020)),
                  if (!booking.isRegular) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      label: booking.status.value,
                      color: _statusColor(booking.status, cs),
                    ),
                  ],
                ],
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

          // Row 2: Avatar + name/phone + amount
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration:
                              isCancelled ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        booking.userPhone,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!booking.isMonthlyPlan && !booking.isTournament) ...[
                  if (booking.amountPaid != null)
                    Text(
                      'Rs. ${booking.amountPaid!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (booking.basePrice != null)
                    Text(
                      'Rs. ${booking.basePrice!.toInt()}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ],
            ),
          ),

          if (isActive &&
              !booking.isMonthlyPlan &&
              !booking.isTournament) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // Row 3: Actions. Regular synthetic entries skip Cancel
            // (regulars are cancelled from the Regulars page) but keep
            // Mark paid so admins can record the collection right here.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Row(
                children: [
                  if (freeGameEligible && onClaimFreeGame != null) ...[
                    FilledButton.icon(
                      onPressed: onClaimFreeGame,
                      icon: const Icon(Icons.card_giftcard_rounded, size: 15),
                      label: const Text('Claim free'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (!booking.isPaid)
                    OutlinedButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.payments_rounded, size: 15),
                      label: const Text('Mark paid'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandGreen,
                        side: BorderSide(
                            color: AppColors.brandGreen.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 34),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Paid'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        side: BorderSide(color: cs.outlineVariant),
                        minimumSize: const Size(0, 34),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  if (!booking.isRegular) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 34),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.more_horiz_rounded,
                        color: cs.onSurfaceVariant),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus status, ColorScheme cs) {
    return switch (status) {
      BookingStatus.pending => const Color(0xFFE6A020),
      BookingStatus.confirmed => AppColors.brandGreen,
      BookingStatus.completed => const Color(0xFF2563EB),
      BookingStatus.cancelled => cs.onSurfaceVariant,
    };
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Mark as Paid Dialog ─────────────────────────────────────────────────────

class _MarkAsPaidDialog extends StatefulWidget {
  final BookingEntity booking;
  const _MarkAsPaidDialog({required this.booking});

  @override
  State<_MarkAsPaidDialog> createState() => _MarkAsPaidDialogState();
}

class _MarkAsPaidDialogState extends State<_MarkAsPaidDialog> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.booking.basePrice?.toInt().toString() ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text);
  bool get _valid => _amount != null && _amount! > 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final booking = widget.booking;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments_rounded, color: AppColors.brandGreen),
          SizedBox(width: 8),
          Text('Mark as Paid'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer: ${booking.customerName ?? booking.userPhone}'),
          Text(
            'Time: ${booking.timeRange}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          if (booking.basePrice != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Slot Price: Rs. ${booking.basePrice!.toInt()}',
                style: const TextStyle(
                  color: AppColors.brandGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount Received (Rs.)',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
              hintText: 'Enter amount',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _valid ? () => Navigator.pop(context, _amount) : null,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
