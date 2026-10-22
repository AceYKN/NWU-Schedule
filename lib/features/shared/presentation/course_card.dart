import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_conflict_detector.dart';
import '../../../domain/schedule/schedule_engine.dart';
import 'course_color_resolver.dart';
import 'course_title.dart';
import 'schedule_conflict_dialog.dart';
import 'schedule_motion.dart';
import '../../schedule/presentation/course_form_fields.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.instance,
    this.status,
    this.compact = false,
    this.paletteIndex,
    super.key,
  });

  final EffectiveCourseInstance instance;
  final String? status;
  final bool compact;
  final int? paletteIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeTokens = scheduleThemeTokensOf(context);
    final colors = CourseColorResolver.resolveSchedule(
      instance.course,
      scheme,
      paletteIndex: paletteIndex,
    );
    final label = [
      if (status != null) status!,
      instance.courseName,
      if (instance.location != null) instance.location!,
      '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
          '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
      if (instance.teacher != null) instance.teacher!,
    ].join('，');

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: () =>
          showCourseDetails(context, instance, paletteIndex: paletteIndex),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              showCourseDetails(context, instance, paletteIndex: paletteIndex),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('course-color-${instance.course.id}'),
                  width: themeTokens.courseAccentWidth,
                  color: colors.accent,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      compact
                          ? themeTokens.compactCoursePadding
                          : themeTokens.cardPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status == '已结束'
                                    ? scheme.surfaceContainerHighest
                                    : colors.container,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: status == '已结束'
                                          ? scheme.onSurfaceVariant
                                          : colors.onContainer,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                              ),
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
  EffectiveCourseInstance instance, {
  Future<void> Function()? onHideCourse,
  int? paletteIndex,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ScheduleMotion.sheetStyleOf(context),
    builder: (sheetContext) {
      final weekMask = instance.meetingRule?.weekMask;
      return Consumer(
          builder: (sheetContext, ref, child) => SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CourseTitle(
                          course: instance.course,
                          paletteIndex: paletteIndex,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${weekdayName(instance.date.weekday)} · '
                          '第 ${instance.startSection}-${instance.endSection} 节',
                          style: Theme.of(sheetContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        CourseDetailLine(
                          label: campusText(sheetContext, '时间'),
                          value:
                              '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                              '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
                        ),
                        CourseDetailLine(
                          label: campusText(sheetContext, '地点'),
                          value: instance.location ?? '地点待补充',
                        ),
                        CourseDetailLine(
                          label: campusText(sheetContext, '教师'),
                          value: instance.teacher ?? '未提供',
                        ),
                        CourseDetailLine(
                          label: campusText(sheetContext, '周次'),
                          value: instance.isException || weekMask == null
                              ? campusText(sheetContext, '单次课程')
                              : campusWeekMask(sheetContext, weekMask),
                        ),
                        if (instance.course.note != null)
                          CourseDetailLine(
                              label: campusText(sheetContext, '备注'),
                              value: instance.course.note!),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (instance.isException &&
                                instance.exceptionId != null)
                              CourseExceptionAction(
                                pageContext: context,
                                instance: instance,
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _showCourseColorPicker(
                                context,
                                sheetContext,
                                ref,
                                instance,
                              ),
                              icon: const Icon(Icons.palette_outlined),
                              label: Text(campusText(sheetContext, '修改颜色')),
                            ),
                            if (!instance.isException)
                              CourseExceptionAction(
                                pageContext: context,
                                instance: instance,
                              ),
                            if (!instance.isException) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  context
                                      .go('/course/${instance.course.id}/edit');
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(campusText(sheetContext, '编辑整门课程')),
                              ),
                              OutlinedButton.icon(
                                onPressed: onHideCourse == null
                                    ? () => _hideCourse(
                                          context,
                                          sheetContext,
                                          ref,
                                          instance.course.id,
                                        )
                                    : () async {
                                        await onHideCourse();
                                        if (sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                      },
                                icon: const Icon(Icons.visibility_off_outlined),
                                label: Text(onHideCourse == null
                                    ? campusText(sheetContext, '停用课程及提醒')
                                    : campusText(sheetContext, '仅在周课表隐藏')),
                              ),
                              TextButton.icon(
                                onPressed: () => _deleteCourse(context,
                                    sheetContext, ref, instance.course.id),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(campusText(sheetContext, '删除课程')),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ));
    },
  );
}

class CourseExceptionAction extends ConsumerWidget {
  const CourseExceptionAction({
    required this.pageContext,
    required this.instance,
    super.key,
  });

  final BuildContext pageContext;
  final EffectiveCourseInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (instance.isException) {
      final exceptionId = instance.exceptionId;
      if (exceptionId == null) return const SizedBox.shrink();
      return OutlinedButton.icon(
        onPressed: () =>
            _deleteException(pageContext, context, ref, exceptionId),
        icon: const Icon(Icons.undo_outlined),
        label: Text(campusText(context, '撤销临时变更')),
      );
    }
    return OutlinedButton.icon(
      onPressed: () =>
          _showExceptionEditor(pageContext, context, ref, instance),
      icon: const Icon(Icons.edit_calendar_outlined),
      label: Text(campusText(context, '临时变更')),
    );
  }
}

Future<CalendarDefinition?> _exceptionCalendar(
    WidgetRef ref, String semesterId) async {
  final snapshot =
      await ref.read(scheduleDataRepositoryProvider).loadSemester(semesterId);
  final id = snapshot.semester.calendarId;
  return id == null
      ? null
      : ref.read(bundledCalendarRepositoryProvider).findById(id);
}

Future<bool> _confirmExceptionSave(
  BuildContext context,
  WidgetRef ref,
  CalendarDefinition calendar,
  CourseException exception,
) async {
  try {
    final snapshot = await ref
        .read(scheduleDataRepositoryProvider)
        .loadSemester(exception.semesterId);
    final current = ScheduleEngine(
      semesterId: exception.semesterId,
      calendarEngine: CalendarEngine(calendar),
      courses: snapshot.courses,
      meetingRules: snapshot.meetingRules,
      exceptions: snapshot.exceptions,
    );
    final conflicts = ScheduleConflictDetector.forExceptionSave(
      current: current,
      exception: exception,
    );
    if (!context.mounted) return false;
    return await confirmScheduleConflicts(context, conflicts);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(campusUserMessage(context, error,
            action: campusText(context, '检查撞课失败'))),
      ));
    }
    return false;
  }
}

DateTime _clampSemesterDate(DateTime date, CalendarDefinition calendar) {
  if (dateOnly(date).isBefore(calendar.semesterStartDate)) {
    return calendar.semesterStartDate;
  }
  if (dateOnly(date).isAfter(calendar.semesterEndDate)) {
    return calendar.semesterEndDate;
  }
  return dateOnly(date);
}

Future<void> showStandaloneAddException({
  required BuildContext pageContext,
  required WidgetRef ref,
  required String semesterId,
  required DateTime initialDate,
}) async {
  final calendar = await _exceptionCalendar(ref, semesterId);
  if (!pageContext.mounted) return;
  if (calendar == null) {
    ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '请先为学期选择校历'))));
    return;
  }
  final exception = await showModalBottomSheet<CourseException>(
    context: pageContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _StandaloneAddExceptionSheet(
      semesterId: semesterId,
      initialDate: initialDate,
      calendar: calendar,
      confirmSave: (context, exception) =>
          _confirmExceptionSave(context, ref, calendar, exception),
    ),
  );
  if (exception == null || !pageContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).saveException(exception);
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '临时加课已保存'))),
      );
    }
  } catch (error) {
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
            content: Text(campusUserMessage(pageContext, error,
                action: campusText(pageContext, '保存临时加课失败')))),
      );
    }
  }
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
    messenger.showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '课程已停用，相关提醒已停止'))));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
            content: Text(campusUserMessage(pageContext, error,
                action: campusText(pageContext, '隐藏失败')))),
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
      title: Text(campusText(dialogContext, '删除这门课程？')),
      content: Text(
          campusText(dialogContext, '手动课程会从本机移除；教务导入课程会保留删除记录，避免再次导入时自动恢复。')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(campusText(dialogContext, '取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(campusText(dialogContext, '删除')),
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
    messenger.showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '课程已删除'))));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
            content: Text(campusUserMessage(pageContext, error,
                action: campusText(pageContext, '删除失败')))),
      );
    }
  }
}

Future<void> _deleteException(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String exceptionId,
) async {
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: Text(campusText(dialogContext, '撤销临时变更？')),
      content: Text(campusText(dialogContext, '这条单次调课记录会被删除，原始课表将恢复。')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(campusText(dialogContext, '取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(campusText(dialogContext, '撤销')),
        ),
      ],
    ),
  );
  if (confirmed != true || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).deleteException(exceptionId);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '临时变更已撤销'))));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(campusUserMessage(pageContext, error,
              action: campusText(pageContext, '撤销临时变更失败'))),
        ),
      );
    }
  }
}

Future<void> _showExceptionEditor(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  EffectiveCourseInstance instance,
) async {
  final calendar = await _exceptionCalendar(ref, instance.course.semesterId);
  if (!sheetContext.mounted) return;
  if (calendar == null) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '请先为学期选择校历'))));
    return;
  }
  final exception = await showModalBottomSheet<CourseException>(
    context: sheetContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ExceptionEditorSheet(
      instance: instance,
      calendar: calendar,
      confirmSave: (context, exception) =>
          _confirmExceptionSave(context, ref, calendar, exception),
    ),
  );
  if (exception == null || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).saveException(exception);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '临时变更已保存'))));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(campusUserMessage(pageContext, error,
              action: campusText(pageContext, '保存临时变更失败'))),
        ),
      );
    }
  }
}

Future<void> editCourseException({
  required BuildContext context,
  required WidgetRef ref,
  required CourseException exception,
}) async {
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final snapshot = await repository.loadSemester(exception.semesterId);
    final current =
        snapshot.exceptions.singleWhere((e) => e.id == exception.id);
    final calendar = await _exceptionCalendar(ref, current.semesterId);
    if (!context.mounted) return;
    if (calendar == null) throw const CalendarMissingError();
    Widget editor;
    if (current.courseId == null) {
      editor = _StandaloneAddExceptionSheet(
        semesterId: current.semesterId,
        initialDate: current.targetDate!,
        calendar: calendar,
        existing: current,
        confirmSave: (context, exception) =>
            _confirmExceptionSave(context, ref, calendar, exception),
      );
    } else {
      final course =
          snapshot.courses.singleWhere((c) => c.id == current.courseId);
      final rules = snapshot.meetingRules.where((r) => r.courseId == course.id);
      final rule = current.sourceMeetingId == null
          ? (rules.isEmpty ? null : rules.first)
          : rules.singleWhere((r) => r.id == current.sourceMeetingId);
      final sourceDate = current.sourceDate ?? current.targetDate!;
      final start = rule?.startSection ?? current.targetStartSection!;
      final end = rule?.endSection ?? current.targetEndSection!;
      final instance = EffectiveCourseInstance(
        course: course,
        meetingRule: rule,
        date: sourceDate,
        templateDate: sourceDate,
        startSection: start,
        endSection: end,
        startTime:
            const NwuPeriodRepository().byNumber(start).startAt(sourceDate),
        endTime: const NwuPeriodRepository().byNumber(end).endAt(sourceDate),
        teacher: rule?.teacher,
        campus: rule?.campus,
        room: rule?.room,
      );
      editor = _ExceptionEditorSheet(
        instance: instance,
        calendar: calendar,
        existing: current,
        confirmSave: (context, exception) =>
            _confirmExceptionSave(context, ref, calendar, exception),
      );
    }
    final edited = await showModalBottomSheet<CourseException>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => editor,
    );
    if (edited == null || !context.mounted) return;
    await repository.saveException(edited);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(campusText(context, '临时变更已更新'))));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(campusUserMessage(context, error,
              action: campusText(context, '编辑临时变更失败')))));
    }
  }
}

Future<void> _showCourseColorPicker(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  EffectiveCourseInstance instance,
) async {
  final selected = await showModalBottomSheet<int>(
    context: sheetContext,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(campusText(context, '修改课程颜色')),
            subtitle: Text(campusText(context, '颜色覆盖只保存在本机，重新导入不会清除')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _courseColors)
                  Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: instance.course.colorOverride == color
                        ? campusText(context, '课程颜色，已选择')
                        : campusText(context, '选择课程颜色'),
                    onTap: () => Navigator.pop(context, color),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, color),
                        borderRadius: BorderRadius.circular(24),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(color),
                          child: instance.course.colorOverride == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, -1),
                  child: Text(campusText(context, '清除覆盖色')),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !sheetContext.mounted) return;
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final snapshot = await repository.loadSemester(instance.course.semesterId);
    final color = selected == -1 ? null : selected;
    if (instance.exceptionId == instance.course.id) {
      final exception =
          snapshot.exceptions.singleWhere((e) => e.id == instance.exceptionId);
      await repository.saveException(exception.withColor(color));
    } else {
      final course =
          snapshot.courses.singleWhere((c) => c.id == instance.course.id);
      final rules = snapshot.meetingRules
          .where((r) => r.courseId == course.id)
          .toList(growable: false);
      await repository.saveCourse(course.copyWith(colorOverride: color), rules);
    }
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(
        SnackBar(content: Text(campusText(pageContext, '课程颜色已更新'))));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
            content: Text(campusUserMessage(pageContext, error,
                action: campusText(pageContext, '更新课程颜色失败')))),
      );
    }
  }
}

const _courseColors = <int>[
  0xff52766c,
  0xff526579,
  0xff9a7354,
  0xff7b5ea7,
  0xffb25d5d,
  0xff3f7f8f,
  0xff8a6d3b,
  0xff4f7d57,
];

class _ExceptionEditorSheet extends StatefulWidget {
  const _ExceptionEditorSheet({
    required this.instance,
    required this.calendar,
    required this.confirmSave,
    this.existing,
  });

  final CourseException? existing;

  final CalendarDefinition calendar;

  final EffectiveCourseInstance instance;
  final Future<bool> Function(BuildContext, CourseException) confirmSave;

  @override
  State<_ExceptionEditorSheet> createState() => _ExceptionEditorSheetState();
}

class _StandaloneAddExceptionSheet extends StatefulWidget {
  const _StandaloneAddExceptionSheet({
    required this.semesterId,
    required this.initialDate,
    required this.calendar,
    required this.confirmSave,
    this.existing,
  });

  final String semesterId;
  final DateTime initialDate;
  final CalendarDefinition calendar;
  final Future<bool> Function(BuildContext, CourseException) confirmSave;

  final CourseException? existing;

  @override
  State<_StandaloneAddExceptionSheet> createState() =>
      _StandaloneAddExceptionSheetState();
}

class _StandaloneAddExceptionSheetState
    extends State<_StandaloneAddExceptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _teacher = TextEditingController();
  final _campus = TextEditingController();
  final _room = TextEditingController();
  final _note = TextEditingController();
  late DateTime _targetDate;
  int _startSection = 1;
  int _endSection = 2;
  bool _checkingConflict = false;

  @override
  void initState() {
    super.initState();
    _targetDate = _clampSemesterDate(widget.initialDate, widget.calendar);
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.addedCourseName ?? '';
      _teacher.text = existing.teacherOverride ?? '';
      _campus.text = existing.campusOverride ?? '';
      _room.text = existing.roomOverride ?? '';
      _note.text = existing.note ?? '';
      _startSection = existing.targetStartSection!;
      _endSection = existing.targetEndSection!;
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _teacher, _campus, _room, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: widget.calendar.semesterStartDate,
      lastDate: widget.calendar.semesterEndDate,
    );
    if (selected != null && mounted) setState(() => _targetDate = selected);
  }

  Future<void> _submit() async {
    if (_checkingConflict || !_formKey.currentState!.validate()) return;
    final exception = CourseException(
      id: widget.existing?.id ??
          'exception-${DateTime.now().microsecondsSinceEpoch}',
      semesterId: widget.semesterId,
      type: CourseExceptionType.add,
      targetDate: dateOnly(_targetDate),
      targetStartSection: _startSection,
      targetEndSection: _endSection,
      teacherOverride: _optional(_teacher),
      campusOverride: _optional(_campus),
      roomOverride: _optional(_room),
      addedCourseName: _name.text.trim(),
      note: _optional(_note),
      colorOverride: widget.existing?.colorOverride,
    );
    setState(() => _checkingConflict = true);
    try {
      if (!await widget.confirmSave(context, exception) || !mounted) return;
      Navigator.of(context).pop(exception);
    } finally {
      if (mounted) setState(() => _checkingConflict = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Text(
                campusText(context, '临时加课'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(campusText(context, '只在指定日期显示，不会修改周期课表。')),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: campusText(context, '课程名 *')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? campusText(context, '请输入课程名')
                    : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(campusText(context, '上课日期')),
                subtitle: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(_targetDate),
                ),
                onTap: _pickDate,
              ),
              SectionRangeSelector(
                startSection: _startSection,
                endSection: _endSection,
                onChanged: (selection) => setState(() {
                  _startSection = selection.start;
                  _endSection = selection.end;
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _teacher,
                decoration: InputDecoration(
                    labelText: campusText(context, CourseFieldLabels.teacher)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _campus,
                decoration: InputDecoration(
                    labelText: campusText(context, CourseFieldLabels.campus)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                decoration: InputDecoration(
                    labelText: campusText(context, CourseFieldLabels.room)),
              ),
              const SizedBox(height: 12),
              CompactNotesField(
                  controller: _note, label: campusText(context, '备注（可选）')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _checkingConflict ? null : _submit,
                child: Text(campusText(context, '保存临时加课')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExceptionEditorSheetState extends State<_ExceptionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _teacher;
  late final TextEditingController _campus;
  late final TextEditingController _room;
  late final TextEditingController _note;
  late DateTime _targetDate;
  late int _startSection;
  late int _endSection;
  CourseExceptionType _type = CourseExceptionType.move;
  bool _checkingConflict = false;

  EffectiveCourseInstance get _instance => widget.instance;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? CourseExceptionType.move;
    _targetDate = _clampSemesterDate(
        existing?.targetDate ?? _instance.date, widget.calendar);
    _startSection = existing?.targetStartSection ?? _instance.startSection;
    _endSection = existing?.targetEndSection ?? _instance.endSection;
    _teacher = TextEditingController(
        text: existing?.teacherOverride ?? _instance.teacher ?? '');
    _campus = TextEditingController(
        text: existing?.campusOverride ?? _instance.campus ?? '');
    _room = TextEditingController(
        text: existing?.roomOverride ?? _instance.room ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_teacher, _campus, _room, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: widget.calendar.semesterStartDate,
      lastDate: widget.calendar.semesterEndDate,
    );
    if (selected != null && mounted) setState(() => _targetDate = selected);
  }

  Future<void> _submit() async {
    if (_checkingConflict || !_formKey.currentState!.validate()) return;
    final sourceRule = _instance.meetingRule;
    if ((_type == CourseExceptionType.move ||
            _type == CourseExceptionType.cancel) &&
        sourceRule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(campusText(context, '找不到原始上课安排，无法创建临时变更'))),
      );
      return;
    }
    final exception = CourseException(
      id: widget.existing?.id ??
          'exception-${DateTime.now().microsecondsSinceEpoch}',
      semesterId: _instance.course.semesterId,
      courseId: _instance.course.id,
      // ADD from an existing course still uses the clicked meeting as its
      // template. Keep its identity even though ADD has no source date, so a
      // course with multiple arrangements cannot fall back to the first one.
      sourceMeetingId: widget.existing != null
          ? widget.existing!.sourceMeetingId
          : sourceRule?.id,
      sourceDate:
          _type == CourseExceptionType.add ? null : dateOnly(_instance.date),
      type: _type,
      targetDate: _type == CourseExceptionType.cancel ? null : _targetDate,
      targetStartSection:
          _type == CourseExceptionType.cancel ? null : _startSection,
      targetEndSection:
          _type == CourseExceptionType.cancel ? null : _endSection,
      teacherOverride: _type == CourseExceptionType.cancel
          ? null
          : _editedOverride(
              _teacher, widget.existing?.teacherOverride, _instance.teacher),
      campusOverride: _type == CourseExceptionType.cancel
          ? null
          : _editedOverride(
              _campus, widget.existing?.campusOverride, _instance.campus),
      roomOverride: _type == CourseExceptionType.cancel
          ? null
          : _editedOverride(
              _room, widget.existing?.roomOverride, _instance.room),
      addedCourseName: _type == CourseExceptionType.add
          ? widget.existing?.addedCourseName ?? _instance.course.name
          : null,
      note: _optional(_note),
      colorOverride: widget.existing?.colorOverride,
    );
    setState(() => _checkingConflict = true);
    try {
      if (!await widget.confirmSave(context, exception) || !mounted) return;
      Navigator.of(context).pop(exception);
    } finally {
      if (mounted) setState(() => _checkingConflict = false);
    }
  }

  String? _editedOverride(
      TextEditingController field, String? originalOverride, String? baseline) {
    if (widget.existing != null &&
        field.text == (originalOverride ?? baseline ?? '')) {
      return originalOverride;
    }
    return exceptionOverrideIfChanged(field.text, baseline);
  }

  @override
  Widget build(BuildContext context) {
    final needsTarget = _type != CourseExceptionType.cancel;
    final maxHeight = MediaQuery.sizeOf(context).height * .82;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Text(
                campusText(context, '临时变更 · {0}',
                    values: {'0': _instance.courseName}),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(_type == CourseExceptionType.add
                  ? campusText(context, '参考安排：{0} · 第 {1}-{2} 节', values: {
                      '0': campusWeekdayName(
                          context,
                          _instance.meetingRule?.weekday ??
                              _instance.date.weekday),
                      '1': _instance.startSection,
                      '2': _instance.endSection
                    })
                  : campusText(context, '原安排：{0}-{1}-{2} · 第 {3}-{4} 节',
                      values: {
                          '0': _instance.date.year,
                          '1': _instance.date.month,
                          '2': _instance.date.day,
                          '3': _instance.startSection,
                          '4': _instance.endSection
                        })),
              const SizedBox(height: 16),
              DropdownButtonFormField<CourseExceptionType>(
                initialValue: _type,
                decoration:
                    InputDecoration(labelText: campusText(context, '变更类型')),
                items: [
                  DropdownMenuItem(
                    value: CourseExceptionType.move,
                    child: Text(campusText(context, '移动本次课程')),
                  ),
                  DropdownMenuItem(
                    value: CourseExceptionType.cancel,
                    child: Text(campusText(context, '停止本次课程')),
                  ),
                  DropdownMenuItem(
                    value: CourseExceptionType.add,
                    child: Text(campusText(context, '临时增加一次课程')),
                  ),
                ],
                onChanged: widget.existing != null
                    ? null
                    : (value) {
                        if (value != null) setState(() => _type = value);
                      },
              ),
              if (needsTarget) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(campusText(context, '目标日期')),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(_targetDate),
                  ),
                  onTap: _pickDate,
                ),
                SectionRangeSelector(
                  startSection: _startSection,
                  endSection: _endSection,
                  onChanged: (selection) => setState(() {
                    _startSection = selection.start;
                    _endSection = selection.end;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _teacher,
                  decoration: InputDecoration(
                      labelText:
                          campusText(context, CourseFieldLabels.teacher)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _campus,
                  decoration: InputDecoration(
                      labelText: campusText(context, CourseFieldLabels.campus)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _room,
                  decoration: InputDecoration(
                      labelText: campusText(context, CourseFieldLabels.room)),
                ),
              ],
              const SizedBox(height: 12),
              CompactNotesField(
                  controller: _note, label: campusText(context, '备注（可选）')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _checkingConflict ? null : _submit,
                child: Text(campusText(context, '保存临时变更')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
