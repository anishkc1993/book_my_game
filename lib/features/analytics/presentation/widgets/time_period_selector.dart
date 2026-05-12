import 'package:flutter/material.dart';

import '../../domain/entities/analytics_entity.dart';

class TimePeriodSelector extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;

  const TimePeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TimePeriod>(
      segments: const [
        ButtonSegment<TimePeriod>(
          value: TimePeriod.today,
          label: Text('Today'),
          icon: Icon(Icons.today_rounded),
        ),
        ButtonSegment<TimePeriod>(
          value: TimePeriod.week,
          label: Text('Week'),
          icon: Icon(Icons.date_range_rounded),
        ),
        ButtonSegment<TimePeriod>(
          value: TimePeriod.month,
          label: Text('Month'),
          icon: Icon(Icons.calendar_month_rounded),
        ),
      ],
      selected: {selectedPeriod},
      onSelectionChanged: (Set<TimePeriod> newSelection) {
        onPeriodChanged(newSelection.first);
      },
      showSelectedIcon: false,
    );
  }
}
