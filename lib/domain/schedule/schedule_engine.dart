import '../../core/nwu/periods.dart';
import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/week_mask.dart';
import '../calendar/calendar_definition.dart';
import '../calendar/calendar_engine.dart';
import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';
import 'effective_course_instance.dart';
import 'schedule_now_state.dart';
import 'week_schedule_view_model.dart';

/// The single source of truth for effective course instances.
///
/// UI, notification, and widget adapters should call this engine instead of
/// implementing their own weekday/week-mask/exception logic.
class ScheduleEngine {
  ScheduleEngine({
    required this.semesterId,
    required this.calendarEngine,
    required Iterable<Course> courses,
    required Iterable<MeetingRule> meetingRules,
    required Iterable<CourseException> exceptions,
    this.periodRepository = const NwuPeriodRepository(),
  })  : courses = List.unmodifiable(
          courses.where((course) => course.semesterId == semesterId),
        ),
        meetingRules = List.unmodifiable(meetingRules),
        exceptions = List.unmodifiable(
          exceptions.where((exception) => exception.semesterId == semesterId),
        ) {
    if (semesterId.trim().isEmpty) {
      throw ArgumentError.value(semesterId, 'semesterId');
    }
  }

  final String semesterId;
  final CalendarEngine calendarEngine;
  final List<Course> courses;
  final List<MeetingRule> meetingRules;
  final List<CourseException> exceptions;
  final NwuPeriodRepository periodRepository;

  /// The calendar definition used by this schedule. Presentation code should
  /// use this read-only view through [ScheduleEngine] rather than reaching
  /// into [CalendarEngine] directly.
  CalendarDefinition get calendarDefinition => calendarEngine.definition;

  int get totalWeeks => calendarDefinition.totalWeeks;

  int get calendarRevision => calendarDefinition.revision;

  DateTime weekStart(int teachingWeek) =>
      calendarDefinition.weekStart(teachingWeek);

  ResolvedCalendarDate resolveDate(DateTime date) =>
      calendarEngine.resolve(date);

  List<EffectiveCourseInstance> getCoursesForDate(DateTime date) {
    return _getCoursesForDate(date);
  }

  /// Resolves the teaching week for an absolute instant using the NWU campus
  /// timezone. Presentation code should use this boundary instead of asking
  /// [CalendarEngine] to interpret a device-local clock directly.
  int? teachingWeekAt(DateTime instant) {
    return calendarEngine.weekOf(CampusClock.toCampusWallTime(instant));
  }

  ScheduleNowState getStateAt(DateTime instant) {
    final now = CampusClock.toCampusWallTime(instant);
    final todayCourses = _getCoursesForDate(now);
    final current = todayCourses
        .where(
          (course) =>
              !now.isBefore(course.startTime) && now.isBefore(course.endTime),
        )
        .toList();
    if (current.isNotEmpty) {
      return ScheduleCurrent(
        now: now,
        todayCourses: todayCourses,
        current: current.first,
      );
    }

    final nextToday =
        todayCourses.where((course) => course.startTime.isAfter(now)).toList();
    if (nextToday.isNotEmpty) {
      return ScheduleNext(
        now: now,
        todayCourses: todayCourses,
        next: nextToday.first,
      );
    }

    final next = getNextCourse(instant);
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

  EffectiveCourseInstance? getNextCourse(DateTime instant) {
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
        if (course.startTime.isAfter(now)) {
          return course;
        }
      }
    }
    return null;
  }

  List<EffectiveCourseInstance> getCoursesForWeek(
    int teachingWeek,
  ) {
    final start = calendarEngine.definition.weekStart(teachingWeek);
    final result = <EffectiveCourseInstance>[];
    for (var day = 0; day < 7; day++) {
      result.addAll(_getCoursesForDate(start.add(Duration(days: day))));
    }
    result.sort(_compareInstances);
    return result;
  }

  WeekScheduleViewModel getWeekViewModel(
    int teachingWeek, {
    bool includeInactive = false,
  }) {
    if (teachingWeek < 1 ||
        teachingWeek > calendarEngine.definition.totalWeeks) {
      throw RangeError.range(
        teachingWeek,
        1,
        calendarEngine.definition.totalWeeks,
        'teachingWeek',
      );
    }
    final weekStart = calendarEngine.definition.weekStart(teachingWeek);
    final days = <WeekDayColumn>[];
    final entries = <ScheduleGridEntry>[];
    final now = CampusClock.now();
    for (var offset = 0; offset < 7; offset++) {
      final date = weekStart.add(Duration(days: offset));
      final resolved = calendarEngine.resolve(date);
      days.add(
        WeekDayColumn(
          weekday: date.weekday,
          date: date,
          label: _weekdayLabel(date.weekday),
          marker: switch (resolved.override?.type) {
            CalendarOverrideType.holiday => '休',
            CalendarOverrideType.useScheduleOf => '调',
            null => null,
          },
          isToday: isSameDate(date, now),
        ),
      );
      for (final instance in _getCoursesForDate(date)) {
        entries.add(ScheduleGridEntry(instance: instance, active: true));
      }
      if (includeInactive) {
        for (final instance in _inactiveInstancesForDate(date)) {
          entries.add(ScheduleGridEntry(instance: instance, active: false));
        }
      }
    }
    entries.sort((left, right) {
      final byDay = left.weekday.compareTo(right.weekday);
      if (byDay != 0) return byDay;
      final bySection = left.startSection.compareTo(right.startSection);
      if (bySection != 0) return bySection;
      if (left.active != right.active) return left.active ? -1 : 1;
      return left.course.name.compareTo(right.course.name);
    });
    return WeekScheduleViewModel(
      week: teachingWeek,
      days: List.unmodifiable(days),
      entries: List.unmodifiable(entries),
    );
  }

  List<EffectiveCourseInstance> _inactiveInstancesForDate(DateTime date) {
    final actualDate = dateOnly(date);
    final resolved = calendarEngine.resolve(actualDate);
    if (!resolved.isTeachingDay || resolved.templateDate == null) {
      return const [];
    }
    final templateDate = resolved.templateDate!;
    final templateWeek = calendarEngine.weekOf(templateDate);
    if (templateWeek == null) return const [];
    final result = <EffectiveCourseInstance>[];
    for (final course in courses) {
      if (course.deleted || course.hidden) continue;
      for (final rule in meetingRules) {
        if (rule.courseId != course.id ||
            rule.weekday != templateDate.weekday ||
            rule.includesWeek(templateWeek) ||
            _hasSourceMoveOrCancel(actualDate, course.id, rule.id)) {
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
    return result;
  }

  bool _hasSourceMoveOrCancel(
    DateTime date,
    String courseId,
    String ruleId,
  ) {
    return exceptions.any(
      (exception) =>
          (exception.type == CourseExceptionType.move ||
              exception.type == CourseExceptionType.cancel) &&
          exception.sourceDate != null &&
          isSameDate(exception.sourceDate!, date) &&
          (exception.courseId == null || exception.courseId == courseId) &&
          (exception.sourceMeetingId == null ||
              exception.sourceMeetingId == ruleId),
    );
  }

  static String _weekdayLabel(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];

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
      course ??= Course(
        id: exception.id,
        semesterId: semesterId,
        sourceType: CourseSourceType.manual,
        name: exception.addedCourseName ?? '临时课程',
      );
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
      exceptionId: exception.id,
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
      if (rule.courseId == courseId && (ruleId == null || rule.id == ruleId)) {
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
    String? exceptionId,
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
      exceptionId: exceptionId,
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
