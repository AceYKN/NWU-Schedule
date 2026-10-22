import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/campus_design.dart';
import '../../../app/bootstrap.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../shared/presentation/course_card.dart';
import '../../shared/presentation/course_color_resolver.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';
import '../../shared/presentation/schedule_motion.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, this.now, this.initialMonth});

  /// Fixed values are used by widget and screenshot tests.
  final DateTime? now;
  final DateTime? initialMonth;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime month;
  late DateTime selectedDate;
  int monthDirection = 1;

  DateTime get _campusToday => dateOnly(CampusClock.toCampusWallTime(
        widget.now ?? DateTime.now().toUtc(),
      ));

  @override
  void initState() {
    super.initState();
    final today = _campusToday;
    month = widget.initialMonth == null
        ? DateTime(today.year, today.month)
        : DateTime(widget.initialMonth!.year, widget.initialMonth!.month);
    selectedDate =
        month.year == today.year && month.month == today.month ? today : month;
  }

  void _selectDate(DateTime date) {
    setState(() {
      final targetMonth = DateTime(date.year, date.month);
      if (targetMonth != month) {
        monthDirection = targetMonth.isAfter(month) ? 1 : -1;
      }
      selectedDate = dateOnly(date);
      month = targetMonth;
    });
  }

  void _selectMonth(DateTime target) {
    final today = _campusToday;
    _selectDate(target.year == today.year && target.month == today.month
        ? today
        : DateTime(target.year, target.month));
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(campusUserMessage(context, error,
            action: campusText(context, '读取本地课表失败'))),
      ),
      data: (value) {
        if (value is ScheduleCalendarMissing) {
          return Center(
              child: Text(campusText(context, '学期已保存，但缺少校历，请更新应用后重试')));
        }
        if (value is! ScheduleReady) {
          return Center(child: Text(campusText(context, '尚未创建或导入学期')));
        }
        final firstDay = DateTime(month.year, month.month);
        final leading = firstDay.weekday - DateTime.monday;
        final totalDays = DateTime(month.year, month.month + 1, 0).day;
        final cellCount = ((leading + totalDays + 6) ~/ 7) * 7;
        final gridStart = addCalendarDays(firstDay, -leading);
        final gridDays = List<DateTime>.generate(
          cellCount,
          (index) => addCalendarDays(gridStart, index),
        );
        final engine = value.engine;
        return _MonthContent(
          month: month,
          monthDirection: monthDirection,
          selectedDate: selectedDate,
          now: _campusToday,
          gridDays: gridDays,
          coursesByDate: {
            for (final day in gridDays)
              dateKey(day): engine.getCoursesForDate(day),
          },
          engine: engine,
          paletteByCourseId:
              CourseColorResolver.schedulePaletteForCourses(engine.courses),
          onDateSelected: _selectDate,
          onMonthChanged: _selectMonth,
        );
      },
    );
  }
}

int _sectionCount(List<EffectiveCourseInstance> courses) => courses.fold(
      0,
      (total, course) => total + course.endSection - course.startSection + 1,
    );

class _MonthContent extends StatelessWidget {
  const _MonthContent({
    required this.month,
    required this.monthDirection,
    required this.selectedDate,
    required this.now,
    required this.gridDays,
    required this.coursesByDate,
    required this.engine,
    required this.paletteByCourseId,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  final DateTime month;
  final int monthDirection;
  final DateTime selectedDate;
  final DateTime now;
  final List<DateTime> gridDays;
  final Map<String, List<EffectiveCourseInstance>> coursesByDate;
  final ScheduleEngine engine;
  final Map<String, int> paletteByCourseId;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = CampusDesign.maybeOf(context);
    final media = MediaQuery.of(context);
    final selectedCourses = coursesByDate[dateKey(selectedDate)] ??
        engine.getCoursesForDate(selectedDate);
    final selectedCalendarDate = engine.resolveDate(selectedDate);
    final selectedLabel = selectedCalendarDate.label?.trim();
    final selectedStatus = switch (selectedCalendarDate.override?.type) {
      CalendarOverrideType.holiday => '休息日',
      CalendarOverrideType.useScheduleOf => '调休安排',
      _ => null,
    };
    final pagePadding = media.size.width < 400 ? 16.0 : 20.0;
    final scaler = media.textScaler;
    final weekWidth = math.max(34.0, scaler.scale(11) * 3 + 6);
    final minDayWidth = math.max(
        38.0,
        math.max(scaler.scale(16) * 2 + 4,
            design == null ? 0 : scaler.scale(11) * 3 + 8));
    final rowHeight = math.max(
      60.0,
      math.max(32.0, scaler.scale(16) * 1.35 + 10) +
          scaler.scale(11) * 1.4 +
          12,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(pagePadding, 18, pagePadding, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: campusText(context, '选择日期'),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) onDateSelected(picked);
                    },
                    child: design != null
                        ? Text(
                            campusText(context, '{0}年 {1}月',
                                values: {'0': month.year, '1': month.month}),
                            style: design.heading(21))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campusText(context, '{0}年',
                                    values: {'0': month.year}),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              Text(
                                campusText(context, '{0}月',
                                    values: {'0': month.month}),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => onDateSelected(now),
              child: Text(campusText(context, '今天')),
            ),
            IconButton(
              tooltip: campusText(context, '上个月'),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: campusText(context, '下个月'),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MonthTransition(
          month: month,
          direction: monthDirection,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.fromLTRB(8, 15, 8, 12),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(
                    constraints.maxWidth,
                    weekWidth + 7 * minDayWidth,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: weekWidth,
                            child: Center(
                              child: Text(
                                '周次',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          for (var weekday = 1; weekday <= 7; weekday++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  design == null
                                      ? '一二三四五六日'[weekday - 1]
                                      : CampusDesign.weekdayName(weekday),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      for (var row = 0; row < gridDays.length ~/ 7; row++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: weekWidth,
                                height: rowHeight,
                                child: _TeachingWeekLabel(
                                  week: _weekForRow(row),
                                  isCurrent: gridDays
                                      .skip(row * 7)
                                      .take(7)
                                      .any((day) => isSameDate(day, now)),
                                ),
                              ),
                              for (var column = 0; column < 7; column++)
                                Expanded(
                                  child: SizedBox(
                                    height: rowHeight,
                                    child: _MonthDayCell(
                                      date: gridDays[row * 7 + column],
                                      inMonth: gridDays[row * 7 + column]
                                                  .year ==
                                              month.year &&
                                          gridDays[row * 7 + column].month ==
                                              month.month,
                                      selected: isSameDate(
                                        gridDays[row * 7 + column],
                                        selectedDate,
                                      ),
                                      today: isSameDate(
                                        gridDays[row * 7 + column],
                                        now,
                                      ),
                                      courses: coursesByDate[dateKey(
                                            gridDays[row * 7 + column],
                                          )] ??
                                          const [],
                                      resolved: engine.resolveDate(
                                        gridDays[row * 7 + column],
                                      ),
                                      onTap: onDateSelected,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          campusText(context, '{0}月{1}日  {2}', values: {
            '0': selectedDate.month,
            '1': selectedDate.day,
            '2': campusWeekdayName(context, selectedDate.weekday)
                .replaceFirst('星期', '周')
          }),
          style: design?.heading(18) ??
              Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
        ),
        if (selectedLabel != null && selectedLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            selectedLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ] else if (selectedStatus != null) ...[
          const SizedBox(height: 6),
          Text(
            campusText(context, selectedStatus),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 12),
        if (selectedCourses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 22,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              selectedCalendarDate.teachingWeek == null
                  ? campusText(context, '当天不在当前学期内')
                  : campusText(context, '当天没有课程'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (final course in [...selectedCourses]
            ..sort((a, b) => a.startTime.compareTo(b.startTime))) ...[
            if (design != null)
              CourseCard(
                  instance: course,
                  compact: true,
                  paletteIndex: paletteByCourseId[course.course.id])
            else
              _AgendaCourseCard(
                course: course,
                paletteIndex: paletteByCourseId[course.course.id],
              ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  int? _weekForRow(int row) {
    for (var column = 0; column < 7; column++) {
      final week = engine.resolveDate(gridDays[row * 7 + column]).teachingWeek;
      if (week != null) return week;
    }
    return null;
  }
}

class _MonthTransition extends StatelessWidget {
  const _MonthTransition({
    required this.month,
    required this.direction,
    required this.child,
  });

  final DateTime month;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = ScheduleMotion.durationOf(context);
    if (duration == Duration.zero) return child;
    final monthKey = ValueKey(month);
    return ClipRect(
      child: AnimatedSize(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final outgoing in previous)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ExcludeSemantics(
                    child: IgnorePointer(child: outgoing),
                  ),
                ),
              if (current != null) current,
            ],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == monthKey;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset((incoming ? direction : -direction) * .08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: monthKey, child: child),
        ),
      ),
    );
  }
}

class _TeachingWeekLabel extends StatelessWidget {
  const _TeachingWeekLabel({required this.week, required this.isCurrent});

  final int? week;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        week == null ? '' : campusText(context, '{0}周', values: {'0': week}),
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isCurrent
                  ? (CampusDesign.maybeOf(context)?.accent ?? scheme.primary)
                  : scheme.onSurfaceVariant,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
            ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.courses,
    required this.resolved,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<EffectiveCourseInstance> courses;
  final ResolvedCalendarDate resolved;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sections = _sectionCount(courses);
    final status = switch (resolved.override?.type) {
      CalendarOverrideType.holiday => '休息日',
      CalendarOverrideType.useScheduleOf => '调休',
      _ => null,
    };
    final label = [
      '${date.year}年${date.month}月${date.day}日',
      if (today) campusText(context, '今天'),
      if (resolved.teachingWeek case final week?)
        campusText(context, '第{0}教学周', values: {'0': week}),
      if (status != null) campusText(context, status),
      if (resolved.label case final name? when name.trim().isNotEmpty) name,
      if (resolved.teachingWeek == null) campusText(context, '学期外'),
      campusText(context, '{0}节课', values: {'0': sections}),
    ].join('，');
    final markerSize =
        math.max(32.0, MediaQuery.textScalerOf(context).scale(16) * 1.35 + 10);
    final duration = ScheduleMotion.durationOf(context);
    return Semantics(
      key: ValueKey('calendar-day-${dateKey(date)}'),
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: () => onTap(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(date),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  key: ValueKey('calendar-day-marker-${dateKey(date)}'),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: markerSize,
                  height: markerSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: today && !selected
                          ? scheme.primary
                          : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: selected || today
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? scheme.onPrimary
                              : today
                                  ? scheme.primary
                                  : inMonth
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant
                                          .withValues(alpha: .55),
                        ),
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(11) * 1.4,
                  child: Center(
                    child: Text(
                      inMonth && sections > 0
                          ? campusText(context, '{0}节', values: {'0': sections})
                          : '',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaCourseCard extends StatelessWidget {
  const _AgendaCourseCard({required this.course, required this.paletteIndex});

  final EffectiveCourseInstance course;
  final int? paletteIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeWidth = math.max(
      64.0,
      MediaQuery.textScalerOf(context).scale(20) * 2.8,
    );
    final colors = CourseColorResolver.resolveSchedule(
      course.course,
      scheme,
      paletteIndex: paletteIndex,
    );
    final accent = colors.accent;
    final start = _time(course.startTime);
    final end = _time(course.endTime);
    final sectionLabel = course.startSection == course.endSection
        ? '第${course.startSection}节'
        : '第${course.startSection}–${course.endSection}节';
    final exceptionLabel = switch (course.exceptionType) {
      CourseExceptionType.add => '加课 · ',
      CourseExceptionType.move => '调课 · ',
      CourseExceptionType.cancel => '停课 · ',
      null => '',
    };
    final location = course.location ?? '地点待补充';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$start至$end，${course.courseName}，'
          '$exceptionLabel$sectionLabel，$location，点击查看课程详情',
      onTap: () =>
          showCourseDetails(context, course, paletteIndex: paletteIndex),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: timeWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  start,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .30),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showCourseDetails(context, course,
                    paletteIndex: paletteIndex),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 16,
                      bottom: 16,
                      child: Container(
                        key: ValueKey('course-color-${course.course.id}'),
                        width: 4,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$exceptionLabel$sectionLabel',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            course.courseName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime value) => formatMinutes(value.hour * 60 + value.minute);
}
