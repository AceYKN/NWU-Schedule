import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
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
}
