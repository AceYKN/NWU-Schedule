import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/theme/campus_design.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/calendar/presentation/calendar_page.dart';

void main() {
  for (final (preview, scale) in [(false, 1.0), (true, 1.0), (true, 1.8)]) {
    testWidgets('calendar and details keep user data at $preview / $scale',
        (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final ready = _ready();
      final base = officialThemes.first.light();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
        ],
        child: MaterialApp(
          theme: preview ? CampusDesign.preview().applyTo(base) : base,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CalendarPage(now: DateTime.utc(2026, 10, 19, 1, 41)),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(preview ? '本日' : '今天'), findsOneWidget);
      expect(find.text(preview ? '月曜日' : '一'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('设置'));
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text(preview ? '教員' : '教师'), findsWidgets);
      expect(find.text('教师'), findsWidgets);
      expect(find.text('校区 · 星期一 {1}'), findsWidgets);
      expect(find.text('设置'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

ScheduleReady _ready() {
  final start = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: 'copy-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: start,
    week1StartDate: start,
    semesterEndDate: DateTime(2027, 1, 24),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: const [],
  );
  final semester = Semester(
    id: 'copy-semester',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '学期原文',
    calendarId: calendar.id,
    calendarRevision: 1,
    createdAt: start,
  );
  final course = Course(
    id: 'copy-course',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '设置',
  );
  return ScheduleReady(
    semester: semester,
    engine: ScheduleEngine(
      semesterId: semester.id,
      calendarEngine: CalendarEngine(calendar),
      courses: [course],
      meetingRules: [
        MeetingRule(
          id: 'copy-rule',
          courseId: course.id,
          weekday: DateTime.monday,
          startSection: 3,
          endSection: 4,
          teacher: '教师',
          campus: '校区',
          room: '星期一 {1}',
          weekMask: WeekMask.all(20),
        ),
      ],
      exceptions: const [],
    ),
  );
}
