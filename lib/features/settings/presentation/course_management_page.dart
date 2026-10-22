import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/campus_design.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../shared/presentation/app_page_header.dart';
import '../../shared/presentation/course_card.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

class CourseManagementPage extends ConsumerStatefulWidget {
  const CourseManagementPage({super.key});

  @override
  ConsumerState<CourseManagementPage> createState() =>
      _CourseManagementPageState();
}

class _CourseManagementPageState extends ConsumerState<CourseManagementPage> {
  final _busy = <String>{};

  Future<void> _run(String id, Future<void> Function() operation) async {
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await operation();
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Course course,
    String action,
  ) async {
    if (action == 'edit') {
      context.go('/course/${Uri.encodeComponent(course.id)}/edit');
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(campusText(dialogContext, '删除这门课程？')),
          content: Text(campusText(dialogContext, '教务课程会保留删除记录，手动课程会从本机移除。')),
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
      if (confirmed != true || !context.mounted) return;
    }
    try {
      final repository = ref.read(scheduleDataRepositoryProvider);
      switch (action) {
        case 'hide':
          await repository.setCourseHidden(course.id, true);
        case 'show':
          await repository.setCourseHidden(course.id, false);
        case 'delete':
          await repository.deleteCourse(course.id);
        case 'restore':
          await repository.restoreImportedCourse(course.id);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(campusUserMessage(context, error,
                  action: campusText(context, '操作失败')))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(campusUserMessage(context, error,
            action: campusText(context, '读取课程失败'))),
        TextButton(
            onPressed: () => ref.invalidate(scheduleLoadProvider),
            child: Text(campusText(context, '重试读取'))),
      ])),
      data: (value) {
        if (value is ScheduleCalendarMissing) {
          return Center(
              child: Text(campusText(context, '学期已保存，但缺少校历，请更新应用后重试')));
        }
        if (value is! ScheduleReady) {
          return Center(child: Text(campusText(context, '请先创建或导入学期')));
        }
        final courses = List<Course>.of(value.engine.courses)
          ..sort((a, b) => a.name.compareTo(b.name));
        final arrangementsByCourse = <String, List<MeetingRule>>{};
        for (final rule in value.engine.meetingRules) {
          arrangementsByCourse.putIfAbsent(rule.courseId, () => []).add(rule);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            AppPageHeader(
              title: campusText(context, '课程管理'),
              showBack: true,
              onBack: () => context.go('/settings'),
            ),
            const SizedBox(height: 8),
            Text(value.semester.label),
            const SizedBox(height: 16),
            if (courses.isEmpty)
              Center(child: Text(campusText(context, '这个学期还没有课程'))),
            ...courses.map((course) {
              final arrangements =
                  arrangementsByCourse[course.id] ?? const <MeetingRule>[];
              return Card(
                child: ListTile(
                  isThreeLine: arrangements.isNotEmpty,
                  title: Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        [
                          course.sourceType == CourseSourceType.manual
                              ? campusText(context, '手动添加')
                              : campusText(context, '教务导入'),
                          campusText(context, '{0} 个上课安排',
                              values: {'0': arrangements.length}),
                          if (course.deleted) campusText(context, '已删除'),
                          if (course.hidden) campusText(context, '已停用（同时停止提醒）'),
                        ].join(' · '),
                      ),
                      for (final rule in arrangements.take(2))
                        Text(
                          _arrangementSummary(context, rule),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (arrangements.length > 2)
                        Text(campusText(context, '还有 {0} 个安排',
                            values: {'0': arrangements.length - 2})),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: campusText(context, '课程操作'),
                    enabled: !_busy.contains(course.id),
                    onSelected: (action) => _run(
                        course.id, () => _act(context, ref, course, action)),
                    itemBuilder: (context) => [
                      if (course.deleted)
                        PopupMenuItem(
                          value: 'restore',
                          child: Text(campusText(context, '恢复课程')),
                        )
                      else ...[
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(campusText(context, '编辑整门课程')),
                        ),
                        PopupMenuItem(
                          value: course.hidden ? 'show' : 'hide',
                          child: Text(course.hidden
                              ? campusText(context, '启用课程及提醒')
                              : campusText(context, '停用课程及提醒')),
                        ),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text(campusText(context, '删除'))),
                      ],
                    ],
                  ),
                ),
              );
            }),
            if (value.engine.exceptions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                campusText(context, '临时变更'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: scheduleThemeTokensOf(context).sectionTitleSize,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ...value.engine.exceptions.map(
                (exception) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.edit_calendar_outlined),
                    title: Text(
                        '${_exceptionCourseName(exception, courses)} · ${campusText(context, _exceptionTitle(exception))}'),
                    subtitle: Text(_exceptionSubtitle(context, exception)),
                    onTap: _busy.contains(exception.id)
                        ? null
                        : () => _run(
                            exception.id,
                            () => editCourseException(
                                context: context,
                                ref: ref,
                                exception: exception)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: campusText(context, '编辑临时变更'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: _busy.contains(exception.id)
                              ? null
                              : () => _run(
                                  exception.id,
                                  () => editCourseException(
                                      context: context,
                                      ref: ref,
                                      exception: exception))),
                      IconButton(
                        tooltip: campusText(context, '撤销临时变更'),
                        icon: const Icon(Icons.undo_outlined),
                        onPressed: _busy.contains(exception.id)
                            ? null
                            : () => _run(
                                exception.id,
                                () =>
                                    _deleteException(context, ref, exception)),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _exceptionCourseName(CourseException exception, List<Course> courses) {
  for (final course in courses) {
    if (course.id == exception.courseId) return course.name;
  }
  return exception.addedCourseName ?? '课程来源已不可用';
}

String _arrangementSummary(BuildContext context, MeetingRule rule) {
  const weekdays = '一二三四五六日';
  final parts = [
    CampusDesign.maybeOf(context) == null
        ? '周${weekdays[rule.weekday - 1]} ${rule.startSection}-${rule.endSection}节'
        : '${CampusDesign.weekdayName(rule.weekday)} ${rule.startSection}–${rule.endSection}時限',
    if (rule.weekMask.rawText.trim().isNotEmpty)
      campusWeekText(context, rule.weekMask.rawText.trim()),
    if (rule.room?.trim().isNotEmpty == true)
      rule.room!.trim()
    else if (rule.campus?.trim().isNotEmpty == true)
      rule.campus!.trim(),
  ];
  return parts.join(' · ');
}

Future<void> _deleteException(
  BuildContext context,
  WidgetRef ref,
  CourseException exception,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(campusText(dialogContext, '撤销临时变更？')),
      content: Text(campusText(dialogContext, '删除后会恢复原始课表安排。')),
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
  if (confirmed != true || !context.mounted) return;
  try {
    await ref
        .read(scheduleDataRepositoryProvider)
        .deleteException(exception.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(campusText(context, '临时变更已撤销'))));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(campusUserMessage(context, error,
                action: campusText(context, '撤销失败')))),
      );
    }
  }
}

String _exceptionTitle(CourseException exception) => switch (exception.type) {
      CourseExceptionType.move => '调课',
      CourseExceptionType.cancel => '停课',
      CourseExceptionType.add => '临时加课',
    };

String _exceptionSubtitle(BuildContext context, CourseException exception) {
  final source = _shortDate(exception.sourceDate);
  final target = _shortDate(exception.targetDate);
  return switch (exception.type) {
    CourseExceptionType.move =>
      campusText(context, '原日期 {0} → 目标日期 {1} · 第 {2}-{3} 节', values: {
        '0': source,
        '1': target,
        '2': exception.targetStartSection,
        '3': exception.targetEndSection
      }),
    CourseExceptionType.cancel =>
      campusText(context, '原日期 {0} · 本次课程已取消', values: {'0': source}),
    CourseExceptionType.add => campusText(context, '目标日期 {0} · 第 {1}-{2} 节',
          values: {
            '0': target,
            '1': exception.targetStartSection,
            '2': exception.targetEndSection
          }),
  };
}

String _shortDate(DateTime? date) => date == null
    ? '未指定日期'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
