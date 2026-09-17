import '../../core/utils/week_mask.dart';
import '../../core/nwu/periods.dart';

class MeetingRule {
  MeetingRule({
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
  }) {
    if (id.trim().isEmpty || courseId.trim().isEmpty) {
      throw ArgumentError('MeetingRule id and courseId must be non-empty');
    }
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday');
    }
    if (startSection < 1 ||
        endSection > NwuPeriodRepository.all.length ||
        startSection > endSection) {
      throw ArgumentError('Invalid meeting section range');
    }
  }

  static const Object _unset = Object();

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
    Object? teacher = _unset,
    Object? campus = _unset,
    Object? room = _unset,
    WeekMask? weekMask,
  }) {
    return MeetingRule(
      id: id,
      courseId: courseId,
      sourceMeetingKey: sourceMeetingKey,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      teacher: identical(teacher, _unset) ? this.teacher : teacher as String?,
      campus: identical(campus, _unset) ? this.campus : campus as String?,
      room: identical(room, _unset) ? this.room : room as String?,
      weekMask: weekMask ?? this.weekMask,
    );
  }
}
