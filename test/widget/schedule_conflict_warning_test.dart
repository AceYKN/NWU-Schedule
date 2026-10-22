import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart' show AppDatabase;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_data_repository.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/schedule/presentation/manual_course_page.dart';
import 'package:nwu_schedule/features/shared/presentation/course_card.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';

void main() {
  testWidgets('manual course warning preserves the form until user saves',
      (tester) async {
    _usePhoneSize(tester);
    final fixture = await _Fixture.create();
    final snapshot = await fixture.repository.loadSemester('semester');
    final ready = ScheduleReady(
      semester: snapshot.semester,
      engine: fixture.engine(snapshot),
    );
    final router = GoRouter(initialLocation: '/new', routes: [
      GoRoute(
        path: '/new',
        builder: (_, __) => const Scaffold(body: ManualCoursePage()),
      ),
      GoRoute(
        path: '/schedule',
        builder: (_, __) => const Scaffold(body: Text('已进入课表')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleDataRepositoryProvider.overrideWithValue(fixture.repository),
        scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '新课程');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存课程'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();

    expect(find.text('发现撞课'), findsOneWidget);
    expect(find.text('保存中…'), findsNothing);
    expect(find.text('与“软件测试”重叠'), findsOneWidget);
    expect(find.text('本学期共 4 天重叠'), findsOneWidget);
    expect((await fixture.repository.loadSemester('semester')).courses,
        hasLength(1));

    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(find.text('新课程'), findsWidgets);
    expect((await fixture.repository.loadSemester('semester')).courses,
        hasLength(1));

    await tester.scrollUntilVisible(find.text('保存课程'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍要保存'));
    await tester.pumpAndSettle();
    expect(find.text('已进入课表'), findsOneWidget);
    expect((await fixture.repository.loadSemester('semester')).courses,
        hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('temporary add warning returns to editor without writing',
      (tester) async {
    _usePhoneSize(tester);
    final fixture = await _Fixture.create();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleDataRepositoryProvider.overrideWithValue(fixture.repository),
        bundledCalendarRepositoryProvider
            .overrideWithValue(_CalendarRepository(_Fixture.calendar)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return TextButton(
              onPressed: () => showStandaloneAddException(
                pageContext: context,
                ref: ref,
                semesterId: 'semester',
                initialDate: DateTime(2026, 9, 7),
              ),
              child: const Text('临时加课入口'),
            );
          }),
        ),
      ),
    ));
    await tester.tap(find.text('临时加课入口'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '临时课程');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存临时加课'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('保存临时加课'));
    await tester.pumpAndSettle();
    expect(find.text('发现撞课'), findsOneWidget);
    expect((await fixture.repository.loadSemester('semester')).exceptions,
        isEmpty);

    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(find.text('保存临时加课'), findsOneWidget);
    expect(find.text('临时课程'), findsWidgets);

    await tester.tap(find.text('保存临时加课'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍要保存'));
    await tester.pumpAndSettle();
    expect((await fixture.repository.loadSemester('semester')).exceptions,
        hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(411, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Fixture {
  _Fixture(this.database, this.repository);

  final AppDatabase database;
  final DriftScheduleDataRepository repository;

  static final calendar = CalendarDefinition(
    id: 'calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 7),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2026, 10, 4),
    totalWeeks: 4,
    revision: 1,
    dateOverrides: const [],
  );

  static Future<_Fixture> create() async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database,
        calendarById: (id) async => id == calendar.id ? calendar : null);
    await repository.saveSemester(Semester(
      id: 'semester',
      academicYear: calendar.academicYear,
      term: SemesterTerm.first,
      label: '2026-2027 第一学期',
      calendarId: calendar.id,
      calendarRevision: calendar.revision,
      createdAt: calendar.semesterStartDate,
    ));
    await repository.saveCourse(
      Course(
        id: 'existing',
        semesterId: 'semester',
        sourceType: CourseSourceType.manual,
        name: '软件测试',
      ),
      [
        MeetingRule(
          id: 'existing-rule',
          courseId: 'existing',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weekMask: WeekMask.all(4),
        ),
      ],
    );
    return _Fixture(database, repository);
  }

  ScheduleEngine engine(ScheduleDataSnapshot snapshot) => ScheduleEngine(
        semesterId: snapshot.semester.id,
        calendarEngine: CalendarEngine(calendar),
        courses: snapshot.courses,
        meetingRules: snapshot.meetingRules,
        exceptions: snapshot.exceptions,
      );
}

class _CalendarRepository extends BundledCalendarRepository {
  const _CalendarRepository(this.calendar);

  final CalendarDefinition calendar;

  @override
  Future<CalendarDefinition?> findById(String id) async =>
      id == calendar.id ? calendar : null;
}
