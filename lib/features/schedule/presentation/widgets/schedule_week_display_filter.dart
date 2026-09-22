import '../../../../domain/schedule/week_schedule_view_model.dart';

/// Applies presentation-only rules for ghost courses in the week grid.
///
/// Inactive entries are useful as a light comparison with another teaching
/// week, but they must not cover a real course in the selected week. The
/// domain model remains untouched; this filter only controls what the current
/// view is allowed to render.
class ScheduleWeekDisplayFilter {
  const ScheduleWeekDisplayFilter._();

  static WeekScheduleViewModel hideConflictingInactive(
    WeekScheduleViewModel model,
  ) {
    final activeByWeekday = <int, List<ScheduleGridEntry>>{};
    for (final entry in model.entries) {
      if (!entry.active) continue;
      activeByWeekday.putIfAbsent(entry.weekday, () => []).add(entry);
    }

    final filtered = model.entries.where((entry) {
      if (entry.active) return true;
      final activeEntries = activeByWeekday[entry.weekday] ?? const [];
      return !activeEntries.any(
        (active) =>
            active.startSection <= entry.endSection &&
            entry.startSection <= active.endSection,
      );
    }).toList(growable: false);

    return WeekScheduleViewModel(
      week: model.week,
      days: model.days,
      entries: filtered,
    );
  }
}
