import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/utils/week_mask.dart';
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
    final accent = Color(
      instance.course.colorOverride ?? scheme.primary.toARGB32(),
    );
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
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
    builder: (sheetContext) {
      final weekMask = instance.meetingRule?.weekMask;
      return Consumer(
          builder: (sheetContext, ref, child) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instance.courseName,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _DetailLine(
                          label: '教师', value: instance.teacher ?? '未提供'),
                      _DetailLine(
                          label: '地点', value: instance.location ?? '未提供'),
                      _DetailLine(
                        label: '时间',
                        value:
                            '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                            '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
                      ),
                      _DetailLine(
                        label: '周次',
                        value: instance.isException || weekMask == null
                            ? '单次课程'
                            : formatWeekMask(weekMask),
                      ),
                      if (instance.course.code != null)
                        _DetailLine(
                            label: '课程代码', value: instance.course.code!),
                      if (instance.course.note != null)
                        _DetailLine(label: '备注', value: instance.course.note!),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showComingSoon(sheetContext, '临时变更'),
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('临时变更'),
                          ),
                          if (!instance.isException) ...[
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                context
                                    .go('/course/${instance.course.id}/edit');
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('编辑整门课程'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _hideCourse(context,
                                  sheetContext, ref, instance.course.id),
                              icon: const Icon(Icons.visibility_off_outlined),
                              label: const Text('隐藏课程'),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteCourse(context,
                                  sheetContext, ref, instance.course.id),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('删除课程'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ));
    },
  );
}

Future<void> _hideCourse(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String courseId,
) async {
  try {
    await ref
        .read(scheduleDataRepositoryProvider)
        .setCourseHidden(courseId, true);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('课程已隐藏')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('隐藏失败：$error')),
      );
    }
  }
}

Future<void> _deleteCourse(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String courseId,
) async {
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除这门课程？'),
      content: const Text('手动课程会从本机移除；教务导入课程会保留删除记录，避免再次导入时自动恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).deleteCourse(courseId);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('课程已删除')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }
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
