import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/campus_design.dart';
import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/constants.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/backup/schedule_backup.dart';
import '../../../domain/semester/semester.dart';
import '../../../domain/settings/appearance_preferences.dart';
import '../../../domain/settings/schedule_display_preferences.dart';
import '../../../infrastructure/backup/backup_file_service.dart';
import '../../../infrastructure/import/webview_session_service.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

const _backgroundRunningDescription =
    '将“西小课”的电池使用设为“不受限制”或“不优化”，可减少提醒和小组件更新延迟。';
const _backgroundRunningPromptKey = 'notifications.backgroundPromptShown';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    final currentSemester = load.when(
      data: (state) => switch (state) {
        ScheduleReady(:final semester) => semester.label,
        ScheduleCalendarMissing(:final semester) =>
          '${semester.label} · ${campusText(context, '校历待更新')}',
        ScheduleNoSemester() => campusText(context, '尚未导入学期'),
      },
      loading: () => campusText(context, '正在读取本地数据'),
      error: (error, stackTrace) => campusUserMessage(context, error,
          action: campusText(context, '读取本地数据失败')),
    );
    final selectedThemeId =
        ref.watch(themeIdProvider).asData?.value ?? officialThemes.first.id;
    final selectedTheme = officialThemes.firstWhere(
      (theme) => theme.id == selectedThemeId,
      orElse: () => officialThemes.first,
    );
    final selectedThemeMode =
        ref.watch(themeModeProvider).asData?.value ?? AppThemeMode.system;
    final failures = ref.watch(platformSyncFailuresProvider);
    final notificationStatus = ref.watch(notificationPlatformStatusProvider);
    final platform = notificationStatus.asData?.value;
    return IgnorePointer(
      ignoring: _busy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          if (_busy) Text(campusText(context, '正在处理…')),
          Text(
            campusText(context, '设置'),
            style: CampusDesign.maybeOf(context)?.heading(21) ??
                Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (failures.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sync_problem),
                title: Text(campusText(context, '平台同步尚未完成')),
                subtitle: Text(
                  campusText(context, '{0}{1}', values: {
                    '0': failures.contains('notifications')
                        ? campusText(context, '提醒排程或清理失败。')
                        : '',
                    '1': failures.contains('widget')
                        ? campusText(context, '小组件更新或清理失败。')
                        : ''
                  }),
                ),
                trailing: TextButton(
                  onPressed: () => _run(() => _retryPlatformSync(context, ref)),
                  child: Text(campusText(context, '重试')),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '学期与课表')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.download_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(campusText(context, '从教务系统导入')),
                  subtitle: Text(campusText(context, '登录教务系统，读取个人课表')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/import'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_outlined),
                  title: Text(campusText(context, '切换学期')),
                  subtitle: Text(currentSemester),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _run(() => _selectSemester(context, ref)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(campusText(context, '课程管理')),
                  subtitle: Text(campusText(context, '编辑、隐藏、删除或恢复课程')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/courses/manage'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(campusText(context, '新建本地学期')),
                  subtitle: Text(campusText(context, '根据已收录校历创建空课表')),
                  onTap: () => _run(() => _createSemester(context, ref)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '课表显示')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.view_week_outlined),
              title: Text(campusText(context, '课表显示')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/schedule-display'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '提醒')),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: ref.watch(notificationEnabledProvider).asData?.value ??
                      false,
                  onChanged: (enabled) => _run(
                    () => _setNotificationEnabled(context, ref, enabled),
                  ),
                  title: Text(campusText(context, '上课提醒')),
                  subtitle: Text(campusText(context, '只使用本地通知，不上传课程数据')),
                ),
                ListTile(
                  title: Text(campusText(context, '提醒状态')),
                  trailing: platform?['replenishFailed'] == true
                      ? TextButton(
                          onPressed: () =>
                              _run(() => _retryPlatformSync(context, ref)),
                          child: Text(campusText(context, '重试')),
                        )
                      : null,
                  subtitle: Text(
                    platform == null
                        ? campusText(context, '暂时无法读取系统通知状态；系统省电可能延迟提醒')
                        : campusText(
                            context, '{0} · {1}\n{2}\n系统可能延迟送达，提前时间不保证准点',
                            values: {
                                '0': platform['systemAllowed'] == true
                                    ? campusText(context, '系统通知允许')
                                    : campusText(context, '系统通知已关闭'),
                                '1': platform['channelAllowed'] == true
                                    ? campusText(context, '提醒渠道允许')
                                    : campusText(context, '提醒渠道已关闭'),
                                '2': failures.contains('notifications') ||
                                        platform['replenishFailed'] == true
                                    ? campusText(context, '排程失败，请重试')
                                    : platform['planStored'] == true
                                        ? campusText(context, '本地提醒计划已保存')
                                        : campusText(context, '尚未保存提醒计划')
                              }),
                  ),
                  onTap: () =>
                      ref.invalidate(notificationPlatformStatusProvider),
                ),
                const Divider(height: 1),
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  ListTile(
                    leading: const Icon(Icons.battery_saver_outlined),
                    title: Text(campusText(context, '电池与后台设置')),
                    subtitle: Text(
                      campusText(context, '{0}\n{1}', values: {
                        '0': switch (platform?['batteryOptimizationIgnored']) {
                          true => campusText(context, '电池优化：已豁免'),
                          false => campusText(context, '电池优化：未豁免'),
                          _ => campusText(context, '电池优化：状态未知'),
                        },
                        '1': campusText(context, _backgroundRunningDescription)
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => _run(
                          () => _openBackgroundRunningSettings(context, ref),
                        ),
                        child: Text(campusText(context, '前往设置')),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(campusText(context, '提前时间')),
                  subtitle: Text(campusText(context, '统一应用于所有课程')),
                  trailing: Text(
                    campusText(context, '{0} 分钟', values: {
                      '0': ref
                              .watch(notificationLeadMinutesProvider)
                              .asData
                              ?.value ??
                          notificationDefaultLeadMinutes
                    }),
                  ),
                  onTap: () =>
                      _run(() => _selectNotificationLead(context, ref)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '外观')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(campusText(context, '模式')),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<AppThemeMode>(
                    segments: [
                      for (final mode in AppThemeMode.values)
                        ButtonSegment(
                            value: mode,
                            label: Text(campusText(context, mode.label))),
                    ],
                    selected: {selectedThemeMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        _run(
                          () => _selectThemeMode(context, ref, selection.first),
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.color_lens_outlined),
                  title: Text(campusText(context, '主题色')),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    children: officialThemes
                        .map(
                          (theme) => ChoiceChip(
                            selected: theme.id == selectedTheme.id,
                            onSelected: (selected) {
                              if (selected) {
                                _run(
                                  () => _selectTheme(context, ref, theme.id),
                                );
                              }
                            },
                            avatar: CircleAvatar(
                              backgroundColor: theme.seedColor,
                            ),
                            label: Text(campusText(context, theme.name)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '数据与隐私')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(campusText(context, '导出完整备份')),
                  subtitle:
                      Text(campusText(context, '只包含本地课程和设置，不包含账号或 Cookie')),
                  onTap: () => _run(() => _exportBackup(context, ref)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(campusText(context, '导入完整备份')),
                  onTap: () => _run(() => _restoreBackup(context, ref)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(campusText(context, '清除所有数据')),
                  onTap: () => _run(() => _clearAllData(context, ref)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: campusText(context, '关于')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(campusText(context, nwuAppName)),
                  subtitle: Text(campusText(
                      context, 'Android First · Local First · 无广告无账号')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(campusText(context, '应用版本')),
                  subtitle: Text(nwuAppVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(campusText(context, '隐私说明')),
                  subtitle: Text(campusText(context, '本地存储，仅在主动导入时访问教务系统')),
                  onTap: () => _showPrivacyInfo(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(campusText(context, '开源许可证')),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: nwuAppName,
                    applicationVersion: nwuAppVersion,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showPrivacyInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(campusText(dialogContext, '隐私说明')),
      content: SingleChildScrollView(
        child: Text(
          campusText(dialogContext,
              '课程、校历、提醒和 Widget 数据只保存在本机。应用没有账号系统、广告、统计或课表后端。\n\n只有你主动进入“从教务系统导入”时，临时 WebView 才访问西北大学官方教务域名。导入结束后会清理 Cookie、缓存和页面存储；应用不读取或保存学号、密码、登录令牌。\n\n诊断信息和备份都由你主动导出，应用不会自动上传。'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(campusText(dialogContext, '知道了')),
        ),
      ],
    ),
  );
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
      _showMessage(context, campusText(context, '当前版本没有可新建的学期'));
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(campusText(sheetContext, '选择校历'))),
            ...entries.map(
              (entry) => ListTile(
                title: Text(entry.label ?? entry.id),
                subtitle: Text(entry.id),
                onTap: () => Navigator.pop(sheetContext, entry.id),
              ),
            ),
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
    await repository.saveSemester(
      Semester(
        id: definition.id,
        academicYear: definition.academicYear,
        term: SemesterTerm.values[definition.term - 1],
        label: '${definition.academicYear} $termLabel',
        calendarId: definition.id,
        calendarRevision: definition.revision,
        createdAt: DateTime.now(),
      ),
    );
    await repository.setPreferredSemesterId(selected);
    if (context.mounted) {
      _showMessage(context, campusText(context, '学期已创建，可以手动添加课程'));
    }
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '创建学期失败')));
    }
  }
}

Future<void> _selectSemester(BuildContext context, WidgetRef ref) async {
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final semesters = await repository.loadSemesters();
    if (!context.mounted) return;
    if (semesters.isEmpty) {
      _showMessage(context, campusText(context, '请先创建或导入学期'));
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(campusText(sheetContext, '切换学期'))),
            ...semesters.map(
              (semester) => ListTile(
                title: Text(semester.label),
                subtitle: Text(semester.calendarId == null
                    ? campusText(sheetContext, '缺少校历')
                    : campusText(sheetContext, '本地课表')),
                onTap: () => Navigator.pop(sheetContext, semester.id),
                trailing: IconButton(
                  tooltip: campusText(sheetContext, '删除学期'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      _deleteSemester(context, sheetContext, ref, semester),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await repository.setPreferredSemesterId(selected);
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '切换学期失败')));
    }
  }
}

Future<void> _deleteSemester(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  Semester semester,
) async {
  final confirmed = await showDialog<bool>(
    context: pageContext,
    builder: (dialogContext) => AlertDialog(
      title: Text(
          campusText(dialogContext, '删除{0}？', values: {'0': semester.label})),
      content:
          Text(campusText(dialogContext, '该学期的课程、临时变更、导入快照和删除记录都会被移除，且无法撤销。')),
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
  if (confirmed != true || !pageContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).deleteSemester(semester.id);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (pageContext.mounted) {
      _showMessage(pageContext, campusText(pageContext, '学期已删除'));
    }
  } catch (error) {
    if (pageContext.mounted) {
      _showMessage(
          pageContext,
          campusUserMessage(pageContext, error,
              action: campusText(pageContext, '删除学期失败')));
    }
  }
}

Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
  try {
    final themeId =
        ref.read(themeIdProvider).asData?.value ?? officialThemes.first.id;
    final themeMode =
        ref.read(themeModeProvider).asData?.value ?? AppThemeMode.system;
    final display =
        ref.read(scheduleDisplayPreferencesProvider).asData?.value ??
            const ScheduleDisplayPreferences.defaults();
    final backup = await ref.read(scheduleDataRepositoryProvider).createBackup(
      appearance: {
        'themeId': themeId,
        'themeMode': themeMode.name,
        'scheduleDisplay': {
          'showWeekend': display.showWeekend,
          'showTeacher': display.showTeacher,
          'showCampus': display.showCampus,
          'showInactiveCourses': display.showInactiveCourses,
          'showPeriodTimes': display.showPeriodTimes,
          'highlightCurrentPeriod': display.highlightCurrentPeriod,
          'showBackToCurrentWeekFab': display.showBackToCurrentWeekFab,
          'hiddenCourseIds': display.hiddenCourseIds.toList(),
        },
      },
    );
    final saved = await const BackupFileService().save(
      backup.encode(),
      suggestedName: 'nwu-schedule-backup.json',
    );
    if (!context.mounted) return;
    _showMessage(context,
        saved ? campusText(context, '备份已导出') : campusText(context, '已取消导出'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '备份导出失败')));
    }
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
        title: Text(campusText(dialogContext, '确认恢复备份？')),
        content: Text(
          campusText(
              dialogContext, '恢复将替换当前本地数据。\n\n{0} 个学期 · {1} 门课程 · {2} 条调课记录',
              values: {
                '0': backup.semesters.length,
                '1': backup.courses.length,
                '2': backup.exceptions.length
              }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(campusText(dialogContext, '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(campusText(dialogContext, '确认恢复')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repository = ref.read(scheduleDataRepositoryProvider);
    await repository.restoreBackup(backup);
    ref.invalidate(themeIdProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(scheduleDisplayPreferencesProvider);
    ref.invalidate(onboardingCompletedProvider);
    ref.invalidate(notificationEnabledProvider);
    ref.invalidate(notificationLeadMinutesProvider);
    ref.invalidate(scheduleLoadProvider);
    if (context.mounted) _showMessage(context, campusText(context, '备份已恢复'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '备份恢复失败')));
    }
  }
}

Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(campusText(dialogContext, '清除所有数据？')),
      content:
          Text(campusText(dialogContext, '这会删除本地学期、课程、调课记录、设置和导入快照，且无法撤销。')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(campusText(dialogContext, '取消')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(campusText(dialogContext, '清除')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).clearAllData();
    await _bestEffort(
      () => ref.read(notificationTaskQueueProvider).schedule(null),
    );
    await _bestEffort(() => ref.read(widgetTaskQueueProvider).schedule(null));
    await _bestEffort(() async {
      await WebViewCookieManager().clearCookies();
    });
    await _bestEffort(const WebViewSessionService().clear);
    ref.invalidate(themeIdProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(scheduleDisplayPreferencesProvider);
    ref.invalidate(onboardingCompletedProvider);
    ref.invalidate(notificationEnabledProvider);
    ref.invalidate(notificationLeadMinutesProvider);
    ref.invalidate(scheduleLoadProvider);
    if (context.mounted) {
      context.go('/');
      if (ref.read(platformSyncFailuresProvider).isNotEmpty) {
        _showMessage(context, campusText(context, '本地数据已清除，平台清理失败，可在设置中重试'));
      }
    }
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '清除数据失败')));
    }
  }
}

Future<void> _bestEffort(Future<void> Function() operation) async {
  try {
    await operation();
  } on Object {
    // Optional platform work must not undo a successful local operation.
  }
}

Future<ScheduleLoadState> _loadScheduleForSync(WidgetRef ref) async {
  ref.invalidate(scheduleLoadProvider);
  final state = await ref.read(scheduleLoadProvider.future);
  if (state is ScheduleCalendarMissing) throw const CalendarMissingError();
  return state;
}

Future<void> _retryPlatformSync(BuildContext context, WidgetRef ref) async {
  late final ScheduleLoadState state;
  try {
    state = await _loadScheduleForSync(ref);
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '读取课表失败，已保留现有平台数据')));
    }
    return;
  }
  try {
    if (!context.mounted) return;
    ref.read(notificationServiceProvider).invalidateCachedPlan();
    await Future.wait([
      ref.read(notificationTaskQueueProvider).schedule(state),
      ref.read(widgetTaskQueueProvider).schedule(state),
    ]);
    if (context.mounted) _showMessage(context, campusText(context, '平台同步已完成'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '平台同步失败，请稍后重试')));
    }
  }
}

Future<void> _selectTheme(
  BuildContext context,
  WidgetRef ref,
  String themeId,
) async {
  try {
    await ref
        .read(scheduleDataRepositoryProvider)
        .setSetting('appearance.themeId', themeId);
    ref.invalidate(themeIdProvider);
    if (context.mounted) _showMessage(context, campusText(context, '主题已切换'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '主题切换失败')));
    }
  }
}

Future<void> _selectThemeMode(
  BuildContext context,
  WidgetRef ref,
  AppThemeMode mode,
) async {
  try {
    await ref
        .read(scheduleDataRepositoryProvider)
        .setSetting('appearance.themeMode', mode.name);
    ref.invalidate(themeModeProvider);
    if (context.mounted) _showMessage(context, campusText(context, '外观模式已更新'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '更新外观模式失败')));
    }
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
      await ref.read(notificationTaskQueueProvider).schedule(null);
      ref.invalidate(notificationEnabledProvider);
      if (context.mounted) {
        _showMessage(context, campusText(context, '上课提醒已关闭'));
      }
      return;
    }
    final granted = await service.requestPermission();
    if (!granted) {
      await repository.setSetting('notifications.enabled', 'false');
      await _bestEffort(
        () => ref.read(notificationTaskQueueProvider).schedule(null),
      );
      ref.invalidate(notificationEnabledProvider);
      if (context.mounted) {
        _showMessage(context, campusText(context, '未获得通知权限，提醒未开启'));
      }
      return;
    }
    final state = await _loadScheduleForSync(ref);
    if (!context.mounted) return;
    await repository.setSetting('notifications.enabled', 'true');
    ref.invalidate(notificationEnabledProvider);
    await ref.read(notificationTaskQueueProvider).schedule(state);
    if (context.mounted) _showMessage(context, campusText(context, '上课提醒已开启'));
    // An optional battery hint must not turn a successful reminder setup into
    // a failure, even if reading or saving the hint state fails.
    await _bestEffort(() => _maybeShowBackgroundRunningPrompt(context, ref));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '设置提醒失败')));
    }
  }
}

Future<void> _openBackgroundRunningSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    await ref
        .read(notificationServiceProvider)
        .openBatteryOptimizationSettings();
    if (context.mounted) ref.invalidate(notificationPlatformStatusProvider);
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, campusText(context, '无法打开系统设置，请在手机设置中调整本应用的电池限制'));
    }
  }
}

Future<void> _maybeShowBackgroundRunningPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  final repository = ref.read(scheduleDataRepositoryProvider);
  if (await repository.getSetting(_backgroundRunningPromptKey) == 'true') {
    return;
  }
  if (!context.mounted) return;
  final status = await ref.read(notificationServiceProvider).status();
  if (!context.mounted || status?['batteryOptimizationIgnored'] != false) {
    return;
  }
  await repository.setSetting(_backgroundRunningPromptKey, 'true');
  if (!context.mounted) return;
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(campusText(dialogContext, '电池与后台设置')),
      content: SingleChildScrollView(
        child: Text(campusText(dialogContext, _backgroundRunningDescription)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(campusText(dialogContext, '暂时跳过')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(campusText(dialogContext, '前往设置')),
        ),
      ],
    ),
  );
  if (context.mounted && openSettings == true) {
    await _openBackgroundRunningSettings(context, ref);
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
          ListTile(title: Text(campusText(sheetContext, '选择提前时间'))),
          for (final minutes in const [5, 10, 15, 20, 30, 60])
            ListTile(
              title: Text(
                  campusText(sheetContext, '{0} 分钟', values: {'0': minutes})),
              onTap: () => Navigator.pop(sheetContext, minutes),
            ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final enabled =
        await repository.getSetting('notifications.enabled') == 'true';
    final state = enabled ? await _loadScheduleForSync(ref) : null;
    if (!context.mounted) return;
    await repository.setSetting('notifications.leadMinutes', '$selected');
    ref.invalidate(notificationLeadMinutesProvider);
    if (enabled) {
      await ref.read(notificationTaskQueueProvider).schedule(state);
    }
    if (context.mounted) _showMessage(context, campusText(context, '提醒时间已更新'));
  } catch (error) {
    if (context.mounted) {
      _showMessage(
          context,
          campusUserMessage(context, error,
              action: campusText(context, '更新提醒时间失败')));
    }
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
        style: CampusDesign.maybeOf(context)?.heading(15) ??
            Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
      ),
    );
  }
}
