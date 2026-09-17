import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../shared/presentation/course_card.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime month = DateTime(CampusClock.now().year, CampusClock.now().month);

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(scheduleEngineProvider);
    final firstDay = DateTime(month.year, month.month);
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final days = List<DateTime>.generate(
      totalDays,
      (index) => DateTime(month.year, month.month, index + 1),
    );
    return FutureBuilder<Map<String, List<EffectiveCourseInstance>>>(
      future: _loadMonth(engine, days),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('暂时无法读取本地课表'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _MonthContent(
          month: month,
          firstDay: firstDay,
          days: days,
          coursesByDate: snapshot.data!,
          onMonthChanged: (value) => setState(() => month = value),
          engine: engine,
        );
      },
    );
  }

  Future<Map<String, List<EffectiveCourseInstance>>> _loadMonth(
    ScheduleEngine engine,
    List<DateTime> days,
  ) async {
    final entries = await Future.wait(
      days.map((day) async {
        return MapEntry(dateKey(day), await engine.getCoursesForDate(day));
      }),
    );
    return Map.fromEntries(entries);
  }
}

class _MonthContent extends StatelessWidget {
  const _MonthContent({
    required this.month,
    required this.firstDay,
    required this.days,
    required this.coursesByDate,
    required this.onMonthChanged,
    required this.engine,
  });

  final DateTime month;
  final DateTime firstDay;
  final List<DateTime> days;
  final Map<String, List<EffectiveCourseInstance>> coursesByDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ScheduleEngine engine;

  @override
  Widget build(BuildContext context) {
    final leading = firstDay.weekday - 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
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
                DateTime(CampusClock.now().year, CampusClock.now().month),
              ),
              icon: const Icon(Icons.today_outlined),
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
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 78,
          ),
          itemBuilder: (context, index) {
            if (index < leading) {
              return const SizedBox.shrink();
            }
            final day = days[index - leading];
            final courses = coursesByDate[dateKey(day)] ?? const [];
            return _MonthCell(
              date: day,
              courses: courses,
              resolved: engine.calendarEngine.resolve(day),
            );
          },
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.courses,
    required this.resolved,
  });

  final DateTime date;
  final List<EffectiveCourseInstance> courses;
  final ResolvedCalendarDate resolved;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDate(date, CampusClock.now());
    final label = resolved.label;
    final holiday = resolved.isTeachingDay == false;
    return Card(
      color: isToday
          ? Theme.of(context).colorScheme.primaryContainer
          : holiday
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: courses.isEmpty
            ? null
            : () => showCourseDetails(context, courses.first),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.day}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (label != null && label.isNotEmpty)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (courses.isNotEmpty)
                Text(
                  '${courses.length} 节',
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
    );
  }
}
