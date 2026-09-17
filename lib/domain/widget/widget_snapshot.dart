import 'dart:convert';

import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../schedule/effective_course_instance.dart';
import '../schedule/schedule_engine.dart';

class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAtUtc,
    required this.next,
    required this.today,
    required this.tomorrow,
  });

  final DateTime generatedAtUtc;
  final WidgetCourseItem? next;
  final List<WidgetCourseItem> today;
  final List<WidgetCourseItem> tomorrow;

  Map<String, Object?> toJson() => {
        'generatedAt': generatedAtUtc.toUtc().toIso8601String(),
        'next': next?.toJson(),
        'today': today.map((item) => item.toJson()).toList(),
        'tomorrow': tomorrow.map((item) => item.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());
}

class WidgetCourseItem {
  const WidgetCourseItem({
    required this.courseId,
    required this.courseName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startSection,
    required this.endSection,
    required this.location,
    required this.teacher,
    required this.isException,
  });

  final String courseId;
  final String courseName;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int startSection;
  final int endSection;
  final String? location;
  final String? teacher;
  final bool isException;

  Map<String, Object?> toJson() => {
        'courseId': courseId,
        'courseName': courseName,
        'date': dateOnly(date).toIso8601String(),
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'startSection': startSection,
        'endSection': endSection,
        'location': location,
        'teacher': teacher,
        'isException': isException,
      };
}

class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder();

  WidgetSnapshot build({
    required ScheduleEngine engine,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    final campusNow = CampusClock.toCampusWallTime(nowUtc);
    final today = dateOnly(campusNow);
    final tomorrow = today.add(const Duration(days: 1));
    return WidgetSnapshot(
      generatedAtUtc: nowUtc,
      next: _item(engine.getNextCourse(nowUtc)),
      today: [
        for (final instance in engine.getCoursesForDate(today))
          _item(instance)!,
      ],
      tomorrow: [
        for (final instance in engine.getCoursesForDate(tomorrow))
          _item(instance)!,
      ],
    );
  }

  static WidgetCourseItem? _item(EffectiveCourseInstance? instance) {
    if (instance == null) return null;
    return WidgetCourseItem(
      courseId: instance.course.id,
      courseName: instance.courseName,
      date: instance.date,
      startTime: instance.startTime,
      endTime: instance.endTime,
      startSection: instance.startSection,
      endSection: instance.endSection,
      location: instance.location,
      teacher: instance.teacher,
      isException: instance.isException,
    );
  }
}
