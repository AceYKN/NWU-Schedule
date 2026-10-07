import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../domain/settings/schedule_display_preferences.dart';
import '../../../domain/errors/app_error.dart';
import '../../shared/presentation/app_page_header.dart';

class ScheduleDisplaySettingsPage extends ConsumerStatefulWidget {
  const ScheduleDisplaySettingsPage({super.key});

  @override
  ConsumerState<ScheduleDisplaySettingsPage> createState() =>
      _ScheduleDisplaySettingsPageState();
}

class _ScheduleDisplaySettingsPageState
    extends ConsumerState<ScheduleDisplaySettingsPage> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nwuUserMessage(error, action: '更新课表显示失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences =
        ref.watch(scheduleDisplayPreferencesProvider).asData?.value ??
            const ScheduleDisplayPreferences.defaults();
    final courseNames = <String, String>{};
    final loaded = ref.watch(scheduleLoadProvider).asData?.value;
    if (loaded is ScheduleReady) {
      for (final course in loaded.engine.courses) {
        courseNames[course.id] = course.name;
      }
    }
    return IgnorePointer(
      ignoring: _busy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          if (_busy) const Text('正在处理…'),
          AppPageHeader(
            title: '课表显示',
            showBack: true,
            onBack: () => context.go('/settings'),
          ),
          const SizedBox(height: 8),
          Text(
            '预览',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: scheduleThemeTokensOf(context).sectionTitleSize,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _SchedulePreview(preferences: preferences),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                _PreferenceSwitch(
                  title: '始终显示周末',
                  subtitle: '关闭时，有周末课程的周会提示你临时查看周末',
                  value: preferences.showWeekend,
                  onChanged: (value) =>
                      _run(() => _save(ref, 'showWeekend', value)),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '显示教师',
                  value: preferences.showTeacher,
                  onChanged: (value) =>
                      _run(() => _save(ref, 'showTeacher', value)),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '显示校区',
                  subtitle: '关闭后仅显示教室',
                  value: preferences.showCampus,
                  onChanged: (value) =>
                      _run(() => _save(ref, 'showCampus', value)),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '显示非本周课程',
                  value: preferences.showInactiveCourses,
                  onChanged: (value) =>
                      _run(() => _save(ref, 'showInactiveCourses', value)),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '显示节次时间',
                  value: preferences.showPeriodTimes,
                  onChanged: (value) =>
                      _run(() => _save(ref, 'showPeriodTimes', value)),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '高亮当前节次',
                  value: preferences.highlightCurrentPeriod,
                  onChanged: (value) =>
                      _save(ref, 'highlightCurrentPeriod', value),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  title: '显示“返回本周”按钮',
                  value: preferences.showBackToCurrentWeekFab,
                  onChanged: (value) =>
                      _save(ref, 'showBackToCurrentWeekFab', value),
                ),
              ],
            ),
          ),
          if (preferences.hiddenCourseIds.isNotEmpty) ...[
            const SizedBox(height: 20),
            _HiddenCoursesCard(
              courseIds: preferences.hiddenCourseIds,
              courseNames: courseNames,
              onRestore: (courseId) => _run(
                () => _restoreHidden(
                  context,
                  ref,
                  courseId,
                  courseNames[courseId] ?? courseId,
                ),
              ),
              onRestoreAll: () => _run(
                () => _restoreAllHidden(
                  context,
                  ref,
                  preferences.hiddenCourseIds,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(WidgetRef ref, String name, bool value) async {
    await ref
        .read(scheduleDataRepositoryProvider)
        .setSetting(scheduleDisplaySettingKeys[name]!, value.toString());
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }

  Future<void> _restoreHidden(
    BuildContext context,
    WidgetRef ref,
    String courseId,
    String courseName,
  ) async {
    final key = scheduleDisplaySettingKeys['hiddenCourseIds']!;
    final repository = ref.read(scheduleDataRepositoryProvider);
    final hidden = decodeHiddenCourseIds(
      await repository.getSetting(key),
    ).toSet()
      ..remove(courseId);
    await repository.setSetting(key, encodeHiddenCourseIds(hidden));
    ref.invalidate(scheduleDisplayPreferencesProvider);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已恢复“$courseName”'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => unawaited(_run(() => _addHidden(ref, courseId))),
        ),
      ),
    );
  }

  Future<void> _restoreAllHidden(
    BuildContext context,
    WidgetRef ref,
    Set<String> previousHidden,
  ) async {
    await _setHidden(ref, const <String>{});
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已恢复 ${previousHidden.length} 门课程'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () =>
              unawaited(_run(() => _setHidden(ref, previousHidden))),
        ),
      ),
    );
  }

  Future<void> _addHidden(WidgetRef ref, String courseId) async {
    final key = scheduleDisplaySettingKeys['hiddenCourseIds']!;
    final repository = ref.read(scheduleDataRepositoryProvider);
    final hidden = decodeHiddenCourseIds(
      await repository.getSetting(key),
    ).toSet()
      ..add(courseId);
    await repository.setSetting(key, encodeHiddenCourseIds(hidden));
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }

  Future<void> _setHidden(WidgetRef ref, Set<String> hidden) async {
    await ref.read(scheduleDataRepositoryProvider).setSetting(
          scheduleDisplaySettingKeys['hiddenCourseIds']!,
          encodeHiddenCourseIds(hidden),
        );
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }
}

class _HiddenCoursesCard extends StatelessWidget {
  const _HiddenCoursesCard({
    required this.courseIds,
    required this.courseNames,
    required this.onRestore,
    required this.onRestoreAll,
  });

  final Set<String> courseIds;
  final Map<String, String> courseNames;
  final ValueChanged<String> onRestore;
  final VoidCallback onRestoreAll;

  @override
  Widget build(BuildContext context) {
    final ids = courseIds.toList()..sort();
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('已隐藏课程'),
            subtitle: Text('${ids.length} 门课程不会出现在周课表中'),
            trailing: TextButton(
              onPressed: onRestoreAll,
              child: const Text('全部恢复'),
            ),
          ),
          for (var index = 0; index < ids.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              title: Text(courseNames[ids[index]] ?? ids[index]),
              trailing: TextButton(
                onPressed: () => onRestore(ids[index]),
                child: const Text('显示'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.preferences});

  final ScheduleDisplayPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = preferences.showWeekend
        ? const ['一', '二', '三', '四', '五', '六', '日']
        : const ['一', '二', '三', '四', '五'];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth = (constraints.maxWidth - 20 - 40) / days.length;
          final detail = [
            if (preferences.showCampus) '长安校区',
            preferences.showTeacher ? 'A101 · 张老师' : 'A101',
          ].join('\n');
          final textPainter = TextPainter(
            text: TextSpan(
              text: '高等数学\n$detail',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: dayWidth - 11);
          final rowHeight =
              ((textPainter.height + 12) / 2).clamp(35.0, double.infinity);
          textPainter.dispose();
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '第 4 周',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (var index = 0; index < days.length; index++)
                      Expanded(
                        child: Center(
                          child: DecoratedBox(
                            decoration: index == 1
                                ? BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : const BoxDecoration(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              child: Text(
                                days[index],
                                style: TextStyle(
                                  color: index == 1
                                      ? scheme.onPrimaryContainer
                                      : null,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: rowHeight * 4 + 2,
                  child: Stack(
                    children: [
                      for (var row = 0; row < 4; row++)
                        Positioned(
                          top: row * rowHeight,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: rowHeight,
                                child: Center(
                                  child: Text(
                                    preferences.showPeriodTimes
                                        ? '${row + 1}\n${const NwuPeriodRepository().byNumber(row + 1).startLabel}'
                                        : '${row + 1}',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ),
                              for (final _ in days)
                                Expanded(
                                  child: Container(
                                    height: rowHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: .28),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 44 + (days.length > 1 ? 1 : 0),
                        top: 2,
                        width: dayWidth,
                        height: rowHeight * 2 - 2,
                        child: _PreviewBlock(
                          title: '高等数学',
                          detail: detail,
                        ),
                      ),
                      if (preferences.showInactiveCourses)
                        Positioned(
                          left: 44 + dayWidth * (days.length > 2 ? 2 : 1),
                          top: rowHeight * 2 + 2,
                          width: dayWidth,
                          height: rowHeight * 2 - 15,
                          child: const _PreviewBlock(
                            title: '大学英语',
                            detail: '非本周',
                            muted: true,
                          ),
                        ),
                      if (preferences.highlightCurrentPeriod)
                        Positioned(
                          left: 40,
                          right: 0,
                          top: rowHeight * 2 - 1,
                          child: Container(height: 2, color: scheme.primary),
                        ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (preferences.showBackToCurrentWeekFab) ...[
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    '回本周',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 20,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.title,
    required this.detail,
    this.muted = false,
  });

  final String title;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = muted
        ? Color.lerp(scheme.surface, scheme.secondaryContainer, .68)!
        : scheme.primaryContainer;
    final foreground = muted
        ? Color.lerp(background, scheme.onSecondaryContainer, .75)!
        : scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 4, 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: muted
              ? scheme.secondary.withValues(alpha: .28)
              : Colors.transparent,
        ),
      ),
      child: Text(
        '$title\n$detail',
        softWrap: true,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
