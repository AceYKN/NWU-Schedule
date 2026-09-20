import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/widget/widget_snapshot.dart';

void main() {
  final definition = CalendarDefinition.fromJson({
    'id': 'widget-calendar',
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

  test('builds next, today, and tomorrow from the schedule engine', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: const [],
    );
    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6, 0),
    );

    expect(snapshot.next?.courseName, '软件测试');
    expect(snapshot.today, isEmpty);
    expect(snapshot.tomorrow.single.location, '长安校区 · 3406');
    expect(snapshot.instances, hasLength(4));
    final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(json['next'], isA<Map>());
    expect((json['today'] as List), isEmpty);
    expect((json['tomorrow'] as List), hasLength(1));
    expect((json['instances'] as List), hasLength(4));
  });

  test('publishes an empty snapshot when there is no class', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: const [],
      meetingRules: const [],
      exceptions: const [],
    );
    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
    );

    expect(snapshot.next, isNull);
    expect(snapshot.today, isEmpty);
    expect(snapshot.tomorrow, isEmpty);
    expect(snapshot.instances, isEmpty);
  });

  test('does not duplicate engine decisions in the native payload', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: const [],
    );
    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 7, 1),
    );

    final first = snapshot.today.single;
    expect(first.courseId, course.id);
    expect(first.startSection, 3);
    expect(first.endSection, 4);
    expect(first.teacher, '教师 A');
  });

  test('keeps the current class in today and advances next past it', () {
    final engine = ScheduleEngine(
      semesterId: 'semester-1',
      calendarEngine: CalendarEngine(definition),
      courses: [course],
      meetingRules: [rule],
      exceptions: const [],
    );
    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 7, 2, 20),
    );

    expect(snapshot.today, hasLength(1));
    expect(snapshot.today.single.date, DateTime(2026, 9, 7));
    expect(snapshot.next?.date, DateTime(2026, 9, 14));
  });

  test('projects MOVE into the rolling widget instances', () {
    final engine = _makeEngine(
      exceptions: [
        CourseException(
          id: 'move-1',
          semesterId: 'semester-1',
          courseId: course.id,
          sourceMeetingId: rule.id,
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.move,
          targetDate: DateTime(2026, 9, 8),
          targetStartSection: 7,
          targetEndSection: 8,
          roomOverride: '3508',
        ),
      ],
    );

    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
    );

    expect(
      snapshot.instances.where((item) => item.date == DateTime(2026, 9, 7)),
      isEmpty,
    );
    final moved = snapshot.instances.singleWhere(
      (item) => item.date == DateTime(2026, 9, 8),
    );
    expect(moved.startSection, 7);
    expect(moved.endSection, 8);
    expect(moved.location, '长安校区 · 3508');
    expect(moved.isException, isTrue);
    expect(
      snapshot.instances.where((item) => item.date == DateTime(2026, 9, 14)),
      hasLength(1),
    );
  });

  test('projects CANCEL without removing later recurring instances', () {
    final engine = _makeEngine(
      exceptions: [
        CourseException(
          id: 'cancel-1',
          semesterId: 'semester-1',
          courseId: course.id,
          sourceMeetingId: rule.id,
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.cancel,
        ),
      ],
    );

    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
    );

    expect(
      snapshot.instances.where((item) => item.date == DateTime(2026, 9, 7)),
      isEmpty,
    );
    expect(
      snapshot.instances.where((item) => item.date == DateTime(2026, 9, 14)),
      hasLength(1),
    );
  });

  test('projects ADD alongside the recurring schedule', () {
    final engine = _makeEngine(
      exceptions: [
        CourseException(
          id: 'add-1',
          semesterId: 'semester-1',
          type: CourseExceptionType.add,
          targetDate: DateTime(2026, 9, 9),
          targetStartSection: 5,
          targetEndSection: 6,
          addedCourseName: '临时实验课',
          roomOverride: '实验室 321',
        ),
      ],
    );

    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
    );

    final added = snapshot.instances.singleWhere(
      (item) => item.date == DateTime(2026, 9, 9),
    );
    expect(added.courseName, '临时实验课');
    expect(added.startSection, 5);
    expect(added.location, '实验室 321');
    expect(added.isException, isTrue);
    expect(added.exceptionId, 'add-1');
    expect(
      (added.toJson()['exceptionId']),
      'add-1',
    );
    expect(
      snapshot.instances.where((item) => item.date == DateTime(2026, 9, 7)),
      hasLength(1),
    );
  });

  test('recomputes today and tomorrow after a campus-date rollover', () {
    final engine = _makeEngine();
    final builder = const WidgetSnapshotBuilder();

    final beforeMidnight = builder.build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6, 15, 59),
    );
    final afterMidnight = builder.build(
      engine: engine,
      now: DateTime.utc(2026, 9, 7, 0, 1),
    );

    expect(beforeMidnight.today, isEmpty);
    expect(beforeMidnight.tomorrow.single.date, DateTime(2026, 9, 7));
    expect(afterMidnight.today.single.date, DateTime(2026, 9, 7));
    expect(afterMidnight.tomorrow, isEmpty);
    expect(afterMidnight.next?.date, DateTime(2026, 9, 7));
    expect(afterMidnight.instances, hasLength(beforeMidnight.instances.length));
  });
}

ScheduleEngine _makeEngine({
  Iterable<CourseException> exceptions = const [],
}) {
  return ScheduleEngine(
    semesterId: 'semester-1',
    calendarEngine: CalendarEngine(
      CalendarDefinition.fromJson({
        'id': 'widget-calendar',
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
      }),
    ),
    courses: [
      Course(
        id: 'course-1',
        semesterId: 'semester-1',
        sourceType: CourseSourceType.manual,
        name: '软件测试',
      ),
    ],
    meetingRules: [
      MeetingRule(
        id: 'rule-1',
        courseId: 'course-1',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        teacher: '教师 A',
        campus: '长安校区',
        room: '3406',
        weekMask: WeekMask.all(4),
      ),
    ],
    exceptions: exceptions,
  );
}
