import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/time/campus_clock.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/calendar/presentation/calendar_page.dart';

void main() {
  testWidgets('shows actual section totals and updates the agenda on selection',
      (tester) async {
    final ready = _ready();
    final now = CampusClock.campusWallTimeToUtc(DateTime(2026, 10, 14, 9));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      ],
      child: MaterialApp(
        home: Scaffold(body: CalendarPage(now: now)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('10月14日  周三'), findsOneWidget);
    expect(find.text('4节'), findsWidgets);
    expect(find.text('0节'), findsNothing);
    expect(find.text('计算机网络'), findsOneWidget);
    expect(find.byTooltip('选择日期'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('数据结构'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('数据结构'), findsOneWidget);
    expect(find.textContaining('共4节'), findsNothing);
    expect(find.textContaining('第3–4节'), findsOneWidget);

    await tester.ensureVisible(find.text('15').first);
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    expect(find.text('10月15日  周四'), findsOneWidget);
    expect(find.text('当天没有课程'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('2026年10月15日.*0节课')),
      findsOneWidget,
    );
    expect(find.text('计算机网络'), findsNothing);

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('10月14日  周三'), findsOneWidget);
    expect(find.text('计算机网络'), findsOneWidget);

    await tester.tap(find.byTooltip('选择日期'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(find.text('11月'), findsOneWidget);
    expect(find.text('11月1日  周日'), findsOneWidget);
    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    expect(find.text('10月14日  周三'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the narrow large-text calendar usable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final ready = _ready();
    final now = CampusClock.campusWallTimeToUtc(DateTime(2026, 10, 14, 9));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(body: CalendarPage(now: now)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('4节'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the calendar label on a selected holiday', (tester) async {
    final ready = _ready(overrides: [
      CalendarDateOverride(
        date: DateTime(2026, 10, 15),
        type: CalendarOverrideType.holiday,
        label: '校庆休息',
      ),
    ]);
    final now = CampusClock.campusWallTimeToUtc(DateTime(2026, 10, 14, 9));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      ],
      child: MaterialApp(home: Scaffold(body: CalendarPage(now: now))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    expect(find.text('校庆休息'), findsOneWidget);
    expect(find.text('当天没有课程'), findsOneWidget);
  });
}

ScheduleReady _ready({List<CalendarDateOverride> overrides = const []}) {
  const id = 'calendar-page-test';
  final week1 = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: id,
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: week1,
    week1StartDate: week1,
    semesterEndDate: week1.add(const Duration(days: 20 * 7 - 1)),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: overrides,
  );
  final semester = Semester(
    id: id,
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    calendarId: id,
    createdAt: week1,
  );
  final courses = [
    Course(
      id: 'networks',
      semesterId: id,
      sourceType: CourseSourceType.manual,
      name: '计算机网络',
    ),
    Course(
      id: 'structures',
      semesterId: id,
      sourceType: CourseSourceType.manual,
      name: '数据结构',
    ),
  ];
  final rules = [
    MeetingRule(
      id: 'networks-rule',
      courseId: 'networks',
      weekday: DateTime.wednesday,
      startSection: 3,
      endSection: 4,
      campus: '长安校区',
      room: '3406',
      weekMask: WeekMask.all(20),
    ),
    MeetingRule(
      id: 'structures-rule',
      courseId: 'structures',
      weekday: DateTime.wednesday,
      startSection: 5,
      endSection: 6,
      campus: '长安校区',
      room: '3508',
      weekMask: WeekMask.all(20),
    ),
  ];
  return ScheduleReady(
    semester: semester,
    engine: ScheduleEngine(
      semesterId: id,
      calendarEngine: CalendarEngine(calendar),
      courses: courses,
      meetingRules: rules,
      exceptions: const [],
    ),
  );
}
