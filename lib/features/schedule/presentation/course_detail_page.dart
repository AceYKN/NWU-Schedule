import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/navigation.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../../domain/semester/semester.dart';
import '../../../domain/schedule/schedule_data_repository.dart';
import '../../shared/presentation/app_page_header.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';
import '../../shared/presentation/course_color_resolver.dart';
import '../../shared/presentation/course_title.dart';

class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(courseSnapshotProvider(courseId));
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(campusText(context, '课程读取失败')),
        TextButton(
            onPressed: () => ref.invalidate(courseSnapshotProvider(courseId)),
            child: Text(campusText(context, '重试'))),
      ])),
      data: (snapshot) =>
          _detail(snapshot) ??
          Center(child: Text(campusText(context, '找不到这门课程'))),
    );
  }

  Widget? _detail(ScheduleDataSnapshot? snapshot) {
    if (snapshot == null) return null;
    for (final course in snapshot.courses) {
      if (course.id == courseId) {
        return _CourseDetail(
            semester: snapshot.semester,
            course: course,
            paletteIndex: CourseColorResolver.schedulePaletteForCourses(
                snapshot.courses)[course.id],
            rules: snapshot.meetingRules
                .where((r) => r.courseId == course.id)
                .toList(growable: false));
      }
    }
    for (final exception in snapshot.exceptions) {
      if (exception.id != courseId ||
          exception.type != CourseExceptionType.add ||
          exception.courseId != null) {
        continue;
      }
      final course = Course(
          id: exception.id,
          semesterId: snapshot.semester.id,
          sourceType: CourseSourceType.manual,
          name: exception.addedCourseName ?? '临时课程',
          note: exception.note,
          colorOverride: exception.colorOverride);
      final rule = MeetingRule(
          id: '${exception.id}-rule',
          courseId: course.id,
          weekday: exception.targetDate!.weekday,
          startSection: exception.targetStartSection!,
          endSection: exception.targetEndSection!,
          teacher: exception.teacherOverride,
          campus: exception.campusOverride,
          room: exception.roomOverride,
          weekMask: const WeekMask(0, rawText: '单次课程'));
      return _CourseDetail(
          semester: snapshot.semester,
          course: course,
          rules: [rule],
          exception: exception);
    }
    return null;
  }
}

class _CourseDetail extends StatelessWidget {
  const _CourseDetail({
    required this.semester,
    required this.course,
    required this.rules,
    this.paletteIndex,
    this.exception,
  });

  final Semester semester;
  final Course course;
  final List<MeetingRule> rules;
  final int? paletteIndex;
  final CourseException? exception;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        themeTokens.pagePadding,
        18,
        themeTokens.pagePadding,
        32,
      ),
      children: [
        AppPageHeader(
          title: campusText(context, '课程详情'),
          showBack: true,
          onBack: () => popOrGo(context, '/schedule'),
          actions: [
            if (exception == null)
              IconButton(
                tooltip: campusText(context, '编辑课程'),
                onPressed: () => context.go('/course/${course.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CourseTitle(
                  course: course,
                  paletteIndex: paletteIndex,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: themeTokens.pageTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  semester.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (exception != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    campusText(context, '临时加课 · {0}',
                        values: {'0': _formatDate(exception!.targetDate)}),
                  ),
                ],
                if (course.note != null && course.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(campusText(context, '备注：{0}',
                      values: {'0': course.note})),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          campusText(context, '上课安排'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: themeTokens.sectionTitleSize,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (rules.isEmpty)
          Card(child: ListTile(title: Text(campusText(context, '暂无上课安排'))))
        else
          ...rules.map((rule) {
            final startPeriod = const NwuPeriodRepository().byNumber(
              rule.startSection,
            );
            final endPeriod = const NwuPeriodRepository().byNumber(
              rule.endSection,
            );
            final location = [
              if (rule.campus?.trim().isNotEmpty == true) rule.campus!,
              if (rule.room?.trim().isNotEmpty == true) rule.room!,
            ].join(' · ');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${campusWeekdayName(context, rule.weekday)} · 第 ${rule.startSection}-${rule.endSection} 节',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    CourseDetailLine(
                      label: campusText(context, '时间'),
                      value: '${startPeriod.startLabel}–${endPeriod.endLabel}',
                    ),
                    CourseDetailLine(
                      label: campusText(context, '地点'),
                      value: location.isEmpty ? '地点待补充' : location,
                    ),
                    if (rule.teacher?.trim().isNotEmpty == true)
                      CourseDetailLine(
                          label: campusText(context, '教师'),
                          value: rule.teacher!),
                    CourseDetailLine(
                      label: campusText(context, '周次'),
                      value: exception == null
                          ? formatWeekMask(rule.weekMask)
                          : '单次课程 · ${_formatDate(exception!.targetDate)}',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '日期待补充';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
