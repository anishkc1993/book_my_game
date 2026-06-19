import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class BookingCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const BookingCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late final ScrollController _scrollController;
  static const int _daysToShow = 30;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late final DateTime _todayNorm;
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayNorm = DateTime(now.year, now.month, now.day);
    _dates = List.generate(_daysToShow, (i) => _todayNorm.add(Duration(days: i)));
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final selNorm = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final diff = selNorm.difference(_todayNorm).inDays;
    if (diff > 0 && diff < _daysToShow && _scrollController.hasClients) {
      final offset = (diff * 60.0) - 40;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg =
        isDark ? AppColors.limeAccent : AppColors.brandGreen;
    final selectedFg =
        isDark ? const Color(0xFF0F2B06) : Colors.white;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = _dates[i];
          final isSelected = date.year == widget.selectedDate.year &&
              date.month == widget.selectedDate.month &&
              date.day == widget.selectedDate.day;
          final isToday = date == _todayNorm;
          final dayName = _dayNames[date.weekday - 1].toUpperCase();

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? selectedBg
                      : isToday
                          ? AppColors.brandGreen.withValues(alpha: 0.4)
                          : cs.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? selectedFg.withValues(alpha: 0.85)
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isSelected ? selectedFg : cs.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  // Indicator dot below — only for selected (matches design)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedFg
                          : isToday
                              ? AppColors.brandGreen
                              : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
