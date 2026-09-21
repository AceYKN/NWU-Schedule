import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../shared/presentation/course_card.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, this.now, this.initialMonth});

  /// Optional fixed instant and month for deterministic UI tests. Production
  /// callers leave both null and use the campus clock.
  final DateTime? now;
  final DateTime? initialMonth;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final campusNow = CampusClock.toCampusWallTime(
      widget.now ?? DateTime.now().toUtc(),
    );
    month = widget.initialMonth ?? DateTime(campusNow.year, campusNow.month);
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(nwuUserMessage(error, action: '读取本地课表失败')),
      ),
      data: (value) {
        if (value is! ScheduleReady) {
          return const Center(child: Text('当前没有可展示的校历'));
        }
        final engine = value.engine;
        final campusNow = CampusClock.toCampusWallTime(
          widget.now ?? DateTime.now().toUtc(),
        );
        final firstDay = DateTime(month.year, month.month);
        final totalDays = DateTime(month.year, month.month + 1, 0).day;
        final leading = firstDay.weekday - 1;
        final cellCount = ((leading + totalDays + 6) ~/ 7) * 7;
        final gridStart = firstDay.subtract(Duration(days: leading));
        final gridDays = List<DateTime>.generate(
          cellCount,
          (index) => gridStart.add(Duration(days: index)),
        );
        return _MonthContent(
          month: month,
          gridDays: gridDays,
          coursesByDate: {
            for (final day in gridDays)
              dateKey(day): engine.getCoursesForDate(day),
          },
          onMonthChanged: (value) => setState(() => month = value),
          engine: engine,
          now: campusNow,
          currentTeachingWeek: engine.resolveDate(campusNow).teachingWeek,
        );
      },
    );
  }
}

class _MonthContent extends StatelessWidget {
  const _MonthContent({
    required this.month,
    required this.gridDays,
    required this.coursesByDate,
    required this.onMonthChanged,
    required this.engine,
    required this.now,
    required this.currentTeachingWeek,
  });

  final DateTime month;
  final List<DateTime> gridDays;
  final Map<String, List<EffectiveCourseInstance>> coursesByDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ScheduleEngine engine;
  final DateTime now;
  final int? currentTeachingWeek;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        themeTokens.pagePadding,
        18,
        themeTokens.pagePadding,
        32,
      ),
      children: [
        Row(
          children: [
            Text(
              '${month.year}年${month.month}月',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '上个月',
              onPressed: () => onMonthChanged(
                DateTime(month.year, month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: '回到本月',
              onPressed: () => onMonthChanged(
                DateTime(now.year, now.month),
              ),
              icon: const Icon(Icons.today_outlined),
            ),
            IconButton(
              tooltip: '选择日期',
              onPressed: () async {
                final pickerYear = month.year.clamp(2000, 2100).toInt();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(pickerYear, month.month),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  onMonthChanged(DateTime(picked.year, picked.month));
                }
              },
              icon: const Icon(Icons.event_outlined),
            ),
            IconButton(
              tooltip: '下个月',
              onPressed: () => onMonthChanged(
                DateTime(month.year, month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 44),
            ...['一', '二', '三', '四', '五', '六', '日'].map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (var row = 0; row < gridDays.length ~/ 7; row++)
              SizedBox(
                height: themeTokens.monthCellHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TeachingWeekGutter(
                      week: _weekForRow(row),
                      highlighted: _weekForRow(row) == currentTeachingWeek,
                    ),
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = gridDays[row * 7 + column];
                            return _MonthCell(
                              date: day,
                              isInMonth: day.month == month.month &&
                                  day.year == month.year,
                              courses: coursesByDate[dateKey(day)] ?? const [],
                              resolved: engine.resolveDate(day),
                              now: now,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
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

class _TeachingWeekGutter extends StatelessWidget {
  const _TeachingWeekGutter({required this.week, required this.highlighted});

  final int? week;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted ? scheme.primaryContainer : null,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .25),
            width: .5,
          ),
        ),
        child: Center(
          child: week == null
              ? const SizedBox.shrink()
              : Text(
                  '第$week周',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: highlighted ? scheme.primary : null,
                        fontWeight: highlighted ? FontWeight.w700 : null,
                      ),
                ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.isInMonth,
    required this.courses,
    required this.resolved,
    required this.now,
  });

  final DateTime date;
  final bool isInMonth;
  final List<EffectiveCourseInstance> courses;
  final ResolvedCalendarDate resolved;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    final isToday = isSameDate(date, now);
    final label = resolved.label;
    final holiday = resolved.override?.type == CalendarOverrideType.holiday;
    final outsideSemester =
        !resolved.isTeachingDay && !holiday && resolved.teachingWeek == null;
    final status = holiday
        ? '休'
        : resolved.override?.type == CalendarOverrideType.useScheduleOf
            ? '调'
            : null;
    final semanticParts = [
      '${date.month}月${date.day}日',
      if (label != null && label.isNotEmpty) label,
      if (resolved.teachingWeek != null) '第${resolved.teachingWeek}教学周',
      if (outsideSemester) '学期外',
      if (courses.isEmpty) '无课程' else '${courses.length}节课程',
    ];
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${semanticParts.join('，')}，点击查看当天课程',
      onTap: () => _showDailyAgenda(context, date, courses, resolved),
      child: Opacity(
        opacity: isInMonth ? 1 : .45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isToday
                ? Theme.of(context).colorScheme.primaryContainer
                : holiday
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .25),
              width: .5,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _showDailyAgenda(context, date, courses, resolved),
              child: Padding(
                padding: EdgeInsets.all(themeTokens.monthCellPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.day}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (status != null)
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (courses.isNotEmpty)
                      Text(
                        '${courses.length} 节',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showDailyAgenda(
  BuildContext context,
  DateTime date,
  List<EffectiveCourseInstance> courses,
  ResolvedCalendarDate resolved,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日 ${weekdayName(date.weekday)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (resolved.label != null && resolved.label!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(resolved.label!),
            ],
            const SizedBox(height: 16),
            if (courses.isEmpty)
              const Text('当天没有课程')
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final course in courses)
                      CourseCard(instance: course, compact: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
