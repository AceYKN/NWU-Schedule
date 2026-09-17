import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';

class EffectiveCourseInstance {
  const EffectiveCourseInstance({
    required this.course,
    required this.meetingRule,
    required this.date,
    required this.templateDate,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.endTime,
    this.teacher,
    this.campus,
    this.room,
    this.isException = false,
    this.exceptionType,
    this.exceptionId,
  });

  final Course course;
  final MeetingRule? meetingRule;
  final DateTime date;
  final DateTime templateDate;
  final int startSection;
  final int endSection;
  final DateTime startTime;
  final DateTime endTime;
  final String? teacher;
  final String? campus;
  final String? room;
  final bool isException;
  final CourseExceptionType? exceptionType;
  final String? exceptionId;

  String get courseName => course.name;

  String? get location {
    final values = [campus, room]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return values.isEmpty ? null : values.join(' · ');
  }

  EffectiveCourseInstance copyWith({
    required int startSection,
    required int endSection,
    required DateTime startTime,
    required DateTime endTime,
    String? teacher,
    String? campus,
    String? room,
    bool? isException,
    CourseExceptionType? exceptionType,
    String? exceptionId,
    DateTime? date,
  }) {
    return EffectiveCourseInstance(
      course: course,
      meetingRule: meetingRule,
      date: date ?? this.date,
      templateDate: templateDate,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      teacher: teacher ?? this.teacher,
      campus: campus ?? this.campus,
      room: room ?? this.room,
      isException: isException ?? this.isException,
      exceptionType: exceptionType ?? this.exceptionType,
      exceptionId: exceptionId ?? this.exceptionId,
    );
  }
}
