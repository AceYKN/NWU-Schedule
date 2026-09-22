import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/nwu/periods.dart';
import '../../../domain/settings/schedule_display_preferences.dart';

class ScheduleDisplaySettingsPage extends ConsumerWidget {
  const ScheduleDisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              '课表显示',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '预览',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                onChanged: (value) => _save(ref, 'showWeekend', value),
              ),
              const Divider(height: 1),
              _PreferenceSwitch(
                title: '显示教师',
                value: preferences.showTeacher,
                onChanged: (value) => _save(ref, 'showTeacher', value),
              ),
              const Divider(height: 1),
              _PreferenceSwitch(
                title: '显示非本周课程',
                value: preferences.showInactiveCourses,
                onChanged: (value) => _save(ref, 'showInactiveCourses', value),
              ),
              const Divider(height: 1),
              _PreferenceSwitch(
                title: '显示节次时间',
                value: preferences.showPeriodTimes,
                onChanged: (value) => _save(ref, 'showPeriodTimes', value),
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
            onRestore: (courseId) => _restoreHidden(ref, courseId),
            onRestoreAll: () => _restoreAllHidden(ref),
          ),
        ],
      ],
    );
  }

  Future<void> _save(WidgetRef ref, String name, bool value) async {
    await ref.read(scheduleDataRepositoryProvider).setSetting(
          scheduleDisplaySettingKeys[name]!,
          value.toString(),
        );
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }

  Future<void> _restoreHidden(WidgetRef ref, String courseId) async {
    final key = scheduleDisplaySettingKeys['hiddenCourseIds']!;
    final repository = ref.read(scheduleDataRepositoryProvider);
    final hidden = decodeHiddenCourseIds(await repository.getSetting(key))
      ..remove(courseId);
    await repository.setSetting(key, encodeHiddenCourseIds(hidden));
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }

  Future<void> _restoreAllHidden(WidgetRef ref) async {
    await ref.read(scheduleDataRepositoryProvider).setSetting(
          scheduleDisplaySettingKeys['hiddenCourseIds']!,
          encodeHiddenCourseIds(const <String>[]),
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
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth = (constraints.maxWidth - 20 - 34) / days.length;
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '周课表  ·  第 4 周',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (preferences.showBackToCurrentWeekFab)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            '回本周',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: const SizedBox.shrink(),
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
                  height: 142,
                  child: Stack(
                    children: [
                      for (var row = 0; row < 4; row++)
                        Positioned(
                          top: row * 35,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                height: 35,
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
                                    height: 35,
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
                        left: 34 + (days.length > 1 ? 1 : 0),
                        top: 2,
                        width: dayWidth,
                        height: 68,
                        child: _PreviewBlock(
                          title: '高等数学',
                          detail:
                              preferences.showTeacher ? 'A101 · 张老师' : 'A101',
                        ),
                      ),
                      if (preferences.showInactiveCourses)
                        Positioned(
                          left: 34 + dayWidth * (days.length > 2 ? 2 : 1),
                          top: 72,
                          width: dayWidth,
                          height: 55,
                          child: const _PreviewBlock(
                            title: '大学英语',
                            detail: '非本周',
                            muted: true,
                          ),
                        ),
                      if (preferences.highlightCurrentPeriod)
                        Positioned(
                          left: 30,
                          right: 0,
                          top: 69,
                          child: Container(height: 2, color: scheme.primary),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 4, 5),
      decoration: BoxDecoration(
        color: muted ? Colors.transparent : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: muted
              ? scheme.outlineVariant.withValues(alpha: .42)
              : Colors.transparent,
        ),
      ),
      child: Text(
        '$title\n$detail',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted
                  ? scheme.onSurfaceVariant.withValues(alpha: .55)
                  : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
