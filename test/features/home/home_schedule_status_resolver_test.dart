import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/time/campus_clock.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/features/home/application/home_schedule_status_resolver.dart';

void main() {
  const resolver = HomeScheduleStatusResolver();

  test('uses start-inclusive and end-exclusive current-course boundaries', () {
    final engine = _engine(rules: [_rule('software', DateTime.monday, 3, 4)]);

    final atStart = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 7, 10, 10),
    );
    final atEnd = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 7, 12),
    );

    expect(atStart, isA<HomeInClassState>());
    expect((atStart as HomeInClassState).current.courseName, '软件测试');
    expect(atEnd, isA<HomeTodayFinishedState>());
  });

  test('selects the next class while between two classes', () {
    final engine = _engine(
      courses: [_course('software', '软件测试'), _course('ml', '机器学习')],
      rules: [
        _rule('software', DateTime.monday, 3, 4),
        _rule('ml', DateTime.monday, 5, 6),
      ],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 7, 12, 30),
    );

    expect(state, isA<HomeBeforeNextClassState>());
    expect((state as HomeBeforeNextClassState).course.courseName, '机器学习');
    expect(state.untilStart, const Duration(hours: 1, minutes: 30));
  });

  test('finished day points to the next effective class', () {
    final engine = _engine(
      courses: [_course('software', '软件测试'), _course('data', '数据结构')],
      rules: [
        _rule('software', DateTime.monday, 3, 4),
        _rule('data', DateTime.tuesday, 1, 2),
      ],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 7, 18),
    );

    expect(state, isA<HomeTodayFinishedState>());
    expect(state.next?.daysFromToday, 1);
    expect(state.next?.course.courseName, '数据结构');
  });

  test('continues across several empty days instead of stopping tomorrow', () {
    final engine = _engine(rules: [_rule('software', DateTime.monday, 1, 2)]);

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 11, 12),
    );

    expect(state, isA<HomeNoClassTodayState>());
    expect(state.next?.daysFromToday, 3);
    expect(state.next?.course.date, DateTime(2026, 9, 14));
  });

  test('classifies an ordinary weekend without treating it as a course fact',
      () {
    final engine = _engine(rules: [_rule('software', DateTime.monday, 1, 2)]);

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 12, 12),
    );

    expect(state, isA<HomeNoClassTodayState>());
    expect(state.todayType, AcademicDayType.weekend);
    expect(state.next?.daysFromToday, 2);
  });

  test('weekend makeup course takes priority over the weekend label', () {
    final calendar = _calendar(
      overrides: [
        CalendarDateOverride(
          date: DateTime(2026, 9, 12),
          type: CalendarOverrideType.useScheduleOf,
          sourceDate: DateTime(2026, 9, 7),
          label: '补课',
        ),
      ],
    );
    final engine = _engine(
      calendar: calendar,
      rules: [_rule('software', DateTime.monday, 1, 2)],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 12, 8, 20),
    );

    expect(state, isA<HomeInClassState>());
    expect(state.todayType, AcademicDayType.makeupDay);
  });

  test('holiday without a class remains distinct from an ordinary empty day',
      () {
    final engine = _engine(
      calendar: _calendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 9, 9),
            type: CalendarOverrideType.holiday,
            label: '校庆假期',
          ),
        ],
      ),
      rules: [_rule('software', DateTime.monday, 1, 2)],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 9, 9),
    );

    expect(state, isA<HomeNoClassTodayState>());
    expect(state.todayType, AcademicDayType.holiday);
  });

  test('an effective ADD on a holiday still becomes the next class', () {
    final engine = _engine(
      calendar: _calendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 9, 9),
            type: CalendarOverrideType.holiday,
            label: '校庆假期',
          ),
        ],
      ),
      rules: const [],
      exceptions: [
        CourseException(
          id: 'holiday-add',
          semesterId: _semesterId,
          type: CourseExceptionType.add,
          targetDate: DateTime(2026, 9, 9),
          targetStartSection: 5,
          targetEndSection: 6,
          addedCourseName: '临时实验课',
        ),
      ],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 9, 13),
    );

    expect(state, isA<HomeBeforeNextClassState>());
    expect((state as HomeBeforeNextClassState).course.courseName, '临时实验课');
    expect(state.todayType, AcademicDayType.holiday);
  });

  test('tomorrow makeup course carries its calendar context', () {
    final calendar = _calendar(
      overrides: [
        CalendarDateOverride(
          date: DateTime(2026, 9, 12),
          type: CalendarOverrideType.useScheduleOf,
          sourceDate: DateTime(2026, 9, 7),
          label: '补课',
        ),
      ],
    );
    final engine = _engine(
      calendar: calendar,
      rules: [_rule('software', DateTime.monday, 1, 2)],
    );

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 11, 18),
    );

    expect(state.next?.daysFromToday, 1);
    expect(state.next?.dayType, AcademicDayType.makeupDay);
  });

  test('distinguishes dates outside the teaching term', () {
    final engine = _engine(rules: [_rule('software', DateTime.monday, 1, 2)]);

    final state = resolver.resolve(
      engine: engine,
      now: _instant(2026, 9, 1, 9),
    );

    expect(state, isA<HomeOutsideTeachingTermState>());
  });

  test('CANCEL and MOVE are reflected through effective meetings', () {
    final cancelled = _engine(
      rules: [_rule('software', DateTime.monday, 3, 4)],
      exceptions: [
        CourseException(
          id: 'cancel',
          semesterId: _semesterId,
          courseId: 'software',
          sourceMeetingId: 'software-rule',
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.cancel,
        ),
      ],
    );
    final moved = _engine(
      rules: [_rule('software', DateTime.monday, 3, 4)],
      exceptions: [
        CourseException(
          id: 'move',
          semesterId: _semesterId,
          courseId: 'software',
          sourceMeetingId: 'software-rule',
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.move,
          targetDate: DateTime(2026, 9, 8),
          targetStartSection: 5,
          targetEndSection: 6,
        ),
      ],
    );

    final cancelledState = resolver.resolve(
      engine: cancelled,
      now: _instant(2026, 9, 7, 9),
    );
    final movedState = resolver.resolve(
      engine: moved,
      now: _instant(2026, 9, 7, 9),
    );

    expect(cancelledState.todayCourses, isEmpty);
    expect(movedState.todayCourses, isEmpty);
    expect(movedState.next?.course.date, DateTime(2026, 9, 8));
    expect(movedState.next?.course.exceptionType, CourseExceptionType.move);
  });
}

const _semesterId = 'home-test-semester';

DateTime _instant(int year, int month, int day, int hour, [int minute = 0]) {
  return CampusClock.campusWallTimeToUtc(
    DateTime(year, month, day, hour, minute),
  );
}

CalendarDefinition _calendar({
  List<CalendarDateOverride> overrides = const [],
}) {
  return CalendarDefinition(
    id: 'home-test-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 1),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2026, 10, 31),
    totalWeeks: 8,
    revision: 1,
    dateOverrides: overrides,
  );
}

Course _course(String id, String name) {
  return Course(
    id: id,
    semesterId: _semesterId,
    sourceType: CourseSourceType.manual,
    name: name,
  );
}

MeetingRule _rule(
  String courseId,
  int weekday,
  int startSection,
  int endSection,
) {
  return MeetingRule(
    id: '$courseId-rule',
    courseId: courseId,
    weekday: weekday,
    startSection: startSection,
    endSection: endSection,
    teacher: '教师甲',
    campus: '长安校区',
    room: '3406',
    weekMask: WeekMask.all(8),
  );
}

ScheduleEngine _engine({
  CalendarDefinition? calendar,
  List<Course>? courses,
  List<MeetingRule> rules = const [],
  List<CourseException> exceptions = const [],
}) {
  return ScheduleEngine(
    semesterId: _semesterId,
    calendarEngine: CalendarEngine(calendar ?? _calendar()),
    courses: courses ?? [_course('software', '软件测试')],
    meetingRules: rules,
    exceptions: exceptions,
  );
}
