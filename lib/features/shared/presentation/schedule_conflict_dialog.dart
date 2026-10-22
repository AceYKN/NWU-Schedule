import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../domain/schedule/schedule_conflict_detector.dart';
import 'campus_text.dart';

Future<bool> confirmScheduleConflicts(
  BuildContext context,
  List<ScheduleConflict> conflicts,
) async {
  if (conflicts.isEmpty) return true;
  final groups = <String, _ConflictGroup>{};
  for (final conflict in conflicts) {
    final changed = conflict.changed;
    final other = conflict.other;
    final key = [
      changed.meetingRule?.id ?? changed.exceptionId,
      changed.startSection,
      changed.endSection,
      other.course.id,
      other.meetingRule?.id ?? other.exceptionId,
      other.startSection,
      other.endSection,
    ].join('|');
    groups.putIfAbsent(key, () => _ConflictGroup(conflict)).dates.add(
          dateKey(conflict.date),
        );
  }
  final summaries = groups.values.toList(growable: false);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('schedule-conflict-dialog'),
      title: Text(campusText(dialogContext, '发现撞课')),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .48,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(campusText(dialogContext, '这些课程会在同一时间上课，可以返回修改或继续保存。')),
              const SizedBox(height: 12),
              for (final summary in summaries.take(4)) ...[
                _ConflictSummary(summary: summary),
                const SizedBox(height: 8),
              ],
              if (summaries.length > 4)
                Text(campusText(dialogContext, '还有 {0} 组撞课',
                    values: {'0': summaries.length - 4})),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(campusText(dialogContext, '返回修改')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(campusText(dialogContext, '仍要保存')),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _ConflictGroup {
  _ConflictGroup(this.first);

  final ScheduleConflict first;
  final Set<String> dates = {};
}

class _ConflictSummary extends StatelessWidget {
  const _ConflictSummary({required this.summary});

  final _ConflictGroup summary;

  @override
  Widget build(BuildContext context) {
    final first = summary.first;
    final date = first.date;
    final changed = first.changed;
    final other = first.other;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campusText(context, '与“{0}”重叠', values: {'0': other.courseName}),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(campusText(context, '{0}年{1}月{2}日 · {3}', values: {
            '0': date.year,
            '1': date.month,
            '2': date.day,
            '3': campusWeekdayName(context, date.weekday),
          })),
          Text(campusText(context, '新安排第{0}-{1}节 · 已有课第{2}-{3}节', values: {
            '0': changed.startSection,
            '1': changed.endSection,
            '2': other.startSection,
            '3': other.endSection,
          })),
          if (summary.dates.length > 1)
            Text(campusText(context, '本学期共 {0} 天重叠',
                values: {'0': summary.dates.length})),
        ],
      ),
    );
  }
}
