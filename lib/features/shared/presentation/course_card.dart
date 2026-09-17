import 'package:flutter/material.dart';

import '../../../core/nwu/periods.dart';
import '../../../domain/schedule/effective_course_instance.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.instance,
    this.status,
    this.compact = false,
    super.key,
  });

  final EffectiveCourseInstance instance;
  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(instance.course.colorOverride ?? scheme.primary.value);
    final label = [
      instance.courseName,
      if (instance.location != null) instance.location!,
      '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
          '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
      if (instance.teacher != null) instance.teacher!,
    ].join('，');

    return Semantics(
      button: true,
      label: label,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showCourseDetails(context, instance),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status != null)
                          Text(
                            status!,
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        Text(
                          instance.courseName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          instance.location ?? '地点待补充',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                          '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}'
                          '${instance.teacher == null ? '' : ' · ${instance.teacher}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showCourseDetails(
  BuildContext context,
  EffectiveCourseInstance instance,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final weekText = instance.meetingRule?.weekMask.weeks;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instance.courseName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 18),
              _DetailLine(label: '教师', value: instance.teacher ?? '未提供'),
              _DetailLine(label: '地点', value: instance.location ?? '未提供'),
              _DetailLine(
                label: '时间',
                value:
                    '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                    '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
              ),
              _DetailLine(
                label: '周次',
                value: weekText == null || weekText.isEmpty
                    ? '单次课程'
                    : '${weekText.first}-${weekText.last} 周',
              ),
              if (instance.course.code != null)
                _DetailLine(label: '课程代码', value: instance.course.code!),
              if (instance.course.note != null)
                _DetailLine(label: '备注', value: instance.course.note!),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showComingSoon(context, '临时变更'),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('临时变更'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showComingSoon(context, '编辑整门课程'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑整门课程'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  Navigator.of(context).pop();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature将在后续数据层阶段接入')),
  );
}
