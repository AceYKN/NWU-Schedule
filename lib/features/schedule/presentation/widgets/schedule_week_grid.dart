import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/nwu/periods.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../../domain/settings/schedule_display_preferences.dart';
import 'course_block.dart';

class ScheduleWeekGrid extends StatelessWidget {
  const ScheduleWeekGrid({
    required this.visibleDays,
    required this.viewModel,
    required this.preferences,
    required this.now,
    super.key,
  });

  final List<WeekDayColumn> visibleDays;
  final WeekScheduleViewModel viewModel;
  final ScheduleDisplayPreferences preferences;
  final DateTime now;

  static const double headerHeight = 50;
  static const double periodHeight = 64;

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
        final height = headerHeight + periodCount * periodHeight;
        final placed = _placeEntries();
        final current =
            preferences.highlightCurrentPeriod ? _currentPeriod() : null;
        final scheme = Theme.of(context).colorScheme;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScheduleGridPainter(
                    periodWidth: periodWidth,
                    dayWidth: dayWidth,
                    dayCount: visibleDays.length,
                    periodCount: periodCount,
                    headerHeight: headerHeight,
                    rowHeight: periodHeight,
                    lineColor: scheme.outlineVariant,
                  ),
                ),
              ),
              for (var index = 0; index < visibleDays.length; index++)
                Positioned(
                  left: periodWidth + index * dayWidth,
                  top: 0,
                  width: dayWidth,
                  height: headerHeight,
                  child: ScheduleDayHeader(day: visibleDays[index]),
                ),
              for (var section = 1; section <= periodCount; section++)
                Positioned(
                  left: 0,
                  top: headerHeight + (section - 1) * periodHeight,
                  width: periodWidth,
                  height: periodHeight,
                  child: ScheduleTimeAxis(
                    section: section,
                    showTime: preferences.showPeriodTimes,
                  ),
                ),
              for (final item in placed)
                Positioned(
                  left: periodWidth +
                      item.dayIndex * dayWidth +
                      item.lane * (dayWidth / item.laneCount) +
                      2,
                  top: headerHeight +
                      (item.entry.startSection - 1) * periodHeight +
                      2,
                  width: math.max<double>(
                    8,
                    dayWidth / item.laneCount - 4,
                  ),
                  height: math.max<double>(
                    24,
                    (item.entry.endSection - item.entry.startSection + 1) *
                            periodHeight -
                        4,
                  ),
                  child: CourseBlock(
                    entry: item.entry,
                    preferences: preferences,
                    width: dayWidth / item.laneCount - 4,
                    height: math.max<double>(
                      24,
                      (item.entry.endSection - item.entry.startSection + 1) *
                              periodHeight -
                          4,
                    ),
                    visibleDayCount: visibleDays.length,
                    isCurrent: current != null &&
                        item.entry.active &&
                        item.entry.weekday == current.weekday &&
                        item.entry.startSection <= current.section &&
                        current.section <= item.entry.endSection,
                  ),
                ),
              if (current != null)
                Positioned(
                  left: periodWidth + current.dayIndex * dayWidth,
                  width: dayWidth,
                  top: headerHeight + (current.section - 1) * periodHeight + 1,
                  child: IgnorePointer(
                    child: Container(
                      height: 2,
                      color: scheme.primary,
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
    for (var dayIndex = 0; dayIndex < visibleDays.length; dayIndex++) {
      final day = visibleDays[dayIndex];
      final entries = viewModel.entries
          .where((entry) => entry.weekday == day.weekday)
          .toList()
        ..sort((left, right) {
          final byStart = left.startSection.compareTo(right.startSection);
          if (byStart != 0) return byStart;
          return right.endSection.compareTo(left.endSection);
        });
      final group = <ScheduleGridEntry>[];
      var groupEnd = 0;
      for (final entry in entries) {
        if (group.isNotEmpty && entry.startSection > groupEnd) {
          _placeOverlapGroup(
            group,
            dayIndex: dayIndex,
            placed: placed,
          );
          group.clear();
        }
        group.add(entry);
        groupEnd = math.max(groupEnd, entry.endSection);
      }
      _placeOverlapGroup(
        group,
        dayIndex: dayIndex,
        placed: placed,
      );
    }
    return placed;
  }

  void _placeOverlapGroup(
    List<ScheduleGridEntry> group, {
    required int dayIndex,
    required List<_PlacedScheduleEntry> placed,
  }) {
    if (group.isEmpty) return;

    final lanes = <List<ScheduleGridEntry>>[];
    final startIndex = placed.length;
    for (final entry in group) {
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
          dayIndex: dayIndex,
          lane: lane,
          laneCount: lanes.length,
        ),
      );
    }
    for (var index = startIndex; index < placed.length; index++) {
      placed[index] = placed[index].copyWith(laneCount: lanes.length);
    }
  }

  static bool _overlaps(ScheduleGridEntry left, ScheduleGridEntry right) {
    return left.startSection <= right.endSection &&
        right.startSection <= left.endSection;
  }

  _CurrentPeriod? _currentPeriod() {
    final today = dateOnly(now);
    final dayIndex = visibleDays.indexWhere(
      (day) => day.isToday && isSameDate(day.date, today),
    );
    if (dayIndex < 0) return null;
    final minutes = now.hour * 60 + now.minute;
    for (final period in NwuPeriodRepository.all) {
      if (minutes >= period.startMinutes && minutes < period.endMinutes) {
        return _CurrentPeriod(
          weekday: visibleDays[dayIndex].weekday,
          dayIndex: dayIndex,
          section: period.number,
        );
      }
    }
    return null;
  }
}

class _CurrentPeriod {
  const _CurrentPeriod({
    required this.weekday,
    required this.dayIndex,
    required this.section,
  });

  final int weekday;
  final int dayIndex;
  final int section;
}

class _PlacedScheduleEntry {
  const _PlacedScheduleEntry({
    required this.entry,
    required this.dayIndex,
    required this.lane,
    required this.laneCount,
  });

  final ScheduleGridEntry entry;
  final int dayIndex;
  final int lane;
  final int laneCount;

  _PlacedScheduleEntry copyWith({int? laneCount}) => _PlacedScheduleEntry(
        entry: entry,
        dayIndex: dayIndex,
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
      ..color = lineColor.withValues(alpha: .45)
      ..strokeWidth = .7;
    canvas.drawLine(
      Offset(periodWidth, 0),
      Offset(periodWidth, size.height),
      paint,
    );
    for (var day = 1; day < dayCount; day++) {
      final x = periodWidth + day * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawLine(
      Offset(periodWidth, headerHeight),
      Offset(size.width, headerHeight),
      paint,
    );
    for (var section = 1; section <= periodCount; section++) {
      final y = headerHeight + section * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridPainter oldDelegate) =>
      oldDelegate.periodWidth != periodWidth ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.dayCount != dayCount ||
      oldDelegate.periodCount != periodCount ||
      oldDelegate.headerHeight != headerHeight ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.lineColor != lineColor;
}

class ScheduleDayHeader extends StatelessWidget {
  const ScheduleDayHeader({required this.day, super.key});

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
        color: day.isToday ? scheme.primaryContainer : scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${day.date.day}',
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1,
                    ),
              ),
              if (day.marker != null)
                Text(
                  day.marker!,
                  maxLines: 1,
                  style: TextStyle(
                    color: markerColor,
                    fontSize: 9,
                    height: 1,
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

class ScheduleTimeAxis extends StatelessWidget {
  const ScheduleTimeAxis({
    required this.section,
    required this.showTime,
    super.key,
  });

  final int section;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final period = const NwuPeriodRepository().byNumber(section);
    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        showTime
            ? '$section\n${period.startLabel}\n${period.endLabel}'
            : '$section',
        textAlign: TextAlign.center,
        maxLines: showTime ? 3 : 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
      ),
    );
  }
}
