import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';

enum AcademicDayType { normal, weekend, holiday, makeupDay }

class NextScheduleSummary {
  const NextScheduleSummary({
    required this.course,
    required this.dayType,
    required this.daysFromToday,
  });

  final EffectiveCourseInstance course;
  final AcademicDayType dayType;
  final int daysFromToday;
}

sealed class HomeScheduleState {
  const HomeScheduleState({
    required this.now,
    required this.todayCourses,
    required this.todayType,
    required this.next,
  });

  final DateTime now;
  final List<EffectiveCourseInstance> todayCourses;
  final AcademicDayType todayType;
  final NextScheduleSummary? next;
}

final class HomeInClassState extends HomeScheduleState {
  const HomeInClassState({
    required super.now,
    required super.todayCourses,
    required super.todayType,
    required super.next,
    required this.current,
    required this.remaining,
  });

  final EffectiveCourseInstance current;
  final Duration remaining;
}

final class HomeBeforeNextClassState extends HomeScheduleState {
  const HomeBeforeNextClassState({
    required super.now,
    required super.todayCourses,
    required super.todayType,
    required super.next,
    required this.course,
    required this.untilStart,
  });

  final EffectiveCourseInstance course;
  final Duration untilStart;
}

final class HomeTodayFinishedState extends HomeScheduleState {
  const HomeTodayFinishedState({
    required super.now,
    required super.todayCourses,
    required super.todayType,
    required super.next,
  });
}

final class HomeNoClassTodayState extends HomeScheduleState {
  const HomeNoClassTodayState({
    required super.now,
    required super.todayCourses,
    required super.todayType,
    required super.next,
  });
}

final class HomeOutsideTeachingTermState extends HomeScheduleState {
  const HomeOutsideTeachingTermState({
    required super.now,
    required super.todayCourses,
    required super.todayType,
    required super.next,
  });
}

/// Resolves the home hero state from the same effective schedule consumed by
/// the week view. Calendar labels are secondary context and never suppress a
/// real current or upcoming course.
class HomeScheduleStatusResolver {
  const HomeScheduleStatusResolver({this.lookAheadDays = 7});

  final int lookAheadDays;

  HomeScheduleState resolve({
    required ScheduleEngine engine,
    required DateTime now,
  }) {
    final campusNow = CampusClock.toCampusWallTime(now);
    final today = dateOnly(campusNow);
    final todayCourses = engine.getCoursesForDate(today);
    final todayType = _dayType(engine, today);
    final next = _findNext(engine, campusNow, today);

    for (final course in todayCourses) {
      if (!campusNow.isBefore(course.startTime) &&
          campusNow.isBefore(course.endTime)) {
        return HomeInClassState(
          now: campusNow,
          todayCourses: todayCourses,
          todayType: todayType,
          next: next,
          current: course,
          remaining: course.endTime.difference(campusNow),
        );
      }
    }

    for (final course in todayCourses) {
      if (course.startTime.isAfter(campusNow)) {
        return HomeBeforeNextClassState(
          now: campusNow,
          todayCourses: todayCourses,
          todayType: todayType,
          next: next,
          course: course,
          untilStart: course.startTime.difference(campusNow),
        );
      }
    }

    if (todayCourses.isNotEmpty) {
      return HomeTodayFinishedState(
        now: campusNow,
        todayCourses: todayCourses,
        todayType: todayType,
        next: next,
      );
    }

    if (engine.teachingWeekAt(now) == null) {
      return HomeOutsideTeachingTermState(
        now: campusNow,
        todayCourses: todayCourses,
        todayType: todayType,
        next: next,
      );
    }

    return HomeNoClassTodayState(
      now: campusNow,
      todayCourses: todayCourses,
      todayType: todayType,
      next: next,
    );
  }

  NextScheduleSummary? _findNext(
    ScheduleEngine engine,
    DateTime campusNow,
    DateTime today,
  ) {
    for (var offset = 0; offset <= lookAheadDays; offset++) {
      final date = today.add(Duration(days: offset));
      for (final course in engine.getCoursesForDate(date)) {
        if (course.startTime.isAfter(campusNow)) {
          return NextScheduleSummary(
            course: course,
            dayType: _dayType(engine, date),
            daysFromToday: offset,
          );
        }
      }
    }
    return null;
  }

  AcademicDayType _dayType(ScheduleEngine engine, DateTime date) {
    final resolved = engine.resolveDate(date);
    return switch (resolved.override?.type) {
      CalendarOverrideType.holiday => AcademicDayType.holiday,
      CalendarOverrideType.useScheduleOf => AcademicDayType.makeupDay,
      null when date.weekday >= DateTime.saturday => AcademicDayType.weekend,
      null => AcademicDayType.normal,
    };
  }
}
