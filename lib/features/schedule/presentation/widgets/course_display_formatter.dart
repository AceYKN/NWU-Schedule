import '../../../../domain/schedule/week_schedule_view_model.dart';

/// Presentation-only formatting for the dense week grid.
///
/// The stored course name and location are never changed. The grid keeps the
/// complete display values and lets the card scale them to its available
/// width instead of silently removing meaningful information.
class CourseDisplayFormatter {
  const CourseDisplayFormatter._();

  static String title(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? value : normalized;
  }

  static String? location(ScheduleGridEntry entry) {
    final values = [entry.campus, entry.room]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? null : values.join('\n');
  }

  static String semanticsLabel(ScheduleGridEntry entry) {
    final locationValue = entry.instance.location;
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
