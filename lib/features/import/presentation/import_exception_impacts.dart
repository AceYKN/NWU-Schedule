import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/import/import_diff.dart';

String importExceptionImpactSummary(List<ImportExceptionImpact> impacts) {
  String date(DateTime? value) => value == null ? '无' : dateKey(value);
  String type(CourseExceptionType value) => switch (value) {
        CourseExceptionType.move => '调课',
        CourseExceptionType.cancel => '停课',
        CourseExceptionType.add => '加课',
      };
  return [
    '来源安排被删除的临时变更将在确认后移除。整门课程被删除时，记录保留，恢复课程后可再次生效。',
    for (final impact in impacts)
      '${impact.courseName} · ${type(impact.exception.type)} · '
          '原 ${date(impact.exception.sourceDate)} → 目标 ${date(impact.exception.targetDate)} · '
          '${impact.exception.targetStartSection == null ? '' : '第 ${impact.exception.targetStartSection}-${impact.exception.targetEndSection} 节 · '}'
          '${impact.removed ? '移除记录' : '保留记录，暂停生效'}',
  ].join('\n');
}

Future<bool> confirmImportExceptionImpacts(
    BuildContext context, List<ImportExceptionImpact> impacts) async {
  if (impacts.isEmpty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('影响 ${impacts.length} 条临时变更'),
          content: SingleChildScrollView(
              child: Text(importExceptionImpactSummary(impacts))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认上述影响并导入')),
          ],
        ),
      ) ??
      false;
}
