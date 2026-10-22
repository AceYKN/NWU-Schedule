import 'package:flutter/material.dart';

import '../../../app/theme/campus_design.dart';
import '../../../domain/calendar/calendar_engine.dart';

class CampusHomeHeader extends StatelessWidget {
  const CampusHomeHeader({
    required this.resolved,
    required this.design,
    super.key,
  });

  final ResolvedCalendarDate resolved;
  final CampusDesign design;

  @override
  Widget build(BuildContext context) {
    final date = resolved.actualDate;
    final week = resolved.teachingWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${date.month}月${date.day}日',
                    style: design.heading(21)),
                TextSpan(
                    text: '  ${CampusDesign.weekdayName(date.weekday)}',
                    style: design.heading(14)),
              ])),
            ),
            Text(week == null ? '休業期間' : '第$week週',
                style: design.heading(12, weight: FontWeight.w400)),
          ],
        ),
        if (resolved.label case final label? when label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: design.accent)),
        ],
      ],
    );
  }
}

class CampusWeekHeader extends StatelessWidget {
  const CampusWeekHeader({
    required this.design,
    required this.week,
    required this.maxWeek,
    required this.onWeekChanged,
    required this.onPreferences,
    super.key,
  });

  final CampusDesign design;
  final int week;
  final int maxWeek;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onPreferences;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
        child: Row(children: [
          Expanded(child: Text('時間割', style: design.heading(21))),
          IconButton(
            tooltip: '前週',
            onPressed: week > 1 ? () => onWeekChanged(week - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 21),
          ),
          Text('第$week週', style: design.heading(13)),
          IconButton(
            tooltip: '翌週',
            onPressed: week < maxWeek ? () => onWeekChanged(week + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 21),
          ),
          IconButton(
            tooltip: '表示設定',
            onPressed: onPreferences,
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ]),
      );
}
