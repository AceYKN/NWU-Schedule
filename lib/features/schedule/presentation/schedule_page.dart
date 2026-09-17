import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../shared/presentation/course_card.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  int? selectedWeek;

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('暂时无法读取本地课表')),
      data: (value) {
        if (value is! ScheduleReady) {
          return const Center(child: Text('当前没有可展示的课表'));
        }
        final engine = value.engine;
        final currentWeek =
            engine.calendarEngine.weekOf(CampusClock.now()) ?? 1;
        final maxWeek = engine.calendarEngine.definition.totalWeeks;
        final week = (selectedWeek ?? currentWeek).clamp(1, maxWeek);
        return _WeekContent(
          week: week,
          currentWeek: currentWeek,
          maxWeek: maxWeek,
          instances: engine.getCoursesForWeek(week),
          onWeekChanged: (value) => setState(() => selectedWeek = value),
          onAddCourse: () => context.go('/course/new'),
          onAddException: () => showStandaloneAddException(
            pageContext: context,
            ref: ref,
            semesterId: engine.semesterId,
            initialDate: engine.calendarEngine.definition.weekStart(week),
          ),
        );
      },
    );
  }
}

class _WeekContent extends StatelessWidget {
  const _WeekContent({
    required this.week,
    required this.currentWeek,
    required this.maxWeek,
    required this.instances,
    required this.onWeekChanged,
    required this.onAddCourse,
    required this.onAddException,
  });

  final int week;
  final int currentWeek;
  final int maxWeek;
  final List<EffectiveCourseInstance> instances;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onAddCourse;
  final VoidCallback onAddException;

  @override
  Widget build(BuildContext context) {
    final maxWeekday = instances.fold<int>(
      5,
      (max, instance) =>
          instance.date.weekday > max ? instance.date.weekday : max,
    );
    final weekdays = List<int>.generate(maxWeekday, (index) => index + 1);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Row(
          children: [
            Text(
              '周课表',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '上一周',
              onPressed: week > 1 ? () => onWeekChanged(week - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('第 $week 周'),
            IconButton(
              tooltip: '下一周',
              onPressed: week < maxWeek ? () => onWeekChanged(week + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                week == currentWeek ? null : () => onWeekChanged(currentWeek),
            child: const Text('本周'),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onAddException,
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('临时加课'),
              ),
              FilledButton.icon(
                onPressed: onAddCourse,
                icon: const Icon(Icons.add),
                label: const Text('手动添加课程'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ScheduleGrid(
          weekdays: weekdays,
          instances: instances,
          now: CampusClock.now(),
        ),
        if (instances.isEmpty) ...[
          const SizedBox(height: 24),
          const Center(child: Text('本周没有课程')),
        ],
      ],
    );
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.weekdays,
    required this.instances,
    required this.now,
  });

  final List<int> weekdays;
  final List<EffectiveCourseInstance> instances;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    final rows = <TableRow>[
      TableRow(
        children: [
          const _GridHeader(text: '节次'),
          ...weekdays.map(
            (day) => _GridHeader(
              text: weekdayName(day),
              highlighted: day == CampusClock.now().weekday,
            ),
          ),
        ],
      ),
    ];
    for (var section = 1; section <= 11; section++) {
      rows.add(
        TableRow(
          children: [
            _PeriodCell(section: section),
            ...weekdays.map(
              (day) => _ScheduleCell(
                day: day,
                section: section,
                instance: _findInstance(day, section),
                showCurrentTime: _isCurrentTime(day, section),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: FixedColumnWidth(themeTokens.gridColumnWidth),
        border: TableBorder.all(
          color: Theme.of(context).dividerColor.withAlpha(89),
          width: themeTokens.gridBorderWidth,
        ),
        children: rows,
      ),
    );
  }

  EffectiveCourseInstance? _findInstance(int day, int section) {
    for (final instance in instances) {
      if (instance.date.weekday == day &&
          instance.startSection <= section &&
          instance.endSection >= section) {
        return instance;
      }
    }
    return null;
  }

  bool _isCurrentTime(int day, int section) {
    if (now.weekday != day) return false;
    final period = const NwuPeriodRepository().byNumber(section);
    final minutes = now.hour * 60 + now.minute;
    return minutes >= period.startMinutes && minutes < period.endMinutes;
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.text, this.highlighted = false});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _PeriodCell extends StatelessWidget {
  const _PeriodCell({required this.section});

  final int section;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    final period = const NwuPeriodRepository().byNumber(section);
    return Container(
      height: themeTokens.gridCellHeight,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        '$section\n${period.startLabel}-${period.endLabel}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.day,
    required this.section,
    required this.instance,
    required this.showCurrentTime,
  });

  final int day;
  final int section;
  final EffectiveCourseInstance? instance;
  final bool showCurrentTime;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    final isStart = instance != null && instance!.startSection == section;
    if (!isStart) {
      return Container(
        height: themeTokens.gridCellHeight,
        decoration: showCurrentTime
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 2,
                  ),
                ),
              )
            : null,
      );
    }
    final color = Color(
      instance!.course.colorOverride ??
          Theme.of(context).colorScheme.primary.toARGB32(),
    );
    return Stack(
      children: [
        Semantics(
          button: true,
          excludeSemantics: true,
          label:
              '${instance!.courseName}，${weekdayName(day)}，第 $section 至 ${instance!.endSection} 节，点击查看课程详情',
          onTap: () => showCourseDetails(context, instance!),
          child: InkWell(
            onTap: () => showCourseDetails(context, instance!),
            child: Container(
              height: themeTokens.gridCellHeight,
              padding: const EdgeInsets.all(6),
              color: color.withAlpha(46),
              child: Text(
                instance!.courseName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        if (showCurrentTime)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}
