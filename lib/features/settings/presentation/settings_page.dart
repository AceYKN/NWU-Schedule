import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(scheduleEngineProvider);
    final definition = engine.calendarEngine.definition;
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
                subtitle: Text(
                  '${definition.academicYear} 第${definition.term}学期',
                ),
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
