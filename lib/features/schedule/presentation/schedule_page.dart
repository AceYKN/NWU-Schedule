import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../../domain/schedule/week_schedule_view_model.dart';
import '../../../domain/settings/schedule_display_preferences.dart';
import '../../shared/presentation/course_card.dart';
import '../../shared/presentation/course_color_resolver.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, this.now});

  /// Optional fixed instant for deterministic UI tests. Production callers
  /// leave this null and use the device clock.
  final DateTime? now;

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
      error: (error, stackTrace) => Center(
        child: Text(nwuUserMessage(error, action: '读取本地课表失败')),
      ),
      data: (value) {
        if (value is! ScheduleReady) {
          return const Center(child: Text('当前没有可展示的课表'));
        }
        final engine = value.engine;
        final now = widget.now ?? DateTime.now().toUtc();
        final preferences =
            ref.watch(scheduleDisplayPreferencesProvider).asData?.value ??
                const ScheduleDisplayPreferences.defaults();
        final currentWeek = engine.teachingWeekAt(now) ?? 1;
        final maxWeek = engine.totalWeeks;
        final week = (selectedWeek ?? currentWeek).clamp(1, maxWeek);
        return Scaffold(
          body: _WeekContent(
            week: week,
            currentWeek: currentWeek,
            maxWeek: maxWeek,
            engine: engine,
            preferences: preferences,
            now: now,
            onWeekChanged: (value) => setState(() => selectedWeek = value),
            onAddCourse: () => context.go('/course/new'),
            onAddException: () => showStandaloneAddException(
              pageContext: context,
              ref: ref,
              semesterId: engine.semesterId,
              initialDate: engine.weekStart(week),
            ),
          ),
          floatingActionButton: preferences.showBackToCurrentWeekFab &&
                  week != currentWeek
              ? FloatingActionButton.extended(
                  onPressed: () => setState(() => selectedWeek = currentWeek),
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('本周'),
                )
              : null,
        );
      },
    );
  }
}

class _WeekContent extends StatefulWidget {
  const _WeekContent({
    required this.week,
    required this.currentWeek,
    required this.maxWeek,
    required this.engine,
    required this.preferences,
    required this.now,
    required this.onWeekChanged,
    required this.onAddCourse,
    required this.onAddException,
  });

  final int week;
  final int currentWeek;
  final int maxWeek;
  final ScheduleEngine engine;
  final ScheduleDisplayPreferences preferences;
  final DateTime now;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onAddCourse;
  final VoidCallback onAddException;

  @override
  State<_WeekContent> createState() => _WeekContentState();
}

class _WeekContentState extends State<_WeekContent> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.week - 1);
  }

  @override
  void didUpdateWidget(covariant _WeekContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.week != widget.week) {
      if (_pageController.hasClients &&
          (_pageController.page ?? 0).round() != widget.week - 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(widget.week - 1);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            themeTokens.pagePadding,
            18,
            themeTokens.pagePadding,
            8,
          ),
          child: _WeekToolbar(
            week: widget.week,
            maxWeek: widget.maxWeek,
            definition: widget.engine.calendarDefinition,
            onWeekChanged: widget.onWeekChanged,
            onAddCourse: widget.onAddCourse,
            onAddException: widget.onAddException,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.maxWeek,
            onPageChanged: (page) {
              final nextWeek = page + 1;
              if (nextWeek != widget.week) widget.onWeekChanged(nextWeek);
            },
            itemBuilder: (context, index) {
              final pageWeek = index + 1;
              final pageModel = widget.engine.getWeekViewModel(
                pageWeek,
                includeInactive: widget.preferences.showInactiveCourses,
                now: widget.now,
              );
              final hasWeekendCourse = pageModel.activeEntries.any(
                (entry) => entry.weekday >= DateTime.saturday,
              );
              final showWeekend =
                  widget.preferences.showWeekend || hasWeekendCourse;
              final visibleDays = showWeekend
                  ? pageModel.days
                  : pageModel.days.take(5).toList(growable: false);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  themeTokens.pagePadding,
                  0,
                  themeTokens.pagePadding,
                  32,
                ),
                child: Column(
                  children: [
                    _ScheduleGrid(
                      visibleDays: visibleDays,
                      viewModel: pageModel,
                      preferences: widget.preferences,
                      now: CampusClock.toCampusWallTime(widget.now),
                    ),
                    if (pageModel.activeEntries.isEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('本周没有课程'),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
    required this.week,
    required this.maxWeek,
    required this.definition,
    required this.onWeekChanged,
    required this.onAddCourse,
    required this.onAddException,
  });

  final int week;
  final int maxWeek;
  final CalendarDefinition definition;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onAddCourse;
  final VoidCallback onAddException;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    final start = definition.weekStart(week);
    final end = start.add(const Duration(days: 6));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '周课表',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text('${start.month}/${start.day} – ${end.month}/${end.day}'),
                ],
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: week,
                isDense: true,
                items: [
                  for (var item = 1; item <= maxWeek; item++)
                    DropdownMenuItem(
                      value: item,
                      child: Text('第 $item 周'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onWeekChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: themeTokens.gridGap,
          runSpacing: themeTokens.gridGap,
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
      ],
    );
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.visibleDays,
    required this.viewModel,
    required this.preferences,
    required this.now,
  });

  final List<WeekDayColumn> visibleDays;
  final WeekScheduleViewModel viewModel;
  final ScheduleDisplayPreferences preferences;
  final DateTime now;

  static const _headerHeight = 44.0;
  static const _rowHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final periodWidth = preferences.showPeriodTimes ? 48.0 : 34.0;
    final periodCount = NwuPeriodRepository.all.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = math.max<double>(
          1,
          (constraints.maxWidth - periodWidth) / visibleDays.length,
        );
        final height = _headerHeight + periodCount * _rowHeight;
        final placed = _placeEntries();
        final currentSection =
            preferences.highlightCurrentPeriod ? _currentSection() : null;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScheduleGridPainter(
                    periodWidth: periodWidth,
                    dayWidth: dayWidth,
                    dayCount: visibleDays.length,
                    periodCount: periodCount,
                    headerHeight: _headerHeight,
                    rowHeight: _rowHeight,
                    lineColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              for (var index = 0; index < visibleDays.length; index++)
                Positioned(
                  left: periodWidth + index * dayWidth,
                  top: 0,
                  width: dayWidth,
                  height: _headerHeight,
                  child: _DayHeader(day: visibleDays[index]),
                ),
              for (var section = 1; section <= periodCount; section++)
                Positioned(
                  left: 0,
                  top: _headerHeight + (section - 1) * _rowHeight,
                  width: periodWidth,
                  height: _rowHeight,
                  child: _PeriodLabel(
                    section: section,
                    showTime: preferences.showPeriodTimes,
                  ),
                ),
              for (final item in placed)
                Positioned(
                  left: periodWidth +
                      visibleDays.indexWhere(
                            (day) => day.weekday == item.entry.weekday,
                          ) *
                          dayWidth +
                      item.lane * (dayWidth / item.laneCount) +
                      2,
                  top: _headerHeight +
                      (item.entry.startSection - 1) * _rowHeight +
                      2,
                  width: math.max<double>(8, dayWidth / item.laneCount - 4),
                  height: math.max<double>(
                    24,
                    (item.entry.endSection - item.entry.startSection + 1) *
                            _rowHeight -
                        4,
                  ),
                  child: _ScheduleBlock(
                    entry: item.entry,
                    preferences: preferences,
                  ),
                ),
              if (currentSection != null)
                Positioned(
                  left: periodWidth,
                  right: 0,
                  top: _headerHeight + (currentSection - 1) * _rowHeight,
                  child: IgnorePointer(
                    child: Container(
                      height: 2,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_PlacedScheduleEntry> _placeEntries() {
    final placed = <_PlacedScheduleEntry>[];
    for (final day in visibleDays) {
      final entries = viewModel.entries
          .where((entry) => entry.weekday == day.weekday)
          .toList()
        ..sort((left, right) {
          final byStart = left.startSection.compareTo(right.startSection);
          if (byStart != 0) return byStart;
          return right.endSection.compareTo(left.endSection);
        });
      final lanes = <List<ScheduleGridEntry>>[];
      final startIndex = placed.length;
      for (final entry in entries) {
        var lane = 0;
        while (lane < lanes.length &&
            lanes[lane].any((other) => _overlaps(other, entry))) {
          lane++;
        }
        if (lane == lanes.length) lanes.add([]);
        lanes[lane].add(entry);
        placed.add(
          _PlacedScheduleEntry(
            entry: entry,
            lane: lane,
            laneCount: lanes.length,
          ),
        );
      }
      for (var index = startIndex; index < placed.length; index++) {
        placed[index] = placed[index].copyWith(laneCount: lanes.length);
      }
    }
    return placed;
  }

  static bool _overlaps(ScheduleGridEntry left, ScheduleGridEntry right) {
    return left.startSection <= right.endSection &&
        right.startSection <= left.endSection;
  }

  int? _currentSection() {
    final today = dateOnly(now);
    final todayColumn = visibleDays
        .where((day) => day.isToday && isSameDate(day.date, today))
        .firstOrNull;
    if (todayColumn == null) return null;
    final minutes = now.hour * 60 + now.minute;
    for (final period in NwuPeriodRepository.all) {
      if (minutes >= period.startMinutes && minutes < period.endMinutes) {
        return period.number;
      }
    }
    return null;
  }
}

class _PlacedScheduleEntry {
  const _PlacedScheduleEntry({
    required this.entry,
    required this.lane,
    required this.laneCount,
  });

  final ScheduleGridEntry entry;
  final int lane;
  final int laneCount;

  _PlacedScheduleEntry copyWith({int? laneCount}) => _PlacedScheduleEntry(
        entry: entry,
        lane: lane,
        laneCount: laneCount ?? this.laneCount,
      );
}

class _ScheduleGridPainter extends CustomPainter {
  const _ScheduleGridPainter({
    required this.periodWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.periodCount,
    required this.headerHeight,
    required this.rowHeight,
    required this.lineColor,
  });

  final double periodWidth;
  final double dayWidth;
  final int dayCount;
  final int periodCount;
  final double headerHeight;
  final double rowHeight;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.7;
    canvas.drawLine(
      Offset(0, headerHeight),
      Offset(size.width, headerHeight),
      paint,
    );
    for (var day = 0; day <= dayCount; day++) {
      final x = periodWidth + day * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
    for (var section = 0; section <= periodCount; section++) {
      final y = headerHeight + section * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridPainter oldDelegate) =>
      oldDelegate.periodWidth != periodWidth ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.dayCount != dayCount ||
      oldDelegate.lineColor != lineColor;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final WeekDayColumn day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markerColor = day.marker == '休' ? scheme.error : scheme.tertiary;
    return Semantics(
      container: true,
      label:
          '星期${day.label}，${day.date.month}月${day.date.day}日${day.marker == null ? '' : '，${day.marker}'}',
      child: Container(
        color: day.isToday ? scheme.primaryContainer : scheme.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(day.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '${day.date.day}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (day.marker != null)
                Text(
                  day.marker!,
                  style: TextStyle(
                    color: markerColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.section, required this.showTime});

  final int section;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final period = const NwuPeriodRepository().byNumber(section);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        showTime
            ? '$section\n${period.startLabel}\n${period.endLabel}'
            : '$section',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
      ),
    );
  }
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({required this.entry, required this.preferences});

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = CourseColorResolver.resolve(entry.course, scheme);
    final location = entry.instance.location;
    final lines = [
      entry.course.name,
      if (location != null) location,
      if (preferences.showTeacher && entry.teacher != null) entry.teacher!,
      if (!entry.active) '非本周',
    ];
    final label = [
      entry.course.name,
      weekdayName(entry.weekday),
      '第${entry.startSection}-${entry.endSection}节',
      if (location != null) location,
      if (preferences.showTeacher && entry.teacher != null) entry.teacher!,
      if (!entry.active) '非本周课程',
    ].join('，');
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label，点击查看课程详情',
      onTap: () => showCourseDetails(context, entry.instance),
      child: InkWell(
        onTap: () => showCourseDetails(context, entry.instance),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: entry.active
                ? colors.container
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant,
              width: entry.active ? 0.7 : 1,
            ),
          ),
          child: Text(
            lines.join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: _fontSize(context),
                  height: 1.1,
                  color: entry.active
                      ? colors.onContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  double _fontSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 500
        ? 11
        : width >= 390
            ? 10
            : 9;
  }
}
