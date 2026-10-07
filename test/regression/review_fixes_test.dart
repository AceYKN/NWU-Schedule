import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/features/settings/presentation/settings_page.dart';
import 'package:drift/native.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/backup/schedule_backup.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart' as d;
import 'package:nwu_schedule/domain/course/course_exception.dart' as d;
import 'package:nwu_schedule/domain/course/meeting_rule.dart' as d;
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart' as d;
import 'package:nwu_schedule/domain/widget/widget_snapshot.dart';
import 'package:nwu_schedule/features/home/application/home_schedule_status_resolver.dart';
import 'package:nwu_schedule/features/settings/presentation/course_management_page.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';
import 'package:nwu_schedule/features/import/presentation/import_exception_impacts.dart';
import 'package:nwu_schedule/features/import/presentation/timetable_import_page.dart';
import 'package:nwu_schedule/infrastructure/notifications/notification_service.dart';
import 'package:nwu_schedule/infrastructure/widget/widget_service.dart';
import 'package:nwu_schedule/domain/errors/app_error.dart';

final calendar = CalendarDefinition.fromJson({
  'id': 'audit',
  'school': 'NWU',
  'academicYear': '2026-2027',
  'term': 1,
  'semesterStartDate': '2026-09-07',
  'week1StartDate': '2026-09-07',
  'semesterEndDate': '2026-10-04',
  'totalWeeks': 4,
  'revision': 1,
  'holidayPeriods': [],
  'makeupDays': [],
});
final course = d.Course(
    id: 'c',
    semesterId: 's',
    sourceType: d.CourseSourceType.manual,
    name: 'Synthetic course');
d.MeetingRule rule({WeekMask? weeks}) => d.MeetingRule(
    id: 'r',
    courseId: 'c',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    weekMask: weeks ?? WeekMask.all(4));
ScheduleEngine engine(
        {List<d.CourseException> exceptions = const [], WeekMask? weeks}) =>
    ScheduleEngine(
        semesterId: 's',
        calendarEngine: CalendarEngine(calendar),
        courses: [course],
        meetingRules: [rule(weeks: weeks)],
        exceptions: exceptions);
Future<DriftScheduleDataRepository> repository() async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final repo = DriftScheduleDataRepository(database,
      calendarById: (_) async => calendar);
  await repo.saveSemester(d.Semester(
      id: 's',
      academicYear: '2026-2027',
      term: d.SemesterTerm.first,
      label: 'Synthetic term',
      calendarId: 'audit',
      createdAt: DateTime(2026, 9, 1)));
  await repo.saveCourse(course, [rule()]);
  return repo;
}

class AuditSyncFailure extends PlatformSyncFailures {
  @override
  Set<String> build() => {'notifications'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'import impact preview lists dates and cancellation leaves the repository untouched',
      (tester) async {
    final repo = await repository();
    await repo.commitImportedTimetable(remoteTimetable());
    final local = await repo.loadSemester(remoteTimetable().semester.id);
    await repo.saveException(d.CourseException(
        id: 'impact',
        semesterId: local.semester.id,
        courseId: local.courses.single.id,
        sourceMeetingId: local.meetingRules.last.id,
        sourceDate: DateTime(2026, 9, 8),
        type: d.CourseExceptionType.move,
        targetDate: DateTime(2026, 9, 9),
        targetStartSection: 3,
        targetEndSection: 4));
    final incoming = remoteTimetable(two: false);
    final preview = await repo.previewImportedTimetable(incoming);
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TimetableImportPreviewCard(
                    timetable: incoming,
                    diff: preview,
                    saving: false,
                    hasConflictItems: false,
                    onConfirm: () async {
                      if (await confirmImportExceptionImpacts(
                          context, preview.exceptionImpacts)) {
                        await repo.commitImportedTimetable(incoming,
                            expectedPreviewRevision: preview.previewRevision,
                            removeExceptionIds: {'impact'});
                        accepted = true;
                      }
                    },
                    onRetry: () {},
                    onCancel: () {},
                    onResolveConflicts: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('影响 1 条临时变更'), findsOneWidget);
    expect(
        find.textContaining(
            'Synthetic imported course · 调课 · 原 2026-09-08 → 目标 2026-09-09'),
        findsOneWidget);
    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消').last);
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(
        (await repo.loadSemester(local.semester.id)).exceptions, hasLength(1));
    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认上述影响并导入'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect((await repo.loadSemester(local.semester.id)).exceptions, isEmpty);
  });

  test(
      'missing calendar preserves both platform stores instead of sending clear commands',
      () async {
    final repo = await repository();
    await repo.setSetting('notifications.enabled', 'true');
    final state =
        ScheduleCalendarMissing((await repo.loadSemester('s')).semester);
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = [
      MethodChannel('nwu_schedule/notifications'),
      MethodChannel('nwu_schedule/widget')
    ];
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
    }
    addTearDown(() {
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    await expectLater(
        rebuildNotificationsForCurrentSchedule(
            repository: repo,
            service: const NotificationService(),
            state: state),
        throwsA(isA<CalendarMissingError>()));
    await expectLater(
        rebuildWidgetForCurrentSchedule(
            service: const WidgetService(), state: state),
        throwsA(isA<CalendarMissingError>()));
    expect(calls, isEmpty);
  });

  testWidgets('standalone ADD can be edited directly with a new date and name',
      (tester) async {
    final repo = await repository();
    await repo.saveException(d.CourseException(
        id: 'standalone',
        semesterId: 's',
        type: d.CourseExceptionType.add,
        addedCourseName: 'Extra laboratory',
        targetDate: DateTime(2026, 9, 9),
        targetStartSection: 5,
        targetEndSection: 6,
        colorOverride: 0xff52766c));
    final snapshot = await repo.loadSemester('s');
    await tester.pumpWidget(ProviderScope(overrides: [
      scheduleDataRepositoryProvider.overrideWithValue(repo),
      bundledCalendarRepositoryProvider
          .overrideWithValue(TestCalendarRepository()),
      scheduleLoadProvider.overrideWith((ref) => Stream.value(ScheduleReady(
          semester: snapshot.semester,
          engine: engine(exceptions: snapshot.exceptions)))),
    ], child: const MaterialApp(home: Scaffold(body: CourseManagementPage()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑临时变更'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Extra laboratory');
    await tester.enterText(name, 'New laboratory');
    await tester.tap(find.text('上课日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存临时加课'), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('保存临时加课'));
    await tester.pumpAndSettle();
    final updated = (await repo.loadSemester('s')).exceptions.single;
    expect(updated.id, 'standalone');
    expect(updated.addedCourseName, 'New laboratory');
    expect(updated.targetDate, DateTime(2026, 9, 15));
    expect(updated.targetStartSection, 5);
    expect(updated.targetEndSection, 6);
    expect(updated.colorOverride, 0xff52766c);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets(
      'retry reloads successfully and rejects repeated clicks while loading',
      (tester) async {
    final repo = await repository();
    await repo.setSetting('notifications.enabled', 'true');
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const notifications = MethodChannel('nwu_schedule/notifications');
    const widgets = MethodChannel('nwu_schedule/widget');
    for (final channel in [notifications, widgets]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'getStatus'
            ? <String, dynamic>{'planStored': true}
            : null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(widgets, null);
    });
    final pending = Completer<ScheduleLoadState>();
    var reads = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      scheduleDataRepositoryProvider.overrideWithValue(repo),
      scheduleLoadProvider.overrideWith((ref) {
        reads++;
        return reads == 1
            ? Stream.error(StateError('temporary failure'))
            : Stream.fromFuture(pending.future);
      }),
      platformSyncFailuresProvider.overrideWith(AuditSyncFailure.new),
    ], child: const MaterialApp(home: Scaffold(body: SettingsPage()))));
    await tester.pumpAndSettle();
    final retry = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '重试').first)
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(reads, 2);
    expect(calls.where((call) => call != 'getStatus'), isEmpty);
    expect(find.text('正在处理…'), findsOneWidget);
    final semester = (await repo.loadSemester('s')).semester;
    pending.complete(ScheduleReady(semester: semester, engine: engine()));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'rebuildNotifications'), hasLength(1));
    expect(calls.where((call) => call == 'updateSnapshot'), hasLength(1));
    expect(calls, isNot(contains('clearNotifications')));
    expect(calls, isNot(contains('clearSnapshot')));
    expect(find.text('平台同步已完成'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final type in [
    d.CourseExceptionType.move,
    d.CourseExceptionType.add,
    d.CourseExceptionType.cancel
  ]) {
    testWidgets(
        'course management directly edits ${type.name} without losing identity or overrides',
        (tester) async {
      final repo = await repository();
      final baseline = d.MeetingRule(
          id: 'r',
          courseId: 'c',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          teacher: 'Baseline teacher',
          room: 'Original room',
          weekMask: WeekMask.all(4));
      await repo.saveCourse(course, [baseline]);
      final exception = d.CourseException(
          id: 'edited',
          semesterId: 's',
          courseId: 'c',
          sourceMeetingId: 'r',
          sourceDate:
              type == d.CourseExceptionType.add ? null : DateTime(2026, 9, 7),
          type: type,
          targetDate: type == d.CourseExceptionType.cancel
              ? null
              : DateTime(2026, 9, 9),
          targetStartSection: type == d.CourseExceptionType.cancel ? null : 3,
          targetEndSection: type == d.CourseExceptionType.cancel ? null : 4,
          teacherOverride: type == d.CourseExceptionType.cancel ? null : '',
          roomOverride:
              type == d.CourseExceptionType.cancel ? null : 'Changed room',
          colorOverride: 0xff52766c,
          note: 'Original note');
      await repo.saveException(exception);
      final snapshot = await repo.loadSemester('s');
      await tester.pumpWidget(ProviderScope(
          overrides: [
            scheduleDataRepositoryProvider.overrideWithValue(repo),
            bundledCalendarRepositoryProvider
                .overrideWithValue(TestCalendarRepository()),
            scheduleLoadProvider.overrideWith((ref) => Stream.value(
                ScheduleReady(
                    semester: snapshot.semester,
                    engine: ScheduleEngine(
                        semesterId: 's',
                        calendarEngine: CalendarEngine(calendar),
                        courses: snapshot.courses,
                        meetingRules: snapshot.meetingRules,
                        exceptions: snapshot.exceptions)))),
          ],
          child:
              const MaterialApp(home: Scaffold(body: CourseManagementPage()))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Synthetic course ·'), findsOneWidget);
      if (type != d.CourseExceptionType.add) {
        expect(find.textContaining('原日期 2026-09-07'), findsOneWidget);
      }
      if (type != d.CourseExceptionType.cancel) {
        expect(find.textContaining('目标日期 2026-09-09'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('编辑临时变更'));
      await tester.pumpAndSettle();
      final note = find.byWidgetPredicate(
          (w) => w is TextFormField && w.controller?.text == 'Original note');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Edited note');
      await tester.ensureVisible(find.text('保存临时变更'));
      await tester.tap(find.text('保存临时变更'));
      await tester.pumpAndSettle();
      final updated = (await repo.loadSemester('s')).exceptions.single;
      expect(updated.id, 'edited');
      expect(updated.note, 'Edited note');
      expect(updated.sourceMeetingId, 'r');
      expect(updated.sourceDate, exception.sourceDate);
      expect(updated.targetDate, exception.targetDate);
      expect(updated.teacherOverride, exception.teacherOverride);
      expect(updated.roomOverride, exception.roomOverride);
      expect(updated.colorOverride, 0xff52766c);
      expect(
          ScheduleBackup.decode((await repo.createBackup()).encode())
              .exceptions,
          hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  test('notification collisions wrap safely and are deterministic', () {
    final extras = [
      for (final id in ['extra-a', 'extra-b'])
        d.CourseException(
          id: id,
          semesterId: 's',
          type: d.CourseExceptionType.add,
          courseId: 'c',
          sourceMeetingId: 'r',
          targetDate: DateTime(2026, 9, 7),
          targetStartSection: 1,
          targetEndSection: 2,
        )
    ];
    for (final hash in [0, -1, 0x7fffffff]) {
      final planner = NotificationPlanner(idHash: (_) => hash);
      final first = planner.build(
          engine: engine(exceptions: extras),
          now: DateTime.utc(2026, 9, 6),
          leadMinutes: 15);
      final second = planner.build(
          engine: engine(exceptions: extras.reversed.toList()),
          now: DateTime.utc(2026, 9, 6),
          leadMinutes: 15);
      expect(first.map((p) => p.id).toSet(), hasLength(first.length));
      expect(first.every((p) => p.id > 0 && p.id <= 0x7fffffff), isTrue);
      expect({for (final p in first) p.payload: p.id},
          {for (final p in second) p.payload: p.id});
    }
  });

  test('stale import preview cannot overwrite local edits', () async {
    final repo = await repository();
    final incoming = remoteTimetable();
    await repo.commitImportedTimetable(incoming);
    final preview = await repo.previewImportedTimetable(incoming);
    final local = await repo.loadSemester(incoming.semester.id);
    await repo.saveCourse(
        local.courses.single.copyWith(note: 'Local edit'), local.meetingRules);
    await expectLater(
        repo.commitImportedTimetable(incoming,
            expectedPreviewRevision: preview.previewRevision),
        throwsA(isA<ImportPreviewExpiredException>()));
    expect((await repo.loadSemester(incoming.semester.id)).courses.single.note,
        'Local edit');
    final fresh = await repo.previewImportedTimetable(incoming);
    await repo.commitImportedTimetable(incoming,
        expectedPreviewRevision: fresh.previewRevision);
    expect((await repo.loadSemester(incoming.semester.id)).courses.single.note,
        'Local edit');
  });

  test('exception change invalidates an import preview', () async {
    final repo = await repository();
    final incoming = remoteTimetable();
    await repo.commitImportedTimetable(incoming);
    final preview = await repo.previewImportedTimetable(incoming);
    final local = await repo.loadSemester(incoming.semester.id);
    await repo.saveException(d.CourseException(
        id: 'new-cancel',
        semesterId: local.semester.id,
        courseId: local.courses.single.id,
        sourceMeetingId: local.meetingRules.first.id,
        sourceDate: DateTime(2026, 9, 7),
        type: d.CourseExceptionType.cancel));
    await expectLater(
        repo.commitImportedTimetable(incoming,
            expectedPreviewRevision: preview.previewRevision),
        throwsA(isA<ImportPreviewExpiredException>()));
    expect((await repo.loadSemester(incoming.semester.id)).exceptions.single.id,
        'new-cancel');
  });

  test('keeping local topology preserves exceptions during reimport', () async {
    final repo = await repository();
    await repo.commitImportedTimetable(remoteTimetable());
    final local = await repo.loadSemester(remoteTimetable().semester.id);
    final second = local.meetingRules.singleWhere((r) => r.weekday == 2);
    // Change local topology as well, creating a real three-way conflict.
    await repo.saveCourse(local.courses.single, [
      local.meetingRules.first,
      d.MeetingRule(
          id: second.id,
          courseId: second.courseId,
          sourceMeetingKey: second.sourceMeetingKey,
          weekday: 3,
          startSection: 3,
          endSection: 4,
          weekMask: second.weekMask)
    ]);
    await repo.saveException(d.CourseException(
        id: 'kept-move',
        semesterId: local.semester.id,
        courseId: local.courses.single.id,
        sourceMeetingId: second.id,
        sourceDate: DateTime(2026, 9, 9),
        type: d.CourseExceptionType.move,
        targetDate: DateTime(2026, 9, 10),
        targetStartSection: 3,
        targetEndSection: 4));
    final incoming = remoteTimetable(two: false);
    final preview = await repo.previewImportedTimetable(incoming);
    expect(preview.hasConflicts, isTrue);
    expect(preview.exceptionImpacts, hasLength(1));
    final resolution = ImportConflictResolution(choices: {
      'ic': {'meetings': MergeDecision.local}
    });
    expect(preview.resolve(resolution).exceptionImpacts, isEmpty);
    await repo.commitImportedTimetable(incoming,
        resolution: resolution,
        expectedPreviewRevision: preview.previewRevision);
    expect((await repo.loadSemester(local.semester.id)).exceptions.single.id,
        'kept-move');
    expect(
        ScheduleBackup.decode((await repo.createBackup()).encode()).exceptions,
        hasLength(1));
  });

  test('whole-course removal retains exception records and previews suspension',
      () async {
    final repo = await repository();
    final incoming = remoteTimetable();
    await repo.commitImportedTimetable(incoming);
    final local = await repo.loadSemester(incoming.semester.id);
    await repo.saveException(d.CourseException(
        id: 'suspended',
        semesterId: local.semester.id,
        courseId: local.courses.single.id,
        sourceMeetingId: local.meetingRules.first.id,
        sourceDate: DateTime(2026, 9, 7),
        type: d.CourseExceptionType.cancel));
    final empty =
        RemoteTimetable(semester: incoming.semester, totalWeeks: 4, courses: [
      ImportedCourse(
          sourceCourseKey: 'replacement',
          name: 'Unrelated course',
          meetings: incoming.courses.single.meetings),
    ]);
    final preview = await repo.previewImportedTimetable(empty);
    expect(preview.exceptionImpacts.single.removed, isFalse);
    await repo.commitImportedTimetable(empty,
        expectedPreviewRevision: preview.previewRevision);
    final deleted = await repo.loadSemester(local.semester.id);
    expect(
        deleted.courses
            .singleWhere((c) => c.id == local.courses.single.id)
            .deleted,
        isTrue);
    expect(deleted.exceptions.single.id, 'suspended');
    expect(
        ScheduleBackup.decode((await repo.createBackup()).encode()).exceptions,
        hasLength(1));
  });

  test(
      'exception references must belong to their course and semester, including ADD',
      () async {
    final repo = await repository();
    final other = d.Course(
        id: 'other',
        semesterId: 's',
        sourceType: d.CourseSourceType.manual,
        name: 'Other');
    final otherRule = d.MeetingRule(
        id: 'other-rule',
        courseId: 'other',
        weekday: 2,
        startSection: 1,
        endSection: 2,
        weekMask: WeekMask.all(4));
    await repo.saveCourse(other, [otherRule]);
    for (final source in ['missing', 'other-rule']) {
      await expectLater(
          repo.saveException(d.CourseException(
              id: 'bad-$source',
              semesterId: 's',
              courseId: 'c',
              sourceMeetingId: source,
              type: d.CourseExceptionType.add,
              targetDate: DateTime(2026, 9, 8),
              targetStartSection: 1,
              targetEndSection: 2)),
          throwsArgumentError);
    }
    await repo.saveSemester(d.Semester(
        id: 'another',
        academicYear: '2026-2027',
        term: d.SemesterTerm.first,
        label: 'Another term',
        createdAt: DateTime(2026, 9, 1)));
    await expectLater(
        repo.saveException(d.CourseException(
            id: 'cross-term',
            semesterId: 'another',
            courseId: 'c',
            type: d.CourseExceptionType.add,
            targetDate: DateTime(2026, 9, 8),
            targetStartSection: 1,
            targetEndSection: 2)),
        throwsArgumentError);
    await expectLater(
        repo.saveException(d.CourseException(
            id: 'missing-course',
            semesterId: 's',
            courseId: 'unknown',
            type: d.CourseExceptionType.add,
            targetDate: DateTime(2026, 9, 8),
            targetStartSection: 1,
            targetEndSection: 2)),
        throwsArgumentError);
    expect((await repo.createBackup()).exceptions, isEmpty);
  });

  test('merge and exception removal are scoped and transactional', () async {
    final repo = await repository();
    final target = d.Course(
        id: 'target',
        semesterId: 's',
        sourceType: d.CourseSourceType.manual,
        name: 'Target');
    await repo.saveCourse(target, [
      d.MeetingRule(
          id: 'target-rule',
          courseId: 'target',
          weekday: 2,
          startSection: 1,
          endSection: 2,
          weekMask: WeekMask.all(4))
    ]);
    await repo.saveException(d.CourseException(
        id: 'linked',
        semesterId: 's',
        courseId: 'c',
        sourceMeetingId: 'r',
        sourceDate: DateTime(2026, 9, 7),
        type: d.CourseExceptionType.cancel));
    await expectLater(
        repo.saveCourse(target, [], removeExceptionIds: ['linked']),
        throwsArgumentError);
    await expectLater(
        repo.mergeCourseInto(
            editedCourse: course.copyWith(name: 'Target'),
            targetCourseId: 'target',
            editedRules: []),
        throwsStateError);
    final retained = await repo.loadSemester('s');
    expect(retained.courses, hasLength(2));
    expect(retained.meetingRules, hasLength(2));
    expect(retained.exceptions.single.id, 'linked');
    await repo.mergeCourseInto(
        editedCourse: course.copyWith(name: 'Target'),
        targetCourseId: 'target',
        editedRules: [],
        removeExceptionIds: ['linked']);
    expect(
        ScheduleBackup.decode((await repo.createBackup()).encode()).exceptions,
        isEmpty);
  });
  testWidgets('retry preserves native stores when reloading the schedule fails',
      (tester) async {
    final repo = await repository();
    await repo.setSetting('notifications.enabled', 'true');
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const notifications = MethodChannel('nwu_schedule/notifications');
    const widgets = MethodChannel('nwu_schedule/widget');
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call.method);
      return call.method == 'getStatus'
          ? <String, dynamic>{
              'systemAllowed': true,
              'channelAllowed': true,
              'planStored': true
            }
          : null;
    });
    messenger.setMockMethodCallHandler(widgets, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(widgets, null);
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      scheduleDataRepositoryProvider.overrideWithValue(repo),
      scheduleLoadProvider.overrideWith((ref) =>
          Stream<ScheduleLoadState>.error(
              StateError('synthetic temporary read failure'))),
      platformSyncFailuresProvider.overrideWith(AuditSyncFailure.new),
    ], child: const MaterialApp(home: Scaffold(body: SettingsPage()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试').first);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call != 'getStatus'), isEmpty);
    expect(find.text('平台同步已完成'), findsNothing);
    expect(find.textContaining('已保留现有平台数据'), findsOneWidget);
    expect((await repo.loadSemester('s')).courses, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  test('base and linked ADD have distinct reminder identities', () {
    final e = engine(exceptions: [
      d.CourseException(
          id: 'extra',
          semesterId: 's',
          type: d.CourseExceptionType.add,
          courseId: 'c',
          sourceMeetingId: 'r',
          targetDate: DateTime(2026, 9, 7),
          targetStartSection: 1,
          targetEndSection: 2,
          roomOverride: 'Different room')
    ]);
    final plan = const NotificationPlanner()
        .build(engine: e, now: DateTime.utc(2026, 9, 6), leadMinutes: 15);
    expect(e.getCoursesForDate(DateTime(2026, 9, 7)), hasLength(2));
    expect(plan[0].id, isNot(plan[1].id));
    expect(plan[0].payload, isNot(plan[1].payload));
    expect(plan.map((p) => p.id).toSet().length, plan.length);
  });
  test('Home, engine and widget agree on a class beyond seven days', () {
    final e = engine(weeks: WeekMask.fromWeeks([3]));
    final now = DateTime.utc(2026, 9, 7);
    expect(
        const HomeScheduleStatusResolver()
            .resolve(engine: e, now: now)
            .next
            ?.course
            .date,
        DateTime(2026, 9, 21));
    expect(e.getNextCourse(now)?.date, DateTime(2026, 9, 21));
    expect(const WidgetSnapshotBuilder().build(engine: e, now: now).next?.date,
        DateTime(2026, 9, 21));
  });
  test('saveException rejects an orphan and keeps the backup restorable',
      () async {
    final repo = await repository();
    await expectLater(
        repo.saveException(d.CourseException(
            id: 'bad-ref',
            semesterId: 's',
            courseId: 'c',
            sourceMeetingId: 'missing',
            sourceDate: DateTime(2026, 9, 7),
            type: d.CourseExceptionType.cancel)),
        throwsArgumentError);
    final backup = await repo.createBackup();
    expect(backup.exceptions, isEmpty);
    expect(ScheduleBackup.decode(backup.encode()).courses, hasLength(1));
  });
  test(
      'saveCourse requires explicit removal of exceptions referencing deleted rules',
      () async {
    final repo = await repository();
    await repo.saveException(d.CourseException(
        id: 'cancel',
        semesterId: 's',
        courseId: 'c',
        sourceMeetingId: 'r',
        sourceDate: DateTime(2026, 9, 7),
        type: d.CourseExceptionType.cancel));
    await expectLater(repo.saveCourse(course, []), throwsStateError);
    expect((await repo.loadSemester('s')).meetingRules, hasLength(1));
    await repo.saveCourse(course, [], removeExceptionIds: ['cancel']);
    final backup = await repo.createBackup();
    expect(backup.meetingRules, isEmpty);
    expect(backup.exceptions, isEmpty);
    expect(ScheduleBackup.decode(backup.encode()).courses, hasLength(1));
  });
  test(
      'remote meeting removal previews local MOVE and requires exact acknowledgement',
      () async {
    final repo = await repository();
    ImportedMeeting meeting(String id, int weekday) => ImportedMeeting(
        sourceMeetingKey: id,
        weekday: weekday,
        startSection: 3,
        endSection: 4,
        teacher: null,
        campus: null,
        room: null,
        weekMask: WeekMask.all(4));
    RemoteTimetable remote(bool two) => RemoteTimetable(
            semester: const RemoteSemester(
                remoteTermKey: 'synthetic',
                academicYear: '2026-2027',
                term: 1,
                label: 'Synthetic import',
                calendarId: 'audit'),
            totalWeeks: 4,
            courses: [
              ImportedCourse(
                  sourceCourseKey: 'ic',
                  name: 'Synthetic imported course',
                  meetings: [meeting('m1', 1), if (two) meeting('m2', 2)])
            ]);
    await repo.commitImportedTimetable(remote(true));
    final data = await repo.loadSemester('nwu-2026-2027-1');
    final removed = data.meetingRules.singleWhere((r) => r.weekday == 2);
    await repo.saveException(d.CourseException(
        id: 'local-move',
        semesterId: data.semester.id,
        courseId: data.courses.single.id,
        sourceMeetingId: removed.id,
        sourceDate: DateTime(2026, 9, 8),
        targetDate: DateTime(2026, 9, 9),
        targetStartSection: 3,
        targetEndSection: 4,
        type: d.CourseExceptionType.move));
    final preview = await repo.previewImportedTimetable(remote(false));
    expect(preview.hasConflicts, isFalse);
    expect(preview.exceptionImpacts, hasLength(1));
    expect(preview.exceptionImpacts.single.courseName,
        'Synthetic imported course');
    expect(preview.exceptionImpacts.single.exception.sourceDate,
        DateTime(2026, 9, 8));
    expect(preview.exceptionImpacts.single.exception.targetDate,
        DateTime(2026, 9, 9));
    await expectLater(repo.commitImportedTimetable(remote(false)),
        throwsA(isA<ImportExceptionRemovalConfirmationRequired>()));
    expect(
        (await repo.loadSemester(data.semester.id)).exceptions, hasLength(1));
    await expectLater(
        repo.commitImportedTimetable(remote(false),
            expectedPreviewRevision: preview.previewRevision,
            removeExceptionIds: {'wrong-id'}),
        throwsA(isA<ImportExceptionRemovalConfirmationRequired>()));
    await repo.commitImportedTimetable(remote(false),
        expectedPreviewRevision: preview.previewRevision,
        removeExceptionIds: {'local-move'});
    expect((await repo.loadSemester(data.semester.id)).exceptions, isEmpty);
  });
}

RemoteTimetable remoteTimetable({bool two = true}) => RemoteTimetable(
      semester: const RemoteSemester(
          remoteTermKey: 'synthetic',
          academicYear: '2026-2027',
          term: 1,
          label: 'Synthetic import',
          calendarId: 'audit'),
      totalWeeks: 4,
      courses: [
        ImportedCourse(
            sourceCourseKey: 'ic',
            name: 'Synthetic imported course',
            meetings: [
              for (final weekday in [1, if (two) 2])
                ImportedMeeting(
                    sourceMeetingKey: 'm$weekday',
                    weekday: weekday,
                    startSection: 3,
                    endSection: 4,
                    teacher: null,
                    campus: null,
                    room: null,
                    weekMask: WeekMask.all(4)),
            ])
      ],
    );

class TestCalendarRepository extends BundledCalendarRepository {
  @override
  Future<CalendarDefinition?> findById(String id) async => calendar;
}
