import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../domain/course/course.dart';

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
          SnackBar(content: Text('操作失败：$error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('无法读取课程')),
      data: (value) {
        if (value is! ScheduleReady) {
          return const Center(child: Text('请先创建或导入学期'));
        }
        final courses = List<Course>.of(value.engine.courses)
          ..sort((a, b) => a.name.compareTo(b.name));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            Row(children: [
              IconButton(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回设置',
              ),
              Text('课程管理', style: Theme.of(context).textTheme.headlineSmall),
            ]),
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
          ],
        );
      },
    );
  }
}
