import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
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
  });

  final int week;
  final int currentWeek;
  final int maxWeek;
  final List<EffectiveCourseInstance> instances;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onAddCourse;

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
          child: FilledButton.icon(
            onPressed: onAddCourse,
            icon: const Icon(Icons.add),
            label: const Text('手动添加课程'),
          ),
        ),
        const SizedBox(height: 8),
        _ScheduleGrid(weekdays: weekdays, instances: instances),
        if (instances.isEmpty) ...[
          const SizedBox(height: 24),
          const Center(child: Text('本周没有课程')),
        ],
      ],
    );
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({required this.weekdays, required this.instances});

  final List<int> weekdays;
  final List<EffectiveCourseInstance> instances;

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(118),
        border: TableBorder.all(
          color: Theme.of(context).dividerColor.withAlpha(89),
          width: 0.6,
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
    return Container(
      height: 70,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text('$section'),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.day,
    required this.section,
    required this.instance,
  });

  final int day;
  final int section;
  final EffectiveCourseInstance? instance;

  @override
  Widget build(BuildContext context) {
    if (instance == null || instance!.startSection != section) {
      return const SizedBox(height: 70);
    }
    final color = Color(
      instance!.course.colorOverride ??
          Theme.of(context).colorScheme.primary.toARGB32(),
    );
    return InkWell(
      onTap: () => showCourseDetails(context, instance!),
      child: Container(
        height: 70,
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
    );
  }
}
