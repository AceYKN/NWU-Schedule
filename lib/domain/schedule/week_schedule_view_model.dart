import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';
import 'effective_course_instance.dart';

class ScheduleGridEntry {
  const ScheduleGridEntry({required this.instance, required this.active});

  final EffectiveCourseInstance instance;
  final bool active;

  Course get course => instance.course;
  MeetingRule? get meetingRule => instance.meetingRule;
  int get weekday => instance.date.weekday;
  int get startSection => instance.startSection;
  int get endSection => instance.endSection;
  String? get room => instance.room;
  String? get campus => instance.campus;
  String? get teacher => instance.teacher;
  bool get isException => instance.isException;
  CourseExceptionType? get exceptionType => instance.exceptionType;
}

class WeekDayColumn {
  const WeekDayColumn({
    required this.weekday,
    required this.date,
    required this.label,
    required this.marker,
    required this.isToday,
  });

  final int weekday;
  final DateTime date;
  final String label;
  final String? marker;
  final bool isToday;
}

class WeekScheduleViewModel {
  const WeekScheduleViewModel({
    required this.week,
    required this.days,
    required this.entries,
  });

  final int week;
  final List<WeekDayColumn> days;
  final List<ScheduleGridEntry> entries;

  int get activeWeekendCount =>
      entries.where((entry) => entry.active && entry.weekday >= 6).length;

  bool get hasHiddenWeekendCourses => activeWeekendCount > 0;

  List<ScheduleGridEntry> get activeEntries =>
      entries.where((entry) => entry.active).toList(growable: false);
}
