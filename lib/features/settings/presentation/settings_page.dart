import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/semester/semester.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(scheduleLoadProvider);
    final currentSemester = load.when(
      data: (state) => switch (state) {
        ScheduleReady(:final semester) => semester.label,
        ScheduleCalendarMissing(:final semester) => '${semester.label} · 校历待更新',
        ScheduleNoSemester() => '尚未导入学期',
      },
      loading: () => '正在读取本地数据',
      error: (error, stackTrace) => '暂时无法读取本地数据',
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '学期与课表'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('当前学期'),
                subtitle: Text(currentSemester),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectSemester(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('新建本地学期'),
                subtitle: const Text('根据已收录校历创建空课表'),
                onTap: () => _createSemester(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('课程管理'),
                subtitle: const Text('编辑、隐藏、删除或恢复课程'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/courses/manage'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('从教务系统导入'),
                subtitle: const Text('正方 WebView 导入将在后续阶段接入'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPrototypeMessage(context, '教务导入'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '提醒'),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: false,
                onChanged: (_) => _showPrototypeMessage(context, '上课提醒'),
                title: const Text('上课提醒'),
                subtitle: const Text('默认提前 15 分钟，统一规划本地通知'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.timer_outlined),
                title: Text('提前时间'),
                trailing: Text('15 分钟'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '外观'),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('主题'),
                subtitle: Text('跟随系统 · 官方主题预留'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  children: officialThemes
                      .map(
                        (theme) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: theme.seedColor,
                          ),
                          label: Text(theme.name),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '数据与隐私'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出完整备份'),
                subtitle: const Text('只包含本地课程和设置，不包含账号或 Cookie'),
                onTap: () => _showPrototypeMessage(context, '备份导出'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入完整备份'),
                onTap: () => _showPrototypeMessage(context, '备份恢复'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('清除所有数据'),
                onTap: () => _showPrototypeMessage(context, '清除数据'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '关于'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('西北大学课程表'),
            subtitle: Text('Android First · Local First · 无广告无账号'),
          ),
        ),
      ],
    );
  }
}

Future<void> _createSemester(BuildContext context, WidgetRef ref) async {
  try {
    final calendarRepository = ref.read(bundledCalendarRepositoryProvider);
    final repository = ref.read(scheduleDataRepositoryProvider);
    final existing = await repository.loadSemesters();
    final entries = (await calendarRepository.listCalendars())
        .where((entry) => !existing.any((semester) => semester.id == entry.id))
        .toList();
    if (!context.mounted) return;
    if (entries.isEmpty) {
      _showMessage(context, '当前版本没有可新建的学期');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择校历')),
            ...entries.map((entry) => ListTile(
                  title: Text(entry.label ?? entry.id),
                  subtitle: Text(entry.id),
                  onTap: () => Navigator.pop(sheetContext, entry.id),
                )),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    final definition = await calendarRepository.findById(selected);
    if (definition == null) throw StateError('校历不存在：$selected');
    final termLabel = switch (definition.term) {
      1 => '第一学期',
      2 => '第二学期',
      _ => '夏季学期',
    };
    await repository.saveSemester(Semester(
      id: definition.id,
      academicYear: definition.academicYear,
      term: SemesterTerm.values[definition.term - 1],
      label: '${definition.academicYear} $termLabel',
      calendarId: definition.id,
      createdAt: DateTime.now(),
    ));
    await repository.setPreferredSemesterId(selected);
    if (context.mounted) _showMessage(context, '学期已创建，可以手动添加课程');
  } catch (error) {
    if (context.mounted) _showMessage(context, '创建学期失败：$error');
  }
}

Future<void> _selectSemester(BuildContext context, WidgetRef ref) async {
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final semesters = await repository.loadSemesters();
    if (!context.mounted) return;
    if (semesters.isEmpty) {
      _showMessage(context, '请先创建或导入学期');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('切换学期')),
            ...semesters.map((semester) => ListTile(
                  title: Text(semester.label),
                  subtitle: Text(semester.calendarId == null ? '缺少校历' : '本地课表'),
                  onTap: () => Navigator.pop(sheetContext, semester.id),
                )),
          ],
        ),
      ),
    );
    if (selected != null) await repository.setPreferredSemesterId(selected);
  } catch (error) {
    if (context.mounted) _showMessage(context, '切换学期失败：$error');
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

void _showPrototypeMessage(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature将在对应开发阶段接入')),
  );
}
