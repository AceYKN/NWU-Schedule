import '../../core/utils/week_mask.dart';

class MeetingRule {
  const MeetingRule({
    required this.id,
    required this.courseId,
    this.sourceMeetingKey,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    this.teacher,
    this.campus,
    this.room,
    required this.weekMask,
  });

  final String id;
  final String courseId;
  final String? sourceMeetingKey;
  /// ISO weekday: Monday = 1, Sunday = 7.
  final int weekday;
  final int startSection;
  final int endSection;
  final String? teacher;
  final String? campus;
  final String? room;
  final WeekMask weekMask;

  bool includesWeek(int week) => weekMask.contains(week);

  MeetingRule copyWith({
    int? weekday,
    int? startSection,
    int? endSection,
    String? teacher,
    String? campus,
    String? room,
    WeekMask? weekMask,
  }) {
    return MeetingRule(
      id: id,
      courseId: courseId,
      sourceMeetingKey: sourceMeetingKey,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      teacher: teacher ?? this.teacher,
      campus: campus ?? this.campus,
      room: room ?? this.room,
      weekMask: weekMask ?? this.weekMask,
    );
  }
}
