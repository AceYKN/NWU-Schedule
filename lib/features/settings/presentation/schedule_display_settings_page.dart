import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../domain/settings/schedule_display_preferences.dart';

class ScheduleDisplaySettingsPage extends ConsumerWidget {
  const ScheduleDisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(scheduleDisplayPreferencesProvider).asData?.value ??
            const ScheduleDisplayPreferences.defaults();
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
                title: '显示周末',
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
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title),
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
    return Card(
      color: scheme.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth = (constraints.maxWidth - 20 - 34) / days.length;
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        preferences.showPeriodTimes ? '节\n时' : '节',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    for (final day in days)
                      Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                                        ? '${row + 1}\n08:${row}0'
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
                                    margin: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            scheme.outlineVariant.withAlpha(90),
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
                          child: Container(height: 2, color: scheme.error),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$title\n$detail',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
