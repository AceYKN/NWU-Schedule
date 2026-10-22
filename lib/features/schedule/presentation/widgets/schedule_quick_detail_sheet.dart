import 'package:flutter/material.dart';

import '../../../../core/nwu/periods.dart';
import '../../../../domain/course/course_exception.dart';
import '../../../../domain/schedule/effective_course_instance.dart';
import '../../../../domain/schedule/schedule_engine.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../shared/presentation/course_card.dart';
import '../../../shared/presentation/course_color_resolver.dart';
import '../../../shared/presentation/course_title.dart';
import '../../../shared/presentation/schedule_motion.dart';
import 'course_display_formatter.dart';
import 'timeslot_semester_schedule.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

Future<void> showScheduleQuickDetail({
  required BuildContext context,
  required ScheduleEngine engine,
  required ScheduleGridEntry entry,
  required int selectedWeek,
  TimeslotSemesterSchedule? semesterSchedule,
  Set<String> hiddenCourseIds = const <String>{},
  Future<void> Function(EffectiveCourseInstance instance)? onHideCourse,
  Future<void> Function(EffectiveCourseInstance instance)? onRestoreCourse,
}) {
  final resolvedSemesterSchedule = semesterSchedule ??
      TimeslotSemesterScheduleBuilder.build(
        engine: engine,
        weekday: entry.weekday,
        startSection: entry.startSection,
        endSection: entry.endSection,
      );
  final pageContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: ScheduleMotion.sheetStyleOf(context),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .68,
      minChildSize: .45,
      maxChildSize: .92,
      builder: (_, scrollController) => _QuickDetailContent(
        pageContext: pageContext,
        entry: entry,
        palette: CourseColorResolver.schedulePaletteForCourses(engine.courses),
        selectedWeek: selectedWeek,
        schedule: resolvedSemesterSchedule,
        scrollController: scrollController,
        hiddenCourseIds: hiddenCourseIds,
        onHideCourse: onHideCourse,
        onRestoreCourse: onRestoreCourse,
      ),
    ),
  );
}

class _QuickDetailContent extends StatelessWidget {
  const _QuickDetailContent({
    required this.pageContext,
    required this.entry,
    required this.palette,
    required this.selectedWeek,
    required this.schedule,
    required this.scrollController,
    required this.hiddenCourseIds,
    this.onHideCourse,
    this.onRestoreCourse,
  });

  final BuildContext pageContext;
  final ScheduleGridEntry entry;
  final Map<String, int> palette;
  final int selectedWeek;
  final TimeslotSemesterSchedule schedule;
  final ScrollController scrollController;
  final Set<String> hiddenCourseIds;
  final Future<void> Function(EffectiveCourseInstance instance)? onHideCourse;
  final Future<void> Function(EffectiveCourseInstance instance)?
      onRestoreCourse;

  @override
  Widget build(BuildContext context) {
    final instance = entry.instance;
    final scheme = Theme.of(context).colorScheme;
    final status = _statusLabel(entry);
    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CourseTitle(
                  course: instance.course,
                  paletteIndex: palette[instance.course.id],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (status != null) _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            campusText(context, '{0} · 第{1}-{2}节', values: {
              '0': campusWeekdayName(context, instance.date.weekday),
              '1': instance.startSection,
              '2': instance.endSection
            }),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          CourseDetailLine(
            label: campusText(context, '时间'),
            value:
                '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
          ),
          CourseDetailLine(
            label: campusText(context, '地点'),
            value: instance.location ?? campusText(context, '地点待补充'),
          ),
          CourseDetailLine(
            label: campusText(context, '教师'),
            value: instance.teacher?.trim().isNotEmpty == true
                ? instance.teacher!
                : campusText(context, '未提供'),
          ),
          CourseDetailLine(
            label: campusText(context, '周次'),
            value: [
              if (instance.isException || instance.meetingRule == null)
                campusText(context, '单次课程')
              else
                campusWeekMask(context, instance.meetingRule!.weekMask),
              campusText(context, '当前：第{0}周', values: {'0': selectedWeek}),
            ].join(' · '),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: CourseExceptionAction(
              pageContext: pageContext,
              instance: instance,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Text(
            campusText(context, '本节次其他周安排'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          if (schedule.groups.isEmpty)
            Text(
              campusText(context, '本学期其他周没有安排'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            )
          else
            for (final group in schedule.groups)
              _WeekArrangementGroup(
                group: group,
                palette: palette,
                selectedWeek: selectedWeek,
                hiddenCourseIds: hiddenCourseIds,
                onRestoreCourse: onRestoreCourse,
              ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onHideCourse != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await onHideCourse!(instance);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text(campusText(context, '仅在周课表隐藏')),
                ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showCourseDetails(
                    pageContext,
                    instance,
                    paletteIndex: palette[instance.course.id],
                    onHideCourse: onHideCourse == null
                        ? null
                        : () => onHideCourse!(instance),
                  );
                },
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(campusText(context, '查看课程详情')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekArrangementGroup extends StatelessWidget {
  const _WeekArrangementGroup({
    required this.group,
    required this.palette,
    required this.selectedWeek,
    required this.hiddenCourseIds,
    this.onRestoreCourse,
  });

  final TimeslotWeekGroup group;
  final Map<String, int> palette;
  final int selectedWeek;
  final Set<String> hiddenCourseIds;
  final Future<void> Function(EffectiveCourseInstance instance)?
      onRestoreCourse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = group.containsWeek(selectedWeek);
    if (group.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeekDot(color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GroupWeekLabel(
                    label: campusText(context, '{0}{1}', values: {
                      '0': campusWeekText(context, group.weekLabel),
                      '1': isCurrent ? campusText(context, ' · 当前') : ''
                    }),
                    color: scheme.error,
                  ),
                  Text(
                    campusText(context, group.statusLabel ?? '本节次无课程'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final meeting in group.meetings)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeekDot(
                  color: CourseColorResolver.resolveSchedule(
                    meeting.course,
                    scheme,
                    paletteIndex: palette[meeting.course.id],
                  ).accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GroupWeekLabel(
                        label: campusText(context, '{0}{1}', values: {
                          '0': campusWeekText(context, group.weekLabel),
                          '1': isCurrent ? campusText(context, ' · 当前') : ''
                        }),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              CourseDisplayFormatter.title(meeting.courseName),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (hiddenCourseIds.contains(meeting.course.id)) ...[
                            const SizedBox(width: 8),
                            const _HiddenBadge(),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if (meeting.location != null) meeting.location!,
                          if (meeting.teacher != null) meeting.teacher!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if (hiddenCourseIds.contains(meeting.course.id) &&
                          onRestoreCourse != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () async {
                              await onRestoreCourse!(meeting);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(campusText(context, '恢复显示')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HiddenBadge extends StatelessWidget {
  const _HiddenBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        campusText(context, '已隐藏'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _GroupWeekLabel extends StatelessWidget {
  const _GroupWeekLabel({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color ?? Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox(width: 8, height: 8),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      '加' => scheme.tertiary,
      '调' => scheme.secondary,
      '停' => scheme.error,
      _ => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String? _statusLabel(ScheduleGridEntry entry) {
  return switch (entry.exceptionType) {
    CourseExceptionType.add => '加',
    CourseExceptionType.move => '调',
    CourseExceptionType.cancel => '停',
    null => entry.active ? null : '非本周',
  };
}
