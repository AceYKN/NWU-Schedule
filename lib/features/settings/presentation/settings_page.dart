import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/backup/schedule_backup.dart';
import '../../../domain/semester/semester.dart';
import '../../../infrastructure/backup/backup_file_service.dart';

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
                value: ref.watch(notificationEnabledProvider).asData?.value ??
                    false,
                onChanged: (enabled) =>
                    _setNotificationEnabled(context, ref, enabled),
                title: const Text('上课提醒'),
                subtitle: const Text('只使用本地通知，不上传课程数据'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('提前时间'),
                subtitle: const Text('统一应用于所有课程'),
                trailing: Text(
                  '${ref.watch(notificationLeadMinutesProvider).asData?.value ?? notificationDefaultLeadMinutes} 分钟',
                ),
                onTap: () => _selectNotificationLead(context, ref),
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
                onTap: () => _exportBackup(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入完整备份'),
                onTap: () => _restoreBackup(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('清除所有数据'),
                onTap: () => _clearAllData(context, ref),
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

Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
  try {
    final backup =
        await ref.read(scheduleDataRepositoryProvider).createBackup();
    final saved = await const BackupFileService().save(backup.encode());
    if (!context.mounted) return;
    _showMessage(context, saved ? '备份已导出' : '已取消导出');
  } catch (error) {
    if (context.mounted) _showMessage(context, '备份导出失败：$error');
  }
}

Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
  try {
    final content = await const BackupFileService().pick();
    if (content == null || !context.mounted) return;
    final backup = ScheduleBackup.decode(content);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认恢复备份？'),
        content: Text(
          '恢复将替换当前本地数据。\n\n'
          '${backup.semesters.length} 个学期 · '
          '${backup.courses.length} 门课程 · '
          '${backup.exceptions.length} 条调课记录',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(scheduleDataRepositoryProvider).restoreBackup(backup);
    ref.invalidate(scheduleLoadProvider);
    if (context.mounted) _showMessage(context, '备份已恢复');
  } catch (error) {
    if (context.mounted) _showMessage(context, '备份恢复失败：$error');
  }
}

Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('清除所有数据？'),
      content: const Text('这会删除本地学期、课程、调课记录、设置和导入快照，且无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('清除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).clearAllData();
    ref.invalidate(scheduleLoadProvider);
    if (context.mounted) _showMessage(context, '本地数据已清除');
  } catch (error) {
    if (context.mounted) _showMessage(context, '清除数据失败：$error');
  }
}

Future<void> _setNotificationEnabled(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final service = ref.read(notificationServiceProvider);
    if (!enabled) {
      await repository.setSetting('notifications.enabled', 'false');
      await service.clear();
      ref.invalidate(notificationEnabledProvider);
      if (context.mounted) _showMessage(context, '上课提醒已关闭');
      return;
    }
    final granted = await service.requestPermission();
    if (!granted) {
      if (context.mounted) _showMessage(context, '未获得通知权限，提醒未开启');
      return;
    }
    await repository.setSetting('notifications.enabled', 'true');
    ref.invalidate(notificationEnabledProvider);
    await rebuildNotificationsForCurrentSchedule(
      repository: repository,
      service: service,
      state: ref.read(scheduleLoadProvider).asData?.value,
    );
    if (context.mounted) _showMessage(context, '上课提醒已开启');
  } catch (error) {
    if (context.mounted) _showMessage(context, '设置提醒失败：$error');
  }
}

Future<void> _selectNotificationLead(
  BuildContext context,
  WidgetRef ref,
) async {
  final selected = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('选择提前时间')),
          for (final minutes in const [5, 10, 15, 20, 30, 60])
            ListTile(
              title: Text('$minutes 分钟'),
              onTap: () => Navigator.pop(sheetContext, minutes),
            ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    await repository.setSetting('notifications.leadMinutes', '$selected');
    ref.invalidate(notificationLeadMinutesProvider);
    if (await repository.getSetting('notifications.enabled') == 'true') {
      await rebuildNotificationsForCurrentSchedule(
        repository: repository,
        service: ref.read(notificationServiceProvider),
        state: ref.read(scheduleLoadProvider).asData?.value,
      );
    }
    if (context.mounted) _showMessage(context, '提醒时间已更新');
  } catch (error) {
    if (context.mounted) _showMessage(context, '更新提醒时间失败：$error');
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
