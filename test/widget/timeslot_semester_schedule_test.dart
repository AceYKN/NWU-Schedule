import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/timeslot_semester_schedule.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';

void main() {
  test('merges same arrangements and separates a different course', () {
    final engine = _engine(
      courses: [_course('a', '软件测试'), _course('b', 'Web数据挖掘')],
      rules: [
        _rule('a-rule', 'a', WeekMask.fromWeeks([1, 2, 3, 4, 9, 10])),
        _rule('b-rule', 'b', WeekMask.fromWeeks([5, 6, 7, 8])),
      ],
    );

    final result = TimeslotSemesterScheduleBuilder.build(
      engine: engine,
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
    );

    expect(result.groups, hasLength(3));
    expect(result.groups[0].weeks, [1, 2, 3, 4]);
    expect(result.groups[0].weekLabel, '1-4周');
    expect(result.groups[1].weeks, [5, 6, 7, 8]);
    expect(result.groups[1].meetings.single.courseName, 'Web数据挖掘');
    expect(result.groups[2].weeks, [9, 10]);
  });

  test('keeps an odd-week arrangement as one correctly formatted group', () {
    final engine = _engine(
      courses: [_course('a', '软件测试')],
      rules: [
        _rule('a-rule', 'a', WeekMask.fromWeeks([1, 3, 5, 7])),
      ],
    );

    final result = TimeslotSemesterScheduleBuilder.build(
      engine: engine,
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
    );

    expect(result.groups, hasLength(1));
    expect(result.groups.single.weeks, [1, 3, 5, 7]);
    expect(result.groups.single.weekLabel, '1-7周单周');
  });

  test('shows a move gap at the source timeslot', () {
    final sourceDate = DateTime(2026, 9, 21);
    final exception = CourseException(
      id: 'move-1',
      semesterId: 'semester',
      courseId: 'a',
      sourceMeetingId: 'a-rule',
      sourceDate: sourceDate,
      type: CourseExceptionType.move,
      targetDate: DateTime(2026, 9, 23),
      targetStartSection: 5,
      targetEndSection: 6,
    );
    final engine = _engine(
      courses: [_course('a', '软件测试')],
      rules: [_rule('a-rule', 'a', WeekMask.all(20))],
      exceptions: [exception],
    );

    final result = TimeslotSemesterScheduleBuilder.build(
      engine: engine,
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
    );

    expect(result.groups.map((group) => group.weeks), [
      [1, 2],
      [3],
      [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    ]);
    expect(result.groups[1].statusLabel, '调课');
  });
}

CalendarDefinition _calendar() {
  final week1 = DateTime(2026, 9, 7);
  return CalendarDefinition(
    id: 'calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: week1,
    week1StartDate: week1,
    semesterEndDate: week1.add(const Duration(days: 20 * 7 - 1)),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: const [],
  );
}

ScheduleEngine _engine({
  required List<Course> courses,
  required List<MeetingRule> rules,
  List<CourseException> exceptions = const [],
}) {
  return ScheduleEngine(
    semesterId: 'semester',
    calendarEngine: CalendarEngine(_calendar()),
    courses: courses,
    meetingRules: rules,
    exceptions: exceptions,
  );
}

Course _course(String id, String name) {
  return Course(
    id: id,
    semesterId: 'semester',
    sourceType: CourseSourceType.manual,
    name: name,
  );
}

MeetingRule _rule(String id, String courseId, WeekMask mask) {
  return MeetingRule(
    id: id,
    courseId: courseId,
    weekday: DateTime.monday,
    startSection: 3,
    endSection: 4,
    teacher: '教师',
    campus: '长安校区',
    room: '3406',
    weekMask: mask,
  );
}
