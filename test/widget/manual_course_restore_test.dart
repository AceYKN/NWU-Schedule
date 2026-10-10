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
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';
import 'package:nwu_schedule/domain/schedule/schedule_data_repository.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/features/schedule/presentation/manual_course_page.dart';

void main() {
  testWidgets('cancelling a same-name restore preserves the deleted course',
      (tester) async {
    final fixture = await _RestoreFixture.create();
    await fixture.openEditor(tester);
    await _submitSameName(tester);
    expect(find.text('恢复同名课程？'), findsOneWidget);
    expect(find.textContaining('本次操作会恢复它'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final after = await fixture.load();
    expect(after.courses.single.deleted, isTrue);
    expect(after.meetingRules, hasLength(1));
    expect(
        await fixture.database
            .select(fixture.database.deletedSourceItems)
            .get(),
        hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final editing in [false, true]) {
    testWidgets(
        editing
            ? 'renaming into a deleted import restores it through reimport'
            : 'adding to a deleted import restores schedule and reminders',
        (tester) async {
      final fixture = await _RestoreFixture.create(editing: editing);
      await fixture.openEditor(tester, editing: editing);
      await _submitSameName(tester);
      await tester.tap(find.text(editing ? '恢复并合并' : '恢复并添加安排'));
      await tester.pumpAndSettle();

      expect(find.text('saved route'), findsOneWidget);
      expect(
          find.text(editing ? '同名课程及上课安排已合并' : '课程已恢复并添加上课安排'), findsOneWidget);
      final after = await fixture.load();
      expect(after.courses, hasLength(1));
      expect(after.courses.single.deleted, isFalse);
      expect(after.courses.single.note, '保留的备注');
      expect(after.courses.single.colorOverride, 0xff123456);
      expect(after.meetingRules, hasLength(2));
      expect(
          await fixture.database
              .select(fixture.database.deletedSourceItems)
              .get(),
          isEmpty);
      final engine = fixture.engine(after);
      expect(engine.getCoursesForDate(DateTime(2026, 9, 7)), isNotEmpty);
      expect(
          const NotificationPlanner().build(
              engine: engine,
              now: DateTime.utc(2026, 9, 6, 23),
              leadMinutes: 15),
          isNotEmpty);

      await fixture.repository.commitImportedTimetable(fixture.timetable);
      final reimported = await fixture.load();
      expect(reimported.courses.single.deleted, isFalse);
      expect(reimported.meetingRules, hasLength(2));
      expect(fixture.engine(reimported).getCoursesForDate(DateTime(2026, 9, 7)),
          isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _submitSameName(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, '软件测试');
  await tester.scrollUntilVisible(find.text('保存课程'), 300,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('保存课程'));
  await tester.pumpAndSettle();
}

class _RestoreFixture {
  _RestoreFixture(this.database, this.repository);

  final AppDatabase database;
  final DriftScheduleDataRepository repository;

  static final calendar = CalendarDefinition(
      id: 'restore-test',
      school: 'NWU',
      academicYear: '2026-2027',
      term: 1,
      semesterStartDate: DateTime(2026, 9, 1),
      week1StartDate: DateTime(2026, 9, 7),
      semesterEndDate: DateTime(2027, 1, 31),
      totalWeeks: 20,
      revision: 1,
      dateOverrides: const []);

  final timetable = RemoteTimetable(
      semester: const RemoteSemester(
          remoteTermKey: '2026-2027-1',
          academicYear: '2026-2027',
          term: 1,
          label: '2026-2027 第一学期',
          calendarId: 'restore-test'),
      totalWeeks: 20,
      courses: [
        ImportedCourse(sourceCourseKey: 'remote-key', name: '软件测试', meetings: [
          ImportedMeeting(
              sourceMeetingKey: 'remote-rule',
              weekday: 1,
              startSection: 3,
              endSection: 4,
              teacher: null,
              campus: null,
              room: null,
              weekMask: WeekMask.all(20)),
        ]),
      ]);

  static Future<_RestoreFixture> create({bool editing = false}) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database,
        calendarById: (_) async => calendar);
    final fixture = _RestoreFixture(database, repository);
    await repository.commitImportedTimetable(fixture.timetable);
    final snapshot = await fixture.load();
    final imported = snapshot.courses.single;
    await repository.saveCourse(
        imported.copyWith(note: '保留的备注', colorOverride: 0xff123456),
        snapshot.meetingRules);
    await repository.deleteCourse(imported.id);
    if (editing) {
      await repository.saveCourse(
          Course(
              id: 'edited',
              semesterId: snapshot.semester.id,
              sourceType: CourseSourceType.manual,
              name: '旧课程名'),
          [
            MeetingRule(
                id: 'edited-rule',
                courseId: 'edited',
                weekday: 2,
                startSection: 1,
                endSection: 2,
                weekMask: WeekMask.all(20)),
          ]);
    }
    return fixture;
  }

  Future<ScheduleDataSnapshot> load() =>
      repository.loadSemester(timetable.semester.id);

  ScheduleEngine engine(ScheduleDataSnapshot snapshot) => ScheduleEngine(
      semesterId: snapshot.semester.id,
      calendarEngine: CalendarEngine(calendar),
      courses: snapshot.courses,
      meetingRules: snapshot.meetingRules,
      exceptions: snapshot.exceptions);

  Future<void> openEditor(WidgetTester tester, {bool editing = false}) async {
    final snapshot = await load();
    final ready =
        ScheduleReady(semester: snapshot.semester, engine: engine(snapshot));
    final router = GoRouter(initialLocation: '/edit', routes: [
      GoRoute(
          path: '/edit',
          builder: (_, __) => Scaffold(
              body: ManualCoursePage(courseId: editing ? 'edited' : null))),
      GoRoute(
          path: '/schedule',
          builder: (_, __) => const Scaffold(body: Text('saved route'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      appDatabaseProvider.overrideWithValue(database),
      scheduleDataRepositoryProvider.overrideWithValue(repository),
      scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      courseEditLoadProvider.overrideWith((ref, id) => Stream.value(ready)),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
  }
}
