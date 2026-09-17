import '../../core/nwu/periods.dart';
import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/week_mask.dart';
import '../calendar/calendar_engine.dart';
import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';
import 'effective_course_instance.dart';
import 'schedule_now_state.dart';

/// The single source of truth for effective course instances.
///
/// UI, notification, and widget adapters should call this engine instead of
/// implementing their own weekday/week-mask/exception logic.
class ScheduleEngine {
  ScheduleEngine({
    required this.calendarEngine,
    required Iterable<Course> courses,
    required Iterable<MeetingRule> meetingRules,
    required Iterable<CourseException> exceptions,
    NwuPeriodRepository periodRepository = const NwuPeriodRepository(),
  })  : courses = List.unmodifiable(courses),
        meetingRules = List.unmodifiable(meetingRules),
        exceptions = List.unmodifiable(exceptions),
        periodRepository = periodRepository;

  final CalendarEngine calendarEngine;
  final List<Course> courses;
  final List<MeetingRule> meetingRules;
  final List<CourseException> exceptions;
  final NwuPeriodRepository periodRepository;

  Future<List<EffectiveCourseInstance>> getCoursesForDate(DateTime date) async {
    return _getCoursesForDate(date);
  }

  Future<ScheduleNowState> getStateAt(DateTime instant) async {
    final now = CampusClock.toCampusWallTime(instant);
    final todayCourses = _getCoursesForDate(now);
    final current = todayCourses
        .where(
          (course) =>
              !now.isBefore(course.startTime) &&
              now.isBefore(course.endTime),
        )
        .toList();
    if (current.isNotEmpty) {
      return ScheduleCurrent(
        now: now,
        todayCourses: todayCourses,
        current: current.first,
      );
    }

    final nextToday = todayCourses
        .where((course) => course.startTime.isAfter(now))
        .toList();
    if (nextToday.isNotEmpty) {
      return ScheduleNext(
        now: now,
        todayCourses: todayCourses,
        next: nextToday.first,
      );
    }

    final next = await getNextCourse(instant);
    if (todayCourses.isEmpty) {
      return ScheduleNoClassToday(
        now: now,
        todayCourses: todayCourses,
        next: next,
      );
    }
    return ScheduleFinishedToday(
      now: now,
      todayCourses: todayCourses,
      next: next,
    );
  }

  Future<EffectiveCourseInstance?> getNextCourse(DateTime instant) async {
    final now = CampusClock.toCampusWallTime(instant);
    final startDate = dateOnly(now);
    final endDate = calendarEngine.definition.semesterEndDate;
    final days = endDate.difference(startDate).inDays;
    if (days < 0) {
      return null;
    }

    for (var offset = 0; offset <= days; offset++) {
      final date = startDate.add(Duration(days: offset));
      final coursesForDate = _getCoursesForDate(date);
      for (final course in coursesForDate) {
        if (course.endTime.isAfter(now)) {
          return course;
        }
      }
    }
    return null;
  }

  Future<List<EffectiveCourseInstance>> getCoursesForWeek(
    int teachingWeek,
  ) async {
    final start = calendarEngine.definition.weekStart(teachingWeek);
    final result = <EffectiveCourseInstance>[];
    for (var day = 0; day < 7; day++) {
      result.addAll(_getCoursesForDate(start.add(Duration(days: day))));
    }
    result.sort(_compareInstances);
    return result;
  }

  List<EffectiveCourseInstance> _getCoursesForDate(DateTime date) {
    final actualDate = dateOnly(date);
    final resolved = calendarEngine.resolve(actualDate);
    final result = <EffectiveCourseInstance>[];

    if (resolved.isTeachingDay && resolved.templateDate != null) {
      result.addAll(
        _baseInstancesForDate(
          actualDate: actualDate,
          templateDate: resolved.templateDate!,
        ),
      );
    }

    // Source exceptions are applied to the visible source date. A target
    // exception is then inserted even if the target is a holiday.
    for (final exception in exceptions) {
      if (exception.sourceDate == null ||
          !isSameDate(exception.sourceDate!, actualDate)) {
        continue;
      }
      if (exception.type == CourseExceptionType.cancel ||
          exception.type == CourseExceptionType.move) {
        result.removeWhere(
          (instance) => _matchesSource(instance, exception),
        );
      }
    }

    for (final exception in exceptions) {
      if (exception.targetDate == null ||
          !isSameDate(exception.targetDate!, actualDate)) {
        continue;
      }
      if (exception.type == CourseExceptionType.move ||
          exception.type == CourseExceptionType.add) {
        final inserted = _buildExceptionInstance(exception, actualDate);
        if (inserted != null) {
          result.add(inserted);
        }
      }
    }

    result.sort(_compareInstances);
    return List.unmodifiable(result);
  }

  List<EffectiveCourseInstance> _baseInstancesForDate({
    required DateTime actualDate,
    required DateTime templateDate,
  }) {
    final week = calendarEngine.weekOf(templateDate);
    if (week == null) {
      return const [];
    }
    final result = <EffectiveCourseInstance>[];
    for (final course in courses) {
      if (course.deleted || course.hidden) {
        continue;
      }
      for (final rule in meetingRules) {
        if (rule.courseId != course.id ||
            rule.weekday != templateDate.weekday ||
            !rule.includesWeek(week)) {
          continue;
        }
        result.add(
          _createInstance(
            course: course,
            rule: rule,
            actualDate: actualDate,
            templateDate: templateDate,
            startSection: rule.startSection,
            endSection: rule.endSection,
            teacher: rule.teacher,
            campus: rule.campus,
            room: rule.room,
          ),
        );
      }
    }
    result.sort(_compareInstances);
    return result;
  }

  EffectiveCourseInstance? _buildExceptionInstance(
    CourseException exception,
    DateTime targetDate,
  ) {
    Course? course;
    MeetingRule? sourceRule;
    DateTime templateDate = targetDate;
    var teacher = exception.teacherOverride;
    var campus = exception.campusOverride;
    var room = exception.roomOverride;
    var startSection = exception.targetStartSection;
    var endSection = exception.targetEndSection;

    if (exception.type == CourseExceptionType.move) {
      if (exception.sourceDate == null || exception.courseId == null) {
        return null;
      }
      course = _findCourse(exception.courseId!);
      sourceRule = _findRule(exception.courseId!, exception.sourceMeetingId);
      if (course == null || sourceRule == null) {
        return null;
      }
      final sourceResolved = calendarEngine.resolve(exception.sourceDate!);
      templateDate = sourceResolved.templateDate ?? exception.sourceDate!;
      teacher ??= sourceRule.teacher;
      campus ??= sourceRule.campus;
      room ??= sourceRule.room;
      startSection ??= sourceRule.startSection;
      endSection ??= sourceRule.endSection;
    } else {
      if (exception.courseId != null) {
        course = _findCourse(exception.courseId!);
        sourceRule = _findRule(exception.courseId!, exception.sourceMeetingId);
      }
      if (course == null) {
        course = Course(
          id: exception.id,
          semesterId: calendarEngine.definition.id,
          sourceType: CourseSourceType.manual,
          name: exception.addedCourseName ?? '临时课程',
        );
      }
      if (sourceRule != null) {
        teacher ??= sourceRule.teacher;
        campus ??= sourceRule.campus;
        room ??= sourceRule.room;
        startSection ??= sourceRule.startSection;
        endSection ??= sourceRule.endSection;
      }
    }

    if (startSection == null || endSection == null) {
      return null;
    }
    final resolvedCourse = course;
    if (resolvedCourse == null) {
      return null;
    }
    final syntheticRule = sourceRule ??
        MeetingRule(
          id: exception.sourceMeetingId ?? '${exception.id}-rule',
          courseId: resolvedCourse.id,
          weekday: targetDate.weekday,
          startSection: startSection,
          endSection: endSection,
          teacher: teacher,
          campus: campus,
          room: room,
          weekMask: const WeekMask(0, rawText: 'exception'),
        );
    return _createInstance(
      course: resolvedCourse,
      rule: syntheticRule,
      actualDate: targetDate,
      templateDate: templateDate,
      startSection: startSection,
      endSection: endSection,
      teacher: teacher ?? syntheticRule.teacher,
      campus: campus ?? syntheticRule.campus,
      room: room ?? syntheticRule.room,
      isException: true,
      exceptionType: exception.type,
    );
  }

  Course? _findCourse(String id) {
    for (final course in courses) {
      if (course.id == id && !course.deleted && !course.hidden) {
        return course;
      }
    }
    return null;
  }

  MeetingRule? _findRule(String courseId, String? ruleId) {
    for (final rule in meetingRules) {
      if (rule.courseId == courseId &&
          (ruleId == null || rule.id == ruleId)) {
        return rule;
      }
    }
    return null;
  }

  bool _matchesSource(
    EffectiveCourseInstance instance,
    CourseException exception,
  ) {
    return (exception.courseId == null ||
            instance.course.id == exception.courseId) &&
        (exception.sourceMeetingId == null ||
            instance.meetingRule?.id == exception.sourceMeetingId);
  }

  EffectiveCourseInstance _createInstance({
    required Course course,
    required MeetingRule rule,
    required DateTime actualDate,
    required DateTime templateDate,
    required int startSection,
    required int endSection,
    String? teacher,
    String? campus,
    String? room,
    bool isException = false,
    CourseExceptionType? exceptionType,
  }) {
    final startPeriod = periodRepository.byNumber(startSection);
    final endPeriod = periodRepository.byNumber(endSection);
    return EffectiveCourseInstance(
      course: course,
      meetingRule: rule,
      date: actualDate,
      templateDate: templateDate,
      startSection: startSection,
      endSection: endSection,
      startTime: startPeriod.startAt(actualDate),
      endTime: endPeriod.endAt(actualDate),
      teacher: teacher,
      campus: campus,
      room: room,
      isException: isException,
      exceptionType: exceptionType,
    );
  }

  static int _compareInstances(
    EffectiveCourseInstance left,
    EffectiveCourseInstance right,
  ) {
    final byDate = left.date.compareTo(right.date);
    if (byDate != 0) {
      return byDate;
    }
    final byStart = left.startTime.compareTo(right.startTime);
    if (byStart != 0) {
      return byStart;
    }
    return left.courseName.compareTo(right.courseName);
  }
}
