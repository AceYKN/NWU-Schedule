import '../../../../core/nwu/periods.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';

/// Shared geometry for the week canvas. Keeping these values in one place
/// prevents the time rail and event cards from drifting apart as the visual
/// design evolves.
class ScheduleGridMetrics {
  const ScheduleGridMetrics._();

  static const headerHeight = 54.0;
  static const periodHeight = 68.0;
  static const timeRailWidth = 46.0;
  static const compactTimeRailWidth = 34.0;
  static const eventGap = 3.0;
  static const afternoonGap = 6.0;
  static const eveningGap = 8.0;

  static double sectionTop(int section,
      {double rowHeight = periodHeight,
      double dayHeaderHeight = headerHeight}) {
    if (section < 1) return dayHeaderHeight;
    var extra = 0.0;
    if (section > 5) extra += afternoonGap;
    if (section > 9) extra += eveningGap;
    return dayHeaderHeight + (section - 1) * rowHeight + extra;
  }

  static double sectionHeight(int startSection, int endSection,
      {double rowHeight = periodHeight}) {
    return sectionTop(endSection, rowHeight: rowHeight) +
        rowHeight -
        sectionTop(startSection, rowHeight: rowHeight);
  }

  static double canvasHeight(int periodCount,
      {double rowHeight = periodHeight,
      double dayHeaderHeight = headerHeight}) {
    return sectionTop(periodCount,
            rowHeight: rowHeight, dayHeaderHeight: dayHeaderHeight) +
        rowHeight;
  }

  static double currentTimeTop(int section, int minutes,
      {double rowHeight = periodHeight,
      double dayHeaderHeight = headerHeight}) {
    final periodStart = _periodStart(section);
    final periodEnd = _periodEnd(section);
    final fraction =
        ((minutes - periodStart) / (periodEnd - periodStart)).clamp(0.0, 1.0);
    return sectionTop(section,
            rowHeight: rowHeight, dayHeaderHeight: dayHeaderHeight) +
        fraction * rowHeight;
  }

  static int _periodStart(int section) =>
      const NwuPeriodRepository().byNumber(section).startMinutes;
  static int _periodEnd(int section) =>
      const NwuPeriodRepository().byNumber(section).endMinutes;
}

/// A display item produced from the effective schedule. An overflow item
/// deliberately replaces all but the first event in a group once more than
/// two courses collide; that keeps the grid readable on a phone.
class ScheduleLayoutItem {
  const ScheduleLayoutItem.event({
    required this.entry,
    required this.dayIndex,
    required this.lane,
    required this.laneCount,
  })  : overflowEntries = const [],
        startSection = null,
        endSection = null;

  const ScheduleLayoutItem.overflow({
    required this.overflowEntries,
    required this.dayIndex,
    required this.lane,
    required this.laneCount,
    required this.startSection,
    required this.endSection,
  }) : entry = null;

  final ScheduleGridEntry? entry;
  final List<ScheduleGridEntry> overflowEntries;
  final int dayIndex;
  final int lane;
  final int laneCount;
  final int? startSection;
  final int? endSection;

  bool get isOverflow => entry == null;

  int get effectiveStartSection =>
      entry?.startSection ?? startSection ?? overflowEntries.first.startSection;

  int get effectiveEndSection =>
      entry?.endSection ?? endSection ?? overflowEntries.first.endSection;
}

class ScheduleLayoutEngine {
  const ScheduleLayoutEngine._();

  static List<ScheduleLayoutItem> place({
    required List<WeekDayColumn> visibleDays,
    required Iterable<ScheduleGridEntry> entries,
  }) {
    final placed = <ScheduleLayoutItem>[];
    for (var dayIndex = 0; dayIndex < visibleDays.length; dayIndex++) {
      final weekday = visibleDays[dayIndex].weekday;
      final dayEntries = entries
          .where((entry) => entry.weekday == weekday)
          .toList(growable: false)
        ..sort(_compareEntries);

      final group = <ScheduleGridEntry>[];
      var groupEnd = 0;
      for (final entry in dayEntries) {
        if (group.isNotEmpty && entry.startSection > groupEnd) {
          _placeGroup(group, dayIndex: dayIndex, placed: placed);
          group.clear();
          groupEnd = 0;
        }
        group.add(entry);
        groupEnd = groupEnd > entry.endSection ? groupEnd : entry.endSection;
      }
      _placeGroup(group, dayIndex: dayIndex, placed: placed);
    }
    return List.unmodifiable(placed);
  }

  static int _compareEntries(ScheduleGridEntry left, ScheduleGridEntry right) {
    final start = left.startSection.compareTo(right.startSection);
    if (start != 0) return start;
    final end = right.endSection.compareTo(left.endSection);
    if (end != 0) return end;
    if (left.active != right.active) return left.active ? -1 : 1;
    return left.course.name.compareTo(right.course.name);
  }

  static void _placeGroup(
    List<ScheduleGridEntry> group, {
    required int dayIndex,
    required List<ScheduleLayoutItem> placed,
  }) {
    if (group.isEmpty) return;

    final lanes = <List<ScheduleGridEntry>>[];
    final laneByEntry = <ScheduleGridEntry, int>{};
    for (final entry in group) {
      var lane = 0;
      while (lane < lanes.length &&
          lanes[lane].any((other) => _overlaps(other, entry))) {
        lane++;
      }
      if (lane == lanes.length) lanes.add([]);
      lanes[lane].add(entry);
      laneByEntry[entry] = lane;
    }

    if (lanes.length > 2) {
      final hidden = group.skip(1).toList(growable: false);
      placed.add(
        ScheduleLayoutItem.event(
          entry: group.first,
          dayIndex: dayIndex,
          lane: 0,
          laneCount: 2,
        ),
      );
      placed.add(
        ScheduleLayoutItem.overflow(
          overflowEntries: hidden,
          dayIndex: dayIndex,
          lane: 1,
          laneCount: 2,
          startSection: group.map((item) => item.startSection).reduce(
                (left, right) => left < right ? left : right,
              ),
          endSection: group.map((item) => item.endSection).reduce(
                (left, right) => left > right ? left : right,
              ),
        ),
      );
      return;
    }

    final laneCount = lanes.length;
    for (final entry in group) {
      placed.add(
        ScheduleLayoutItem.event(
          entry: entry,
          dayIndex: dayIndex,
          lane: laneByEntry[entry]!,
          laneCount: laneCount,
        ),
      );
    }
  }

  static bool _overlaps(ScheduleGridEntry left, ScheduleGridEntry right) {
    return left.startSection <= right.endSection &&
        right.startSection <= left.endSection;
  }
}
