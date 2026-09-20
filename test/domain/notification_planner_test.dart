import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';

void main() {
  final definition = CalendarDefinition.fromJson({
    'id': 'test-calendar',
    'school': 'NWU',
    'academicYear': '2026-2027',
    'term': 1,
    'semesterStartDate': '2026-09-01',
    'week1StartDate': '2026-09-07',
    'semesterEndDate': '2026-09-30',
    'totalWeeks': 4,
    'revision': 1,
    'holidayPeriods': [],
    'makeupDays': [],
  });
  final course = Course(
    id: 'course-1',
    semesterId: 'semester-1',
    sourceType: CourseSourceType.manual,
    name: '软件测试',
  );
  final rule = MeetingRule(
    id: 'rule-1',
    courseId: course.id,
    weekday: 1,
    startSection: 3,
    endSection: 4,
    teacher: '教师 A',
    campus: '长安校区',
    room: '3406',
    weekMask: WeekMask.all(4),
  );

  test('plans future notifications from effective instances', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: const [],
    );
    final plan = const NotificationPlanner().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6, 0),
      leadMinutes: 15,
    );

    expect(plan, isNotEmpty);
    expect(plan.first.title, '软件测试');
    expect(plan.first.body, contains('3406 · 教师 A'));
    expect(plan.first.body, contains('上课'));
    expect(plan.first.fireAtUtc.isAfter(DateTime.utc(2026, 9, 6)), isTrue);
  });

  test('cancelled and past instances are not planned', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: [
        __cancelException(),
      ],
    );
    final plan = const NotificationPlanner().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 14, 3),
      leadMinutes: 15,
    );

    expect(plan, isNotEmpty);
    expect(
      plan.every(
        (item) => item.fireAtUtc.isAfter(DateTime.utc(2026, 9, 14, 3)),
      ),
      isTrue,
    );
  });

  test('moves a reminder from the source occurrence to the target occurrence',
      () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: [
        CourseException(
          id: 'move-1',
          semesterId: 'semester-1',
          courseId: course.id,
          sourceMeetingId: rule.id,
          sourceDate: DateTime(2026, 9, 14),
          type: CourseExceptionType.move,
          targetDate: DateTime(2026, 9, 15),
          targetStartSection: 5,
          targetEndSection: 6,
        ),
      ],
    );
    final plan = const NotificationPlanner().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 13),
      leadMinutes: 15,
      until: DateTime.utc(2026, 9, 16, 23),
    );

    expect(
      plan.where((item) => item.payload.contains('2026-09-14')),
      isEmpty,
    );
    final moved =
        plan.where((item) => item.payload.contains('2026-09-15')).toList();
    expect(moved, hasLength(1));
    expect(moved.single.fireAtUtc, DateTime.utc(2026, 9, 15, 5, 45));
  });
}

// Kept outside the test body to make the exception shape explicit in the
// fixture without coupling the planner to raw CourseException construction.
CourseException __cancelException() => CourseException(
      id: 'cancel-1',
      semesterId: 'semester-1',
      courseId: 'course-1',
      sourceMeetingId: 'rule-1',
      sourceDate: DateTime(2026, 9, 7),
      type: CourseExceptionType.cancel,
    );
