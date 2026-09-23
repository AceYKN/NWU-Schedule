import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/nwu/periods.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../../domain/settings/schedule_display_preferences.dart';
import 'course_block.dart';
import 'schedule_layout_engine.dart';

class ScheduleWeekGrid extends StatelessWidget {
  const ScheduleWeekGrid({
    required this.visibleDays,
    required this.viewModel,
    required this.preferences,
    required this.now,
    this.onEntryTap,
    super.key,
  });

  final List<WeekDayColumn> visibleDays;
  final WeekScheduleViewModel viewModel;
  final ScheduleDisplayPreferences preferences;
  final DateTime now;
  final ValueChanged<ScheduleGridEntry>? onEntryTap;

  @override
  Widget build(BuildContext context) {
    final periodWidth = preferences.showPeriodTimes
        ? ScheduleGridMetrics.timeRailWidth
        : ScheduleGridMetrics.compactTimeRailWidth;
    final periodCount = NwuPeriodRepository.all.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = math.max<double>(
          1,
          (constraints.maxWidth - periodWidth) / visibleDays.length,
        );
        final layout = ScheduleLayoutEngine.place(
          visibleDays: visibleDays,
          entries: viewModel.entries,
        );
        final current =
            preferences.highlightCurrentPeriod ? _currentPeriod() : null;
        final scheme = Theme.of(context).colorScheme;
        final canvasHeight = ScheduleGridMetrics.canvasHeight(periodCount);

        return ColoredBox(
          color: scheme.surface,
          child: SizedBox(
            height: canvasHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScheduleDayBackgroundPainter(
                        periodWidth: periodWidth,
                        dayWidth: dayWidth,
                        colors: [
                          for (final day in visibleDays)
                            _dayBackgroundColor(day, scheme),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScheduleGridPainter(
                        periodWidth: periodWidth,
                        dayWidth: dayWidth,
                        dayCount: visibleDays.length,
                        periodCount: periodCount,
                        lineColor: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  for (var index = 0; index < visibleDays.length; index++)
                    Positioned(
                      left: periodWidth + index * dayWidth,
                      top: 0,
                      width: dayWidth,
                      height: ScheduleGridMetrics.headerHeight,
                      child: ScheduleDayHeader(day: visibleDays[index]),
                    ),
                  for (var section = 1; section <= periodCount; section++)
                    Positioned(
                      left: 0,
                      top: ScheduleGridMetrics.sectionTop(section),
                      width: periodWidth,
                      height: ScheduleGridMetrics.periodHeight,
                      child: ScheduleTimeAxis(
                        section: section,
                        showTime: preferences.showPeriodTimes,
                      ),
                    ),
                  for (final item in layout)
                    _buildLayoutItem(
                      context,
                      item: item,
                      periodWidth: periodWidth,
                      dayWidth: dayWidth,
                      visibleDayCount: visibleDays.length,
                    ),
                  if (current != null)
                    Positioned(
                      left: periodWidth + current.dayIndex * dayWidth,
                      width: dayWidth,
                      top: current.top - 9,
                      height: 18,
                      child: CurrentTimeIndicator(label: current.label),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutItem(
    BuildContext context, {
    required ScheduleLayoutItem item,
    required double periodWidth,
    required double dayWidth,
    required int visibleDayCount,
  }) {
    final width = math.max<double>(
      8,
      dayWidth / item.laneCount - ScheduleGridMetrics.eventGap,
    );
    final height = math.max<double>(
      24,
      ScheduleGridMetrics.sectionHeight(
            item.effectiveStartSection,
            item.effectiveEndSection,
          ) -
          ScheduleGridMetrics.eventGap,
    );
    final left = periodWidth +
        item.dayIndex * dayWidth +
        item.lane * (dayWidth / item.laneCount) +
        ScheduleGridMetrics.eventGap / 2;
    final top = ScheduleGridMetrics.sectionTop(item.effectiveStartSection) +
        ScheduleGridMetrics.eventGap / 2;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: item.isOverflow
          ? OverflowCourseBlock(
              entries: item.overflowEntries,
              height: height,
              onEntryTap: onEntryTap,
            )
          : CourseBlock(
              entry: item.entry!,
              preferences: preferences,
              width: width,
              height: height,
              visibleDayCount: visibleDayCount,
              isCurrent: _isCurrentEntry(item.entry!),
              onTap: onEntryTap == null ? null : () => onEntryTap!(item.entry!),
            ),
    );
  }

  bool _isCurrentEntry(ScheduleGridEntry entry) {
    final current = _currentPeriod();
    return current != null &&
        entry.active &&
        entry.weekday == visibleDays[current.dayIndex].weekday &&
        entry.startSection <= current.section &&
        current.section <= entry.endSection;
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
          dayIndex: dayIndex,
          section: period.number,
          top: ScheduleGridMetrics.currentTimeTop(period.number, minutes),
          label: formatMinutes(minutes),
        );
      }
    }
    return null;
  }
}

class _CurrentPeriod {
  const _CurrentPeriod({
    required this.dayIndex,
    required this.section,
    required this.top,
    required this.label,
  });

  final int dayIndex;
  final int section;
  final double top;
  final String label;
}

Color _dayBackgroundColor(WeekDayColumn day, ColorScheme scheme) {
  final amount = scheme.brightness == Brightness.light ? .05 : .09;
  return switch (day.kind) {
    ScheduleDayKind.normal => scheme.surface,
    ScheduleDayKind.holiday => Color.lerp(
        scheme.surface,
        scheme.errorContainer,
        amount,
      )!,
    ScheduleDayKind.makeup => Color.lerp(
        scheme.surface,
        scheme.tertiaryContainer,
        amount,
      )!,
  };
}

Color _dayStatusForeground(WeekDayColumn day, ColorScheme scheme) =>
    switch (day.kind) {
      ScheduleDayKind.normal => scheme.onSurfaceVariant,
      ScheduleDayKind.holiday => scheme.error,
      ScheduleDayKind.makeup => scheme.tertiary,
    };

class _ScheduleDayBackgroundPainter extends CustomPainter {
  const _ScheduleDayBackgroundPainter({
    required this.periodWidth,
    required this.dayWidth,
    required this.colors,
  });

  final double periodWidth;
  final double dayWidth;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < colors.length; index++) {
      canvas.drawRect(
        Rect.fromLTWH(periodWidth + index * dayWidth, 0, dayWidth, size.height),
        Paint()..color = colors[index],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleDayBackgroundPainter oldDelegate) {
    if (oldDelegate.periodWidth != periodWidth ||
        oldDelegate.dayWidth != dayWidth ||
        oldDelegate.colors.length != colors.length) {
      return true;
    }
    for (var index = 0; index < colors.length; index++) {
      if (oldDelegate.colors[index] != colors[index]) return true;
    }
    return false;
  }
}

class CurrentTimeIndicator extends StatelessWidget {
  const CurrentTimeIndicator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 4,
            right: 0,
            top: 8,
            child: Divider(color: color, thickness: 1.5, height: 1),
          ),
          Positioned(
            left: 0,
            top: 5,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleGridPainter extends CustomPainter {
  const _ScheduleGridPainter({
    required this.periodWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.periodCount,
    required this.lineColor,
  });

  final double periodWidth;
  final double dayWidth;
  final int dayCount;
  final int periodCount;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = lineColor.withValues(alpha: .22)
      ..strokeWidth = .7;
    final groupPaint = Paint()
      ..color = lineColor.withValues(alpha: .42)
      ..strokeWidth = 1;
    final verticalPaint = Paint()
      ..color = lineColor.withValues(alpha: .12)
      ..strokeWidth = .7;

    canvas.drawLine(
      Offset(0, ScheduleGridMetrics.headerHeight),
      Offset(size.width, ScheduleGridMetrics.headerHeight),
      groupPaint,
    );
    for (var section = 1; section <= periodCount; section++) {
      final y = ScheduleGridMetrics.sectionTop(section) +
          ScheduleGridMetrics.periodHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        section == 4 || section == 8 ? groupPaint : lightPaint,
      );
    }
    canvas.drawLine(
      Offset(periodWidth, 0),
      Offset(periodWidth, size.height),
      groupPaint,
    );
    for (var day = 1; day < dayCount; day++) {
      final x = periodWidth + day * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridPainter oldDelegate) {
    return oldDelegate.periodWidth != periodWidth ||
        oldDelegate.dayWidth != dayWidth ||
        oldDelegate.dayCount != dayCount ||
        oldDelegate.periodCount != periodCount ||
        oldDelegate.lineColor != lineColor;
  }
}

class ScheduleDayHeader extends StatelessWidget {
  const ScheduleDayHeader({required this.day, super.key});

  final WeekDayColumn day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = day.shortMarker;
    final semanticParts = [
      '星期${day.label}',
      '${day.date.month}月${day.date.day}日',
      if (day.calendarLabel?.trim().isNotEmpty == true) day.calendarLabel!,
      if (day.kind == ScheduleDayKind.holiday)
        '休假'
      else if (day.kind == ScheduleDayKind.makeup && marker == '补')
        '补班'
      else if (day.kind == ScheduleDayKind.makeup)
        '调课',
    ];
    return Semantics(
      container: true,
      label: semanticParts.join('，'),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            44.0,
            math.max(30.0, constraints.maxWidth - 4),
          );
          return Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: _dayStatusForeground(day, scheme),
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: day.isToday
                          ? BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(7),
                            )
                          : const BoxDecoration(),
                      child: Center(
                        child: Text(
                          '${day.date.day}',
                          maxLines: 1,
                          style: TextStyle(
                            color: day.isToday ? scheme.onPrimary : null,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (marker != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      marker,
                      style: TextStyle(
                        color: _dayStatusForeground(day, scheme),
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$section',
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          if (showTime) ...[
            const SizedBox(height: 3),
            Text(
              period.startLabel,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              period.endLabel,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
