import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/schedule/schedule_now_state.dart';

CalendarDefinition makeCalendar({
  List<CalendarDateOverride> overrides = const [],
}) {
  return CalendarDefinition(
    id: 'nwu-test-2026-1',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 1),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2027, 1, 31),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: overrides,
  );
}

Course makeCourse() {
  return Course(
    id: 'course-software-testing',
    semesterId: 'nwu-test-2026-1',
    sourceType: CourseSourceType.imported,
    name: '软件测试',
    code: 'SE301',
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

MeetingRule makeRule({
  int weekday = DateTime.monday,
  int startSection = 3,
  int endSection = 4,
  WeekMask? weekMask,
}) {
  return MeetingRule(
    id: 'rule-software-testing',
    courseId: 'course-software-testing',
    weekday: weekday,
    startSection: startSection,
    endSection: endSection,
    teacher: '苏老师',
    campus: '长安校区',
    room: '3406',
    weekMask: weekMask ?? WeekMask.all(20),
  );
}

ScheduleEngine makeEngine({
  CalendarDefinition? calendar,
  List<MeetingRule>? rules,
  List<CourseException> exceptions = const [],
}) {
  final course = makeCourse();
  return ScheduleEngine(
    calendarEngine: CalendarEngine(calendar ?? makeCalendar()),
    courses: [course],
    meetingRules: rules ?? [makeRule()],
    exceptions: exceptions,
  );
}

void main() {
  test('matches a course by template weekday and teaching week', () async {
    final engine = makeEngine();

    final courses = await engine.getCoursesForDate(DateTime(2026, 9, 7));

    expect(courses, hasLength(1));
    expect(courses.single.courseName, '软件测试');
    expect(courses.single.startSection, 3);
    expect(courses.single.startTime, DateTime(2026, 9, 7, 10, 10));
    expect(courses.single.endTime, DateTime(2026, 9, 7, 12));
  });

  test('uses the source date for a makeup day', () async {
    final engine = makeEngine(
      calendar: makeCalendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 9, 12),
            type: CalendarOverrideType.useScheduleOf,
            sourceDate: DateTime(2026, 9, 7),
            label: '调课',
          ),
        ],
      ),
    );

    final courses = await engine.getCoursesForDate(DateTime(2026, 9, 12));

    expect(courses, hasLength(1));
    expect(courses.single.date, DateTime(2026, 9, 12));
    expect(courses.single.templateDate, DateTime(2026, 9, 7));
    expect(courses.single.isException, isFalse);
  });

  test('makeup day keeps the source teaching week', () async {
    final engine = makeEngine(
      calendar: makeCalendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 10, 17),
            type: CalendarOverrideType.useScheduleOf,
            sourceDate: DateTime(2026, 10, 7),
            label: '调课',
          ),
        ],
      ),
      rules: [
        makeRule(
          weekday: DateTime.wednesday,
          weekMask: WeekMask.fromWeeks([5]),
        ),
      ],
    );

    final courses = await engine.getCoursesForDate(DateTime(2026, 10, 17));

    expect(courses, hasLength(1));
    expect(courses.single.templateDate, DateTime(2026, 10, 7));
  });

  test('honors odd and even week masks', () async {
    final oddEngine = makeEngine(
      rules: [makeRule(weekMask: WeekMask.parse('单周', maxWeek: 20))],
    );
    final evenEngine = makeEngine(
      rules: [makeRule(weekMask: WeekMask.parse('双周', maxWeek: 20))],
    );

    expect(
      await oddEngine.getCoursesForDate(DateTime(2026, 9, 7)),
      hasLength(1),
    );
    expect(
      await evenEngine.getCoursesForDate(DateTime(2026, 9, 7)),
      isEmpty,
    );
    expect(
      await evenEngine.getCoursesForDate(DateTime(2026, 9, 14)),
      hasLength(1),
    );
  });

  test('MOVE removes source, adds target, and keeps later recurrence', () async {
    final engine = makeEngine(
      exceptions: [
        CourseException(
          id: 'move-1',
          courseId: 'course-software-testing',
          sourceMeetingId: 'rule-software-testing',
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.move,
          targetDate: DateTime(2026, 9, 8),
          targetStartSection: 7,
          targetEndSection: 8,
          roomOverride: '3508',
        ),
      ],
    );

    expect(
      await engine.getCoursesForDate(DateTime(2026, 9, 7)),
      isEmpty,
    );
    final target = await engine.getCoursesForDate(DateTime(2026, 9, 8));
    expect(target, hasLength(1));
    expect(target.single.startSection, 7);
    expect(target.single.room, '3508');
    expect(
      await engine.getCoursesForDate(DateTime(2026, 9, 14)),
      hasLength(1),
    );
  });

  test('CANCEL removes only one occurrence', () async {
    final engine = makeEngine(
      exceptions: [
        CourseException(
          id: 'cancel-1',
          courseId: 'course-software-testing',
          sourceMeetingId: 'rule-software-testing',
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.cancel,
        ),
      ],
    );

    expect(
      await engine.getCoursesForDate(DateTime(2026, 9, 7)),
      isEmpty,
    );
    expect(
      await engine.getCoursesForDate(DateTime(2026, 9, 14)),
      hasLength(1),
    );
  });

  test('ADD remains visible on a holiday', () async {
    final holiday = CalendarDateOverride(
      date: DateTime(2026, 9, 9),
      type: CalendarOverrideType.holiday,
      label: '校庆假期',
    );
    final engine = makeEngine(
      calendar: makeCalendar(overrides: [holiday]),
      exceptions: [
        CourseException(
          id: 'add-1',
          type: CourseExceptionType.add,
          targetDate: DateTime(2026, 9, 9),
          targetStartSection: 5,
          targetEndSection: 6,
          addedCourseName: '临时实验课',
          roomOverride: '实验室 321',
        ),
      ],
    );

    final courses = await engine.getCoursesForDate(DateTime(2026, 9, 9));
    expect(courses, hasLength(1));
    expect(courses.single.courseName, '临时实验课');
    expect(courses.single.isException, isTrue);
  });

  test('finds the next course across a weekend', () async {
    final engine = makeEngine(
      rules: [makeRule(weekday: DateTime.monday)],
    );

    final next = await engine.getNextCourse(DateTime.utc(2026, 9, 11, 12));

    expect(next, isNotNull);
    expect(next!.date, DateTime(2026, 9, 14));
  });

  test('returns current, next, finished, and no-class states', () async {
    final engine = makeEngine();

    final current = await engine.getStateAt(DateTime.utc(2026, 9, 7, 2, 30));
    expect(current, isA<ScheduleCurrent>());

    final next = await engine.getStateAt(DateTime.utc(2026, 9, 7, 0));
    expect(next, isA<ScheduleNext>());

    final finished = await engine.getStateAt(DateTime.utc(2026, 9, 7, 8));
    expect(finished, isA<ScheduleFinishedToday>());

    final noClass = await engine.getStateAt(DateTime.utc(2026, 9, 8, 0));
    expect(noClass, isA<ScheduleNoClassToday>());
    expect((noClass as ScheduleNoClassToday).next, isNotNull);
  });
}
