import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../../domain/semester/semester.dart';

class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_CourseDetail?>(
      future: _loadCourse(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final detail = snapshot.data;
        if (detail == null) {
          return const Center(child: Text('找不到这门课程'));
        }
        return _CourseDetail(
          semester: detail.semester,
          course: detail.course,
          rules: detail.rules,
        );
      },
    );
  }

  Future<_CourseDetail?> _loadCourse(WidgetRef ref) async {
    final repository = ref.read(scheduleDataRepositoryProvider);
    for (final semester in await repository.loadSemesters()) {
      final snapshot = await repository.loadSemester(semester.id);
      for (final course in snapshot.courses) {
        if (course.id == courseId) {
          return _CourseDetail(
            semester: semester,
            course: course,
            rules: snapshot.meetingRules
                .where((rule) => rule.courseId == course.id)
                .toList(growable: false),
          );
        }
      }
    }
    return null;
  }
}

class _CourseDetail extends StatelessWidget {
  const _CourseDetail({
    required this.semester,
    required this.course,
    required this.rules,
  });

  final Semester semester;
  final Course course;
  final List<MeetingRule> rules;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                '课程详情',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: '编辑课程',
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
                Text(
                  course.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text('${course.code ?? '无课程代码'} · ${semester.label}'),
                if (course.teachingClass != null) ...[
                  const SizedBox(height: 4),
                  Text('教学班：${course.teachingClass}'),
                ],
                if (course.credits != null || course.assessment != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (course.credits != null) '${course.credits} 学分',
                      if (course.assessment != null) course.assessment!,
                    ].join(' · '),
                  ),
                ],
                if (course.note != null && course.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('备注：${course.note}'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '上课安排',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (rules.isEmpty)
          const Card(child: ListTile(title: Text('暂无上课安排')))
        else
          ...rules.map(
            (rule) => Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  '${weekdayName(rule.weekday)} · 第 ${rule.startSection}-${rule.endSection} 节',
                ),
                subtitle: Text(
                  [
                    formatWeekMask(rule.weekMask),
                    if (rule.campus != null) rule.campus!,
                    if (rule.room != null) rule.room!,
                    if (rule.teacher != null) rule.teacher!,
                  ].join(' · '),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
