import '../../core/utils/date_utils.dart';
import '../course/course.dart';
import '../course/course_canonicalizer.dart';
import '../course/course_exception.dart';
import '../course/course_identity.dart';
import '../course/meeting_rule.dart';
import 'effective_course_instance.dart';
import 'schedule_engine.dart';

class ScheduleConflict {
  const ScheduleConflict({required this.changed, required this.other});

  final EffectiveCourseInstance changed;
  final EffectiveCourseInstance other;

  DateTime get date => changed.date;
}

/// Compares effective schedules so holidays, makeup days, week masks and
/// temporary changes have the same meaning here as they do in the timetable.
abstract final class ScheduleConflictDetector {
  static List<ScheduleConflict> forCourseSave({
    required ScheduleEngine current,
    required Iterable<Course> changedCourses,
    required Iterable<MeetingRule> changedRules,
    Iterable<String> removeExceptionIds = const [],
  }) {
    final courses = changedCourses.toList(growable: false);
    final affectedIds = courses.map((course) => course.id).toSet();
    final removedIds = removeExceptionIds.toSet();
    final canonical = CourseCanonicalizer.canonicalize(
      courses: courses,
      meetingRules: changedRules,
      exceptions: current.exceptions.where((exception) =>
          exception.courseId != null &&
          affectedIds.contains(exception.courseId) &&
          !removedIds.contains(exception.id)),
    );
    final projected = _withChanges(
      current,
      courses: [
        for (final course in current.courses)
          if (!affectedIds.contains(course.id)) course,
        ...canonical.courses,
      ],
      rules: [
        for (final rule in current.meetingRules)
          if (!affectedIds.contains(rule.courseId)) rule,
        ...canonical.meetingRules,
      ],
      exceptions: [
        for (final exception in current.exceptions)
          if ((exception.courseId == null ||
                  !affectedIds.contains(exception.courseId)) &&
              !removedIds.contains(exception.id))
            exception,
        ...canonical.exceptions,
      ],
    );
    final changedIds = canonical.courses.map((course) => course.id).toSet();
    final beforeCourseIds = <String, String>{
      for (final course in courses)
        course.id: canonical.courses
            .firstWhere((candidate) =>
                candidate.semesterId == course.semesterId &&
                CourseIdentity.sameName(candidate.name, course.name))
            .id,
    };
    return _introducedConflicts(
      current,
      projected,
      isChanged: (instance) => changedIds.contains(instance.course.id),
      beforeCourseIds: beforeCourseIds,
    );
  }

  static List<ScheduleConflict> forExceptionSave({
    required ScheduleEngine current,
    required CourseException exception,
  }) {
    final projected = _withChanges(
      current,
      courses: current.courses,
      rules: current.meetingRules,
      exceptions: [
        for (final existing in current.exceptions)
          if (existing.id != exception.id) existing,
        exception,
      ],
    );
    return _introducedConflicts(
      current,
      projected,
      isChanged: (instance) => instance.exceptionId == exception.id,
    );
  }

  static ScheduleEngine _withChanges(
    ScheduleEngine source, {
    required Iterable<Course> courses,
    required Iterable<MeetingRule> rules,
    required Iterable<CourseException> exceptions,
  }) =>
      ScheduleEngine(
        semesterId: source.semesterId,
        calendarEngine: source.calendarEngine,
        courses: courses,
        meetingRules: rules,
        exceptions: exceptions,
        periodRepository: source.periodRepository,
      );

  static List<ScheduleConflict> _introducedConflicts(
    ScheduleEngine before,
    ScheduleEngine after, {
    required bool Function(EffectiveCourseInstance) isChanged,
    Map<String, String> beforeCourseIds = const {},
  }) {
    final existing = <String>{};
    final result = <ScheduleConflict>[];
    final calendar = after.calendarDefinition;
    for (var date = calendar.semesterStartDate;
        !date.isAfter(calendar.semesterEndDate);
        date = addCalendarDays(date, 1)) {
      for (final pair in _overlaps(before.getCoursesForDate(date))) {
        existing.add(_pairKey(pair.$1, pair.$2, courseIds: beforeCourseIds));
      }
      for (final pair in _overlaps(after.getCoursesForDate(date))) {
        if (existing.contains(_pairKey(pair.$1, pair.$2))) continue;
        final leftChanged = isChanged(pair.$1);
        final rightChanged = isChanged(pair.$2);
        if (!leftChanged && !rightChanged) continue;
        result.add(ScheduleConflict(
          changed: leftChanged ? pair.$1 : pair.$2,
          other: leftChanged ? pair.$2 : pair.$1,
        ));
      }
    }
    result.sort((left, right) {
      final date = left.date.compareTo(right.date);
      if (date != 0) return date;
      final time = left.changed.startTime.compareTo(right.changed.startTime);
      if (time != 0) return time;
      return left.other.courseName.compareTo(right.other.courseName);
    });
    return List.unmodifiable(result);
  }

  static Iterable<(EffectiveCourseInstance, EffectiveCourseInstance)> _overlaps(
      List<EffectiveCourseInstance> instances) sync* {
    for (var index = 0; index < instances.length; index++) {
      final left = instances[index];
      for (var otherIndex = index + 1;
          otherIndex < instances.length;
          otherIndex++) {
        final right = instances[otherIndex];
        if (left.course.id == right.course.id) continue;
        if (left.startTime.isBefore(right.endTime) &&
            right.startTime.isBefore(left.endTime)) {
          yield (left, right);
        }
      }
    }
  }

  static String _pairKey(
    EffectiveCourseInstance left,
    EffectiveCourseInstance right, {
    Map<String, String> courseIds = const {},
  }) {
    String key(EffectiveCourseInstance instance) => [
          courseIds[instance.course.id] ?? instance.course.id,
          instance.startSection,
          instance.endSection,
        ].join('|');
    final values = [key(left), key(right)]..sort();
    return '${dateKey(left.date)}|${values[0]}|${values[1]}';
  }
}
