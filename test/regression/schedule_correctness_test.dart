import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/utils/date_utils.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart' as db;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/backup/schedule_backup.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/domain/widget/widget_snapshot.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';

final calendar = CalendarDefinition(
    id: 'regression',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 7),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2026, 12, 27),
    totalWeeks: 16,
    revision: 1,
    dateOverrides: const []);
Course course({bool hidden = false, bool deleted = false}) => Course(
    id: 'course',
    semesterId: 'regression',
    sourceType: CourseSourceType.manual,
    name: '合成测试课程',
    hidden: hidden,
    deleted: deleted);
MeetingRule rule() => MeetingRule(
    id: 'rule',
    courseId: 'course',
    weekday: 1,
    startSection: 1,
    endSection: 1,
    teacher: '原教师',
    campus: '原校区',
    room: '原教室',
    weekMask: WeekMask.all(16));
ScheduleEngine engine(List<Course> courses, List<MeetingRule> rules,
        List<CourseException> exceptions) =>
    ScheduleEngine(
        semesterId: 'regression',
        calendarEngine: CalendarEngine(calendar),
        courses: courses,
        meetingRules: rules,
        exceptions: exceptions);
Future<DriftScheduleDataRepository> repository(db.AppDatabase database) async {
  final repository = DriftScheduleDataRepository(database,
      calendarById: (_) async => calendar);
  await repository.saveSemester(Semester(
      id: 'regression',
      academicYear: '2026-2027',
      term: SemesterTerm.first,
      label: '合成学期',
      calendarId: calendar.id,
      createdAt: DateTime(2026, 9, 1)));
  return repository;
}

CourseException add(String id, DateTime date, {String? courseId}) =>
    CourseException(
        id: id,
        semesterId: 'regression',
        courseId: courseId,
        sourceMeetingId: courseId == null ? null : 'rule',
        type: CourseExceptionType.add,
        targetDate: date,
        targetStartSection: 1,
        targetEndSection: 1,
        addedCourseName: '临时测试');

void main() {
  test('huge teaching week ranges are rejected before expansion', () {
    expect(() => WeekMask.parse('1-1000000000周'), throwsRangeError);
    expect(() => WeekMask.parse('0-16周'), throwsRangeError);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'inherit, clear and set survive database and backup into every effective consumer',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    await repo.saveCourse(course(), [rule()]);
    for (final value in <String?>[null, '', '新值']) {
      final exception = CourseException(
          id: 'move',
          semesterId: 'regression',
          courseId: 'course',
          sourceMeetingId: 'rule',
          sourceDate: DateTime(2026, 9, 7),
          type: CourseExceptionType.move,
          targetDate: DateTime(2026, 9, 8),
          targetStartSection: 1,
          targetEndSection: 1,
          teacherOverride: value,
          campusOverride: value,
          roomOverride: value);
      await repo.saveException(exception);
      final decoded =
          ScheduleBackup.decode((await repo.createBackup()).encode());
      expect(decoded.exceptions.single.teacherOverride, value);
      expect(decoded.exceptions.single.campusOverride, value);
      expect(decoded.exceptions.single.roomOverride, value);
      await repo.restoreBackup(decoded);
      final snapshot = await repo.loadSemester('regression');
      final effective =
          engine(snapshot.courses, snapshot.meetingRules, snapshot.exceptions);
      final instance = effective.getCoursesForDate(DateTime(2026, 9, 8)).single;
      expect(instance.teacher, value ?? '原教师');
      expect(instance.campus, value ?? '原校区');
      expect(instance.room, value ?? '原教室');
      final widget = const WidgetSnapshotBuilder()
          .build(engine: effective, now: DateTime.utc(2026, 9, 7));
      final moved =
          widget.instances.singleWhere((i) => i.exceptionId == 'move');
      expect(moved.location, instance.location);
      final plan = const NotificationPlanner().build(
          engine: effective, now: DateTime.utc(2026, 9, 7), leadMinutes: 15);
      final reminder = plan.firstWhere((p) => p.title == instance.courseName);
      if (value == '') expect(reminder.body, isNot(contains('原教室')));
    }
  });

  test('date keys take precedence over legacy instants for MOVE and CANCEL',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    await repo.saveCourse(course(), [rule()]);
    await repo.saveException(CourseException(
        id: 'move',
        semesterId: 'regression',
        courseId: 'course',
        sourceMeetingId: 'rule',
        sourceDate: DateTime(2026, 9, 7),
        type: CourseExceptionType.move,
        targetDate: DateTime(2026, 9, 8),
        targetStartSection: 1,
        targetEndSection: 1));
    final row = await database.select(database.courseExceptions).getSingle();
    expect(row.sourceDateKey, '2026-09-07');
    expect(row.targetDateKey, '2026-09-08');
    // Simulate a legacy timestamp resolving to a different day on another device.
    await database.update(database.courseExceptions).write(
        db.CourseExceptionsCompanion(
            sourceDate: Value(DateTime.utc(2026, 9, 5)),
            targetDate: Value(DateTime.utc(2026, 9, 6))));
    final loaded = await repo.loadSemester('regression');
    expect(dateKey(loaded.exceptions.single.sourceDate!), '2026-09-07');
    expect(dateKey(loaded.exceptions.single.targetDate!), '2026-09-08');
    expect(
        engine(loaded.courses, loaded.meetingRules, loaded.exceptions)
            .getCoursesForDate(DateTime(2026, 9, 7)),
        isEmpty);
  });

  test('referenced ADD obeys hidden, deleted and missing course visibility',
      () {
    final referenced =
        add('referenced', DateTime(2026, 9, 8), courseId: 'course');
    for (final courses in [
      [course(hidden: true)],
      [course(deleted: true)],
      <Course>[]
    ]) {
      expect(
          engine(courses, [rule()], [referenced])
              .getCoursesForDate(DateTime(2026, 9, 8)),
          isEmpty);
    }
    expect(
        engine([course()], [rule()], [referenced])
            .getCoursesForDate(DateTime(2026, 9, 8))
            .single
            .course
            .id,
        'course');
    expect(
        engine([
          course(hidden: true)
        ], [
          rule()
        ], [
          add('independent', DateTime(2026, 9, 8))
        ]).getCoursesForDate(DateTime(2026, 9, 8)).single.course.id,
        'independent');
  });

  test(
      'semester boundary rejects invalid writes and restores without partial changes',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    for (final date in [calendar.semesterStartDate, calendar.semesterEndDate]) {
      await repo.saveException(add(dateKey(date), date));
    }
    final valid = await repo.createBackup();
    for (final date in [
      addCalendarDays(calendar.semesterStartDate, -1),
      addCalendarDays(calendar.semesterEndDate, 1)
    ]) {
      await expectLater(
          repo.saveException(add('invalid', date)), throwsArgumentError);
      final badJson = valid.toJson();
      (badJson['exceptions'] as List).add({
        'id': 'bad',
        'semesterId': 'regression',
        'type': 'add',
        'targetDate': dateKey(date),
        'targetStartSection': 1,
        'targetEndSection': 1,
        'addedCourseName': 'invalid'
      });
      await expectLater(repo.restoreBackup(ScheduleBackup.fromJson(badJson)),
          throwsArgumentError);
      expect((await repo.loadSemester('regression')).exceptions, hasLength(2));
      expect(
          engine([], [], [add('legacy-invalid', date)]).getCoursesForDate(date),
          isEmpty);
    }
  });

  test(
      'standalone color survives reload and backup without creating a Course row',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    await repo.saveException(
        add('independent', DateTime(2026, 9, 8)).withColor(0xff52766c));
    await repo.restoreBackup(
        ScheduleBackup.decode((await repo.createBackup()).encode()));
    var snapshot = await repo.loadSemester('regression');
    expect(snapshot.courses, isEmpty);
    expect(
        engine([], [], snapshot.exceptions)
            .getCoursesForDate(DateTime(2026, 9, 8))
            .single
            .course
            .colorOverride,
        0xff52766c);
    await repo.saveException(snapshot.exceptions.single.withColor(null));
    snapshot = await repo.loadSemester('regression');
    expect(snapshot.exceptions.single.colorOverride, isNull);
    expect(snapshot.courses, isEmpty);
  });

  test('full semester plan has all 560 effective instances and stable IDs', () {
    final rules = [
      for (var day = 1; day <= 7; day++)
        for (final section in [1, 3, 5, 7, 9])
          MeetingRule(
              id: 'rule-$day-$section',
              courseId: 'course',
              weekday: day,
              startSection: section,
              endSection: section,
              weekMask: WeekMask.all(16))
    ];
    final effective = engine([course()], rules, []);
    final plan = const NotificationPlanner().build(
        engine: effective, now: DateTime.utc(2026, 9, 6), leadMinutes: 15);
    expect(plan, hasLength(560));
    expect(plan.map((p) => p.id).toSet(), hasLength(560));
    expect(
        const WidgetSnapshotBuilder()
            .build(engine: effective, now: DateTime.utc(2026, 9, 6))
            .instances,
        hasLength(plan.length));
  });

  test(
      'appearance changes do not invalidate schedules while reminder changes do',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    var count = 0;
    final subscription = repo.watchChanges().listen((_) => count++);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final baseline = count;
    await repo.setSetting('appearance.themeId', 'cedar-green');
    await repo.setSetting('schedule.weekView.showTeacher', 'false');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(count, baseline);
    await repo.setSetting('notifications.leadMinutes', '30');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(count, greaterThan(baseline));
  });

  test(
      'historical editing loads its owner without changing the selected semester',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repo = await repository(database);
    await repo.saveCourse(course(), [rule()]);
    await repo.saveSemester(Semester(
        id: 'selected',
        academicYear: '2026-2027',
        term: SemesterTerm.second,
        label: '选中学期',
        createdAt: DateTime(2026, 9, 1)));
    await repo.setPreferredSemesterId('selected');
    final container = ProviderContainer(overrides: [
      scheduleDataRepositoryProvider.overrideWithValue(repo),
      bundledCalendarRepositoryProvider.overrideWithValue(_Calendars())
    ]);
    addTearDown(container.dispose);
    final listener =
        container.listen(courseEditLoadProvider('course'), (_, __) {});
    addTearDown(listener.close);
    final state = await container.read(courseEditLoadProvider('course').future)
        as ScheduleReady;
    expect(state.semester.id, 'regression');
    await repo.saveCourse(state.engine.courses.single.copyWith(note: '编辑历史'),
        state.engine.meetingRules);
    expect(await repo.getPreferredSemesterId(), 'selected');
    expect((await repo.loadSemester('regression')).courses.single.note, '编辑历史');
    expect((await repo.loadSemester('selected')).courses, isEmpty);
  });
}

class _Calendars extends BundledCalendarRepository {
  @override
  Future<CalendarDefinition?> findById(String id) async => calendar;
}
