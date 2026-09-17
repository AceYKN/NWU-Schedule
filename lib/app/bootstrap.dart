import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_mask.dart';
import '../domain/calendar/calendar_definition.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/course/course.dart';
import '../domain/course/meeting_rule.dart';
import '../domain/schedule/schedule_engine.dart';

final scheduleEngineProvider = Provider<ScheduleEngine>((ref) {
  return ScheduleEngine(
    calendarEngine: CalendarEngine(demoCalendar),
    courses: demoCourses,
    meetingRules: demoMeetingRules,
    exceptions: const [],
  );
});

final demoCalendar = CalendarDefinition(
  id: 'nwu-2026-2027-1',
  school: 'NWU',
  academicYear: '2026-2027',
  term: 1,
  semesterStartDate: DateTime(2026, 8, 31),
  week1StartDate: DateTime(2026, 8, 31),
  semesterEndDate: DateTime(2027, 1, 15),
  totalWeeks: 20,
  revision: 1,
  dateOverrides: const [],
);

final demoCourses = <Course>[
  Course(
    id: 'demo-network-lab',
    semesterId: 'nwu-2026-2027-1',
    sourceType: CourseSourceType.manual,
    name: '计算机网络实验',
    code: 'CS214',
    teachingClass: '计算机科学与技术 2301',
    note: '静态原型示例课程',
    colorOverride: 0xff557a95,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
  Course(
    id: 'demo-software-testing',
    semesterId: 'nwu-2026-2027-1',
    sourceType: CourseSourceType.manual,
    name: '软件测试',
    code: 'SE301',
    teachingClass: '计算机科学与技术 2301',
    colorOverride: 0xff7d6a95,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
  Course(
    id: 'demo-artificial-intelligence',
    semesterId: 'nwu-2026-2027-1',
    sourceType: CourseSourceType.manual,
    name: '人工智能',
    code: 'CS305',
    teachingClass: '计算机科学与技术 2301',
    colorOverride: 0xff9b7653,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
  Course(
    id: 'demo-data-structure-lab',
    semesterId: 'nwu-2026-2027-1',
    sourceType: CourseSourceType.manual,
    name: '数据结构实验',
    code: 'CS203L',
    teachingClass: '计算机科学与技术 2301',
    colorOverride: 0xff63816c,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
];

final demoMeetingRules = <MeetingRule>[
  MeetingRule(
    id: 'demo-network-lab-rule',
    courseId: 'demo-network-lab',
    weekday: DateTime.monday,
    startSection: 1,
    endSection: 4,
    teacher: '徐丹',
    campus: '长安校区',
    room: '计算机技术实验室 321',
    weekMask: WeekMask.all(16),
  ),
  MeetingRule(
    id: 'demo-software-testing-rule',
    courseId: 'demo-software-testing',
    weekday: DateTime.wednesday,
    startSection: 3,
    endSection: 4,
    teacher: '苏峙之',
    campus: '长安校区',
    room: '3406',
    weekMask: WeekMask.all(16),
  ),
  MeetingRule(
    id: 'demo-artificial-intelligence-rule',
    courseId: 'demo-artificial-intelligence',
    weekday: DateTime.thursday,
    startSection: 5,
    endSection: 6,
    teacher: '张老师',
    campus: '长安校区',
    room: '7301',
    weekMask: WeekMask.parse('双周', maxWeek: 16),
  ),
  MeetingRule(
    id: 'demo-data-structure-lab-rule',
    courseId: 'demo-data-structure-lab',
    weekday: DateTime.friday,
    startSection: 7,
    endSection: 8,
    teacher: '李老师',
    campus: '长安校区',
    room: '实验室 321',
    weekMask: WeekMask.all(16),
  ),
];
