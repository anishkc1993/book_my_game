import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/booking_entity.dart';
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
      provider.selectDate(DateTime.now());
      provider.fetchBookingsForSelectedDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Manage Bookings'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showCreateBookingDialog(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Booking',
          ),
        ],
      ),
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, child) {
          return CustomScrollView(
            slivers: [
              // Calendar Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Panel',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'View and manage all bookings',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BookingCalendar(
                        selectedDate: bookingProvider.selectedDate,
                        onDateSelected: (date) {
                          bookingProvider.selectDate(date);
                          bookingProvider.fetchBookingsForSelectedDate();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsSummary(context, bookingProvider),
                ),
              ),

              // Bookings List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.list_alt_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bookings for ${_getDateLabel(bookingProvider.selectedDate)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bookings List
              if (bookingProvider.state == BookingState.loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (bookingProvider.dateBookings.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookings for this date',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => _showCreateBookingDialog(context),
                            child: const Text('Create Booking'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final booking = bookingProvider.dateBookings[index];
                        return _BookingCard(
                          booking: booking,
                          onMarkPaid: () => _markAsPaid(context, booking),
                          onCancel: () => _cancelBooking(context, booking),
                        );
                      },
                      childCount: bookingProvider.dateBookings.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBookingDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking'),
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, BookingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookings = provider.dateBookings;

    final totalBookings = bookings.length;
    final activeBookings = bookings.where((b) =>
        b.status == BookingStatus.pending || b.status == BookingStatus.confirmed).length;
    final paidBookings = bookings.where((b) => b.isPaid).length;
    final unpaidActiveBookings = bookings.where((b) =>
        !b.isPaid && (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed)).length;
    final totalRevenue = bookings
        .where((b) => b.isPaid && b.amountPaid != null)
        .fold(0.0, (sum, b) => sum + b.amountPaid!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(context, 'Total', totalBookings.toString(), colorScheme.primary),
              _statItem(context, 'Active', activeBookings.toString(), Colors.blue),
              _statItem(context, 'Paid', paidBookings.toString(), Colors.green),
              _statItem(context, 'Unpaid', unpaidActiveBookings.toString(), Colors.orange),
            ],
          ),
          if (totalRevenue > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_rupee_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Revenue: Rs. ${totalRevenue.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
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

  Widget _statItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) return 'Today';
    if (selectedDay == tomorrow) return 'Tomorrow';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _markAsPaid(BuildContext context, BookingEntity booking) async {
    final amountController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payments_rounded, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Mark as Paid'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${booking.customerName ?? booking.userPhone}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                'Time: ${booking.timeRange}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (Rs.)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                  border: OutlineInputBorder(),
                  hintText: 'Enter amount',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
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
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context, amount);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );

    amountController.dispose();

    if (result != null && context.mounted) {
      final success = await context.read<BookingProvider>().markAsPaid(booking.id!, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Marked as paid - Rs. ${result.toStringAsFixed(0)}' : 'Failed to update'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(BuildContext context, BookingEntity booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Cancel booking for ${booking.customerName ?? booking.userPhone}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final bookingProvider = context.read<BookingProvider>();
      final success = await bookingProvider.cancelBooking(booking.id!);
      // Refresh the date bookings for admin view
      await bookingProvider.fetchBookingsForSelectedDate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Booking cancelled' : 'Failed to cancel'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCreateBookingDialog(BuildContext context) async {
    final bookingProvider = context.read<BookingProvider>();
    final authProvider = context.read<AuthProvider>();

    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final remarksController = TextEditingController();
    Set<int> selectedHours = {};

    // Get available slots
    await bookingProvider.fetchSlotsForSelectedDate();

    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final availableSlots = bookingProvider.slots.where((s) => s.isAvailable).toList();

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Create Booking'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date: ${_getDateLabel(bookingProvider.selectedDate)}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          prefixIcon: Icon(Icons.person_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '98XXXXXXXX',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          border: const OutlineInputBorder(),
                          counterText: '${phoneController.text.length}/${Validators.phoneNumberLength}',
                          errorText: phoneController.text.isNotEmpty &&
                              !Validators.isValidPhoneNumber(phoneController.text)
                              ? 'Enter ${Validators.phoneNumberLength} digits'
                              : null,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: Validators.phoneNumberLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(Validators.phoneNumberLength),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Text('Select Time Slots', style: theme.textTheme.titleSmall),
                          const SizedBox(width: 8),
                          if (selectedHours.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedHours.length} selected',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to select multiple slots',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (availableSlots.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('No slots available for this date'),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableSlots.map((slot) {
                            final isSelected = selectedHours.contains(slot.startTime.hour);
                            return FilterChip(
                              label: Text(_formatHour(slot.startTime.hour)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedHours.add(slot.startTime.hour);
                                  } else {
                                    selectedHours.remove(slot.startTime.hour);
                                  }
                                });
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks (Optional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedHours.isNotEmpty &&
                      Validators.isValidPhoneNumber(phoneController.text)
                      ? () {
                          Navigator.pop(context, {
                            'phone': phoneController.text,
                            'name': nameController.text,
                            'hours': selectedHours.toList()..sort(),
                            'remarks': remarksController.text,
                          });
                        }
                      : null,
                  child: Text(selectedHours.length > 1
                      ? 'Create ${selectedHours.length} Bookings'
                      : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      final user = authProvider.user;
      if (user == null) return;

      final selectedDate = bookingProvider.selectedDate;
      final hours = result['hours'] as List<int>;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      int successCount = 0;
      int failCount = 0;

      for (final hour in hours) {
        final startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          hour,
        );
        final endTime = startTime.add(const Duration(hours: 1));

        final booking = BookingEntity(
          userId: 'admin_walk_in_${DateTime.now().millisecondsSinceEpoch}_$hour',
          userPhone: result['phone'] as String,
          customerName: (result['name'] as String).isEmpty ? null : result['name'] as String,
          date: selectedDate,
          startTime: startTime,
          endTime: endTime,
          remarks: (result['remarks'] as String).isEmpty ? null : result['remarks'] as String,
          status: BookingStatus.confirmed,
          createdByAdmin: user.uid,
        );

        final success = await bookingProvider.createAdminBooking(booking);
        if (success) {
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
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    }

    phoneController.dispose();
    nameController.dispose();
    remarksController.dispose();
  }

  String _formatHour(int hour) {
    final startPeriod = hour >= 12 ? 'PM' : 'AM';
    final displayStart = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final endHour = hour + 1;
    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final displayEnd = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
    return '$displayStart $startPeriod - $displayEnd $endPeriod';
  }
}

class _BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onMarkPaid;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.onMarkPaid,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = booking.isPending || booking.isConfirmed;
    final isCancelled = booking.isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCancelled
            ? colorScheme.surfaceContainerLow.withOpacity(0.5)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: booking.isPaid
              ? Colors.green.withOpacity(0.5)
              : isCancelled
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.timeRange,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                // Status Chips
                if (booking.isPaid)
                  _statusChip(
                    context,
                    booking.amountPaid != null
                        ? 'PAID Rs.${booking.amountPaid!.toStringAsFixed(0)}'
                        : 'PAID',
                    Colors.green,
                  )
                else if (isActive)
                  _statusChip(context, 'UNPAID', Colors.orange),
                const SizedBox(width: 8),
                _statusChip(
                  context,
                  booking.status.value,
                  _getStatusColor(booking.status),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Info
            Row(
              children: [
                Icon(Icons.person_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.customerName ?? 'Walk-in Customer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.phone_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  booking.userPhone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (booking.remarks != null && booking.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.remarks!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Actions
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!booking.isPaid)
                    TextButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Mark Paid'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }
}
