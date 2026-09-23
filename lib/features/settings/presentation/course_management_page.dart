import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/errors/app_error.dart';
import '../../shared/presentation/app_page_header.dart';

class CourseManagementPage extends ConsumerWidget {
  const CourseManagementPage({super.key});

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
          title: const Text('删除这门课程？'),
          content: const Text('教务课程会保留删除记录，手动课程会从本机移除。'),
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
          SnackBar(content: Text(nwuUserMessage(error, action: '操作失败'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(nwuUserMessage(error, action: '读取课程失败')),
      ),
      data: (value) {
        if (value is! ScheduleReady) {
          return const Center(child: Text('请先创建或导入学期'));
        }
        final courses = List<Course>.of(value.engine.courses)
          ..sort((a, b) => a.name.compareTo(b.name));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            AppPageHeader(
              title: '课程管理',
              showBack: true,
              onBack: () => context.go('/settings'),
            ),
            const SizedBox(height: 8),
            Text(value.semester.label),
            const SizedBox(height: 16),
            if (courses.isEmpty) const Center(child: Text('这个学期还没有课程')),
            ...courses.map((course) => Card(
                  child: ListTile(
                    title: Text(course.name),
                    subtitle: Text([
                      course.sourceType == CourseSourceType.manual
                          ? '手动添加'
                          : '教务导入',
                      if (course.deleted) '已删除',
                      if (course.hidden) '已隐藏',
                    ].join(' · ')),
                    trailing: PopupMenuButton<String>(
                      tooltip: '课程操作',
                      onSelected: (action) =>
                          _act(context, ref, course, action),
                      itemBuilder: (context) => [
                        if (course.deleted)
                          const PopupMenuItem(
                              value: 'restore', child: Text('恢复课程'))
                        else ...[
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(
                            value: course.hidden ? 'show' : 'hide',
                            child: Text(course.hidden ? '取消隐藏' : '隐藏'),
                          ),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除')),
                        ],
                      ],
                    ),
                  ),
                )),
            if (value.engine.exceptions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '临时变更',
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
                    title: Text(_exceptionTitle(exception)),
                    subtitle: Text(_exceptionSubtitle(exception)),
                    trailing: IconButton(
                      tooltip: '撤销临时变更',
                      icon: const Icon(Icons.undo_outlined),
                      onPressed: () => _deleteException(
                        context,
                        ref,
                        exception,
                      ),
                    ),
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

Future<void> _deleteException(
  BuildContext context,
  WidgetRef ref,
  CourseException exception,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('撤销临时变更？'),
      content: const Text('删除后会恢复原始课表安排。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('撤销'),
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
        const SnackBar(content: Text('临时变更已撤销')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nwuUserMessage(error, action: '撤销失败'))),
      );
    }
  }
}

String _exceptionTitle(CourseException exception) => switch (exception.type) {
      CourseExceptionType.move => 'MOVE · 调课',
      CourseExceptionType.cancel => 'CANCEL · 停课',
      CourseExceptionType.add => 'ADD · 临时加课',
    };

String _exceptionSubtitle(CourseException exception) {
  final source = _shortDate(exception.sourceDate);
  final target = _shortDate(exception.targetDate);
  return switch (exception.type) {
    CourseExceptionType.move =>
      '$source → $target · 第 ${exception.targetStartSection}-${exception.targetEndSection} 节',
    CourseExceptionType.cancel => '$source · 本次课程已取消',
    CourseExceptionType.add =>
      '$target · 第 ${exception.targetStartSection}-${exception.targetEndSection} 节 · ${exception.addedCourseName ?? '课程'}',
  };
}

String _shortDate(DateTime? date) => date == null
    ? '未指定日期'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
