import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/time/campus_clock.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart' show AppDatabase;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/schedule/presentation/schedule_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/course_block.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';

void main() {
  testWidgets('changes the clicked occurrence directly from the week grid',
      (tester) async {
    final repository = await _pumpSchedule(tester);
    await tester.tap(find.byType(CourseEventCard).first);
    await tester.pumpAndSettle();

    // The action is visible immediately, before the semester arrangements.
    await tester.tap(find.text('临时变更'));
    await tester.pumpAndSettle();
    expect(find.text('临时变更 · 软件测试'), findsOneWidget);
    expect(find.text('原安排：2026-9-21 · 第 3-4 节'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<CourseExceptionType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止本次课程').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存临时变更'));
    await tester.tap(find.text('保存临时变更'));
    await tester.pumpAndSettle();

    final snapshot = await repository.loadSemester('semester');
    final exception = snapshot.exceptions.single;
    expect(exception.type, CourseExceptionType.cancel);
    expect(exception.courseId, 'course');
    expect(exception.sourceMeetingId, 'rule');
    expect(exception.sourceDate, DateTime(2026, 9, 21));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('临时变更已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('cancels and confirms undo directly from the changed course',
      (tester) async {
    final repository = await _pumpSchedule(tester, changed: true);
    await tester.tap(find.byType(CourseEventCard).first);
    await tester.pumpAndSettle();
    expect(find.text('临时变更'), findsNothing);
    await tester.tap(find.text('撤销临时变更'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
        (await repository.loadSemester('semester')).exceptions, hasLength(1));
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('撤销临时变更'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect((await repository.loadSemester('semester')).exceptions, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('临时变更已撤销'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<DriftScheduleDataRepository> _pumpSchedule(
  WidgetTester tester, {
  bool changed = false,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final calendar = CalendarDefinition(
    id: 'calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 7),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2027, 1, 24),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: const [],
  );
  final repository = DriftScheduleDataRepository(
    database,
    calendarById: (id) async => id == calendar.id ? calendar : null,
  );
  await repository.saveSemester(Semester(
    id: 'semester',
    academicYear: calendar.academicYear,
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    calendarId: calendar.id,
    calendarRevision: calendar.revision,
    createdAt: DateTime(2026, 9, 7),
  ));
  await repository.saveCourse(
    Course(
      id: 'course',
      semesterId: 'semester',
      sourceType: CourseSourceType.manual,
      name: '软件测试',
    ),
    [
      MeetingRule(
        id: 'rule',
        courseId: 'course',
        weekday: DateTime.monday,
        startSection: 3,
        endSection: 4,
        weekMask: WeekMask.all(20),
      ),
    ],
  );
  if (changed) {
    await repository.saveException(CourseException(
      id: 'move',
      semesterId: 'semester',
      courseId: 'course',
      sourceMeetingId: 'rule',
      sourceDate: DateTime(2026, 9, 21),
      type: CourseExceptionType.move,
      targetDate: DateTime(2026, 9, 22),
      targetStartSection: 3,
      targetEndSection: 4,
    ));
  }
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      bundledCalendarRepositoryProvider
          .overrideWithValue(_CalendarRepository(calendar)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SchedulePage(
          now: CampusClock.campusWallTimeToUtc(DateTime(2026, 9, 21, 8)),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return repository;
}

class _CalendarRepository extends BundledCalendarRepository {
  _CalendarRepository(this.calendar);

  final CalendarDefinition calendar;

  @override
  Future<CalendarDefinition?> findById(String id) async =>
      id == calendar.id ? calendar : null;
}
