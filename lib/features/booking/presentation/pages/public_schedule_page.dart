import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Public, no-auth view of a turf's 7-day schedule. Reachable at
/// `/turf/:turfId/schedule`. Customers tap a free slot → WhatsApp deep
/// link to the turf admin pre-filled with the slot they want.
///
/// Intentionally read-only and PII-free: only displays which hours are
/// taken, never customer names or phones.
class PublicSchedulePage extends StatefulWidget {
  final String turfId;
  const PublicSchedulePage({super.key, required this.turfId});

  @override
  State<PublicSchedulePage> createState() => _PublicSchedulePageState();
}

class _PublicSchedulePageState extends State<PublicSchedulePage> {
  late Future<_ScheduleData> _future;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ScheduleData> _load() async {
    final db = FirebaseFirestore.instance;

    // Build 7-day window + the dateKey list up front.
    final today =
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0, microsecond: 0, millisecond: 0);
    final days = List.generate(7, (i) => today.add(Duration(days: i)));
    String dateKeyOf(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final dateKeys = days.map(dateKeyOf).toList();

    // Fan out ALL the reads in parallel — turf, slot config, regulars,
    // plans, AND a single bookings query covering the whole 7-day
    // window via `dateKey whereIn`. Drops the round-trip count from
    // ~11 sequential to 5 parallel (≈ p95 RTT * 5 → p95 RTT * 1).
    final results = await Future.wait([
      db.collection('turfs').doc(widget.turfId).get(),
      db
          .collection('turfs')
          .doc(widget.turfId)
          .collection('settings')
          .doc('slot_config')
          .get(),
      db
          .collection('regular_bookings')
          .where('turfId', isEqualTo: widget.turfId)
          .where('isActive', isEqualTo: true)
          .get(),
      db
          .collection('turfs')
          .doc(widget.turfId)
          .collection('monthly_plans')
          .where('isActive', isEqualTo: true)
          .get(),
      db
          .collection('bookings')
          .where('turfId', isEqualTo: widget.turfId)
          .where('dateKey', whereIn: dateKeys)
          .get(),
    ]);

    // 1) Turf info — for display name + WhatsApp number.
    final turfData =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final turfName = (turfData['venueName'] as String?)?.isNotEmpty == true
        ? (turfData['venueName'] as String)
        : (turfData['name'] as String? ?? 'Turf');
    final adminPhone = turfData['adminPhone'] as String? ?? '';

    // 2) Slot config — enabled hours + pricing bands.
    final slotData =
        (results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final enabledHoursRaw = slotData['enabledHours'] as List<dynamic>?;
    final enabledHours = enabledHoursRaw?.map((e) => e as int).toList() ??
        [
          for (int h = AppConstants.slotStartHour;
              h < AppConstants.slotEndHour;
              h++)
            h
        ];
    final morningPrice =
        (slotData['morningPrice'] as num?)?.toDouble() ?? 1000;
    final dayPrice = (slotData['dayPrice'] as num?)?.toDouble() ?? 1000;
    final eveningPrice =
        (slotData['eveningPrice'] as num?)?.toDouble() ?? 1200;
    final weekendPrice =
        (slotData['weekendPrice'] as num?)?.toDouble() ?? 1500;
    final dayStartHour =
        (slotData['dayStartHour'] as num?)?.toInt() ?? 10;
    final eveningStartHour =
        (slotData['eveningStartHour'] as num?)?.toInt() ?? 17;

    // 3) Regulars + plans — independent of the day loop.
    final regularsSnap =
        results[2] as QuerySnapshot<Map<String, dynamic>>;
    final regulars = regularsSnap.docs.map((d) {
      final data = d.data();
      return _RegularInfo(
        daysOfWeek: ((data['daysOfWeek'] as List<dynamic>?) ?? [])
            .map((e) => e as int)
            .toList(),
        startHour: (data['startHour'] as num?)?.toInt() ?? 0,
        startDate: (data['startDate'] as Timestamp?)?.toDate(),
      );
    }).toList();

    final plansSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final plans = plansSnap.docs.map((d) {
      final data = d.data();
      return _PlanInfo(
        daysOfWeek: ((data['daysOfWeek'] as List<dynamic>?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        startHours: ((data['startHours'] as List<dynamic>?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        startDate: (data['startDate'] as Timestamp?)?.toDate(),
      );
    }).toList();

    // 4) Bookings — one query covers the whole 7-day window. Bucket by
    //    dateKey client-side.
    final bookingsSnap =
        results[4] as QuerySnapshot<Map<String, dynamic>>;
    final bookedByDateKey = <String, Set<int>>{
      for (final k in dateKeys) k: <int>{},
    };
    for (final b in bookingsSnap.docs) {
      final data = b.data();
      final status = data['status'] as String?;
      if (status == 'CANCELLED') continue;
      final dateKey = data['dateKey'] as String?;
      if (dateKey == null) continue;
      final bucket = bookedByDateKey[dateKey];
      if (bucket == null) continue;
      final start = (data['startTime'] as Timestamp?)?.toDate();
      if (start != null) bucket.add(start.hour);
    }

    final dayResults = <_DaySchedule>[];
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final bookedHours = Set<int>.from(bookedByDateKey[dateKeys[i]] ?? {});

      // Regular sessions on this weekday.
      for (final r in regulars) {
        if (r.daysOfWeek.contains(day.weekday) &&
            (r.startDate == null || !day.isBefore(r.startDate!))) {
          bookedHours.add(r.startHour);
        }
      }
      // Plan slots on this weekday — each plan covers multiple hours per
      // scheduled day, and only kicks in on/after its startDate.
      for (final p in plans) {
        if (!p.daysOfWeek.contains(day.weekday)) continue;
        if (p.startDate != null && day.isBefore(p.startDate!)) continue;
        bookedHours.addAll(p.startHours);
      }

      dayResults.add(_DaySchedule(date: day, bookedHours: bookedHours));
    }

    return _ScheduleData(
      turfName: turfName,
      adminPhone: adminPhone,
      enabledHours: enabledHours,
      days: dayResults,
      morningPrice: morningPrice,
      dayPrice: dayPrice,
      eveningPrice: eveningPrice,
      weekendPrice: weekendPrice,
      dayStartHour: dayStartHour,
      eveningStartHour: eveningStartHour,
    );
  }

  double _priceFor(_ScheduleData data, DateTime date, int hour) {
    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      return data.weekendPrice;
    }
    if (hour < data.dayStartHour) return data.morningPrice;
    if (hour < data.eveningStartHour) return data.dayPrice;
    return data.eveningPrice;
  }

  String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _dayLabel(DateTime d) {
    final today = DateTime.now();
    final isToday = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;
    final isTomorrow = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day + 1;
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    const wkd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return wkd[d.weekday - 1];
  }

  String _dateShort(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _openWhatsapp(
      _ScheduleData data, DateTime date, int hour) async {
    if (data.adminPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Turf contact unavailable'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final price = _priceFor(data, date, hour);
    final dateLabel =
        '${_dayLabel(date)}, ${_dateShort(date)}';
    final slotLabel =
        '${_formatHour(hour)} – ${_formatHour(hour + 1)}';
    final msg = Uri.encodeComponent(
      'Hi, I\'d like to book ${data.turfName} on $dateLabel '
      '($slotLabel · Rs. ${price.toInt()}).',
    );
    // wa.me expects digits only (no +, no spaces).
    final phoneDigits = data.adminPhone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$phoneDigits?text=$msg');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open WhatsApp'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_ScheduleData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Couldn\'t load schedule.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            final data = snap.data!;
            final selectedDay = data.days[_selectedDayIndex];
            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.turfName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Available slots · next 7 days',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Day tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                    child: SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: data.days.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final d = data.days[i].date;
                          final isSelected = i == _selectedDayIndex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDayIndex = i),
                            child: Container(
                              width: 76,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandGreen
                                    : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brandGreen
                                      : cs.outlineVariant,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _dayLabel(d),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : cs.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dateShort(d),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                              .withValues(alpha: 0.85)
                                          : cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Legend
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: [
                        _LegendDot(
                            color: AppColors.brandGreen, label: 'Free'),
                        const SizedBox(width: 16),
                        _LegendDot(
                            color: cs.outlineVariant, label: 'Booked'),
                        const Spacer(),
                        Text(
                          'Tap a slot to book on WhatsApp',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Slot grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final hour = data.enabledHours[i];
                        final booked =
                            selectedDay.bookedHours.contains(hour);
                        final price = _priceFor(
                            data, selectedDay.date, hour);
                        return _SlotTile(
                          hour: hour,
                          formattedHour: _formatHour(hour),
                          formattedNext: _formatHour(hour + 1),
                          isBooked: booked,
                          price: price,
                          onTap: booked
                              ? null
                              : () => _openWhatsapp(
                                  data, selectedDay.date, hour),
                        );
                      },
                      childCount: data.enabledHours.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  final int hour;
  final String formattedHour;
  final String formattedNext;
  final bool isBooked;
  final double price;
  final VoidCallback? onTap;
  const _SlotTile({
    required this.hour,
    required this.formattedHour,
    required this.formattedNext,
    required this.isBooked,
    required this.price,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isBooked
        ? cs.surfaceContainerHighest
        : AppColors.brandGreen.withValues(alpha: 0.12);
    final fg = isBooked ? cs.onSurfaceVariant : AppColors.brandGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBooked
                ? cs.outlineVariant
                : AppColors.brandGreen.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$formattedHour – $formattedNext',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isBooked ? 'Booked' : 'Rs. ${price.toInt()}',
              style: TextStyle(
                color: fg.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegularInfo {
  final List<int> daysOfWeek;
  final int startHour;
  final DateTime? startDate;
  _RegularInfo({
    required this.daysOfWeek,
    required this.startHour,
    required this.startDate,
  });
}

class _PlanInfo {
  final List<int> daysOfWeek;
  final List<int> startHours;
  final DateTime? startDate;
  _PlanInfo({
    required this.daysOfWeek,
    required this.startHours,
    required this.startDate,
  });
}

class _DaySchedule {
  final DateTime date;
  final Set<int> bookedHours;
  _DaySchedule({required this.date, required this.bookedHours});
}

class _ScheduleData {
  final String turfName;
  final String adminPhone;
  final List<int> enabledHours;
  final List<_DaySchedule> days;
  final double morningPrice;
  final double dayPrice;
  final double eveningPrice;
  final double weekendPrice;
  final int dayStartHour;
  final int eveningStartHour;
  _ScheduleData({
    required this.turfName,
    required this.adminPhone,
    required this.enabledHours,
    required this.days,
    required this.morningPrice,
    required this.dayPrice,
    required this.eveningPrice,
    required this.weekendPrice,
    required this.dayStartHour,
    required this.eveningStartHour,
  });
}
