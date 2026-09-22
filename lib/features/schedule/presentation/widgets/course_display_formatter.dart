import '../../../../domain/schedule/week_schedule_view_model.dart';

/// Presentation-only formatting for the dense week grid.
///
/// The stored course name and location are never changed. These helpers only
/// remove common display noise or choose the most useful short value when a
/// course cell is narrow.
class CourseDisplayFormatter {
  const CourseDisplayFormatter._();

  static String title(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return value;
    final withoutSuffix = normalized
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return withoutSuffix.isEmpty ? normalized : withoutSuffix;
  }

  static String? location(ScheduleGridEntry entry) {
    final room = entry.room?.trim();
    if (room != null && room.isNotEmpty) return room;
    final campus = entry.campus?.trim();
    if (campus != null && campus.isNotEmpty) return campus;
    return null;
  }

  static String semanticsLabel(ScheduleGridEntry entry) {
    final locationValue = location(entry);
    return [
      title(entry.course.name),
      '星期${entry.weekday == 7 ? '日' : '一二三四五六'[entry.weekday - 1]}',
      '第${entry.startSection}-${entry.endSection}节',
      if (locationValue != null) locationValue,
      if (entry.teacher != null && entry.teacher!.trim().isNotEmpty)
        entry.teacher!,
      if (!entry.active) '非本周课程',
    ].join('，');
  }
}
