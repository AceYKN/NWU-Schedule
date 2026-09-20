import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';

void main() {
  test('migrates a schema v1 database to v2 without losing data', () async {
    final directory = Directory.systemTemp.createTempSync('nwu-schedule-db-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/legacy.sqlite');
    final created = DateTime(2026, 9, 1);

    var database = AppDatabase(NativeDatabase(file));
    await database.into(database.semesters).insert(
          SemestersCompanion.insert(
            id: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '第一学期',
            createdAt: created,
          ),
        );
    await database.into(database.courses).insert(
          CoursesCompanion.insert(
            id: 'legacy-course',
            semesterId: '2026-2027-1',
            sourceType: 'manual',
            name: '迁移保留课程',
            createdAt: created,
            updatedAt: created,
          ),
        );
    await database.close();

    // Start from the current on-disk schema, then remove the v2-only column
    // and lower user_version to create a faithful v1 migration fixture.
    final legacyExecutor = NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        sqlite.execute('ALTER TABLE semesters DROP COLUMN calendar_revision');
        sqlite.execute('PRAGMA user_version = 1');
      },
    );
    await legacyExecutor.close();

    database = AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 2);
    final semester = await database.select(database.semesters).getSingle();
    final course = await database.select(database.courses).getSingle();
    expect(semester.calendarRevision, isNull);
    expect(course.id, 'legacy-course');
    expect(course.name, '迁移保留课程');
    await database.close();
  });

  test('schema v2 survives close and reopen with its course data', () async {
    final directory = Directory.systemTemp.createTempSync('nwu-schedule-db-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/schedule.sqlite');
    final created = DateTime(2026, 9, 1);

    var database = AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 2);
    await database.into(database.semesters).insert(
          SemestersCompanion.insert(
            id: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '第一学期',
            createdAt: created,
          ),
        );
    await database.into(database.courses).insert(
          CoursesCompanion.insert(
            id: 'course-1',
            semesterId: '2026-2027-1',
            sourceType: 'manual',
            name: '软件测试',
            createdAt: created,
            updatedAt: created,
          ),
        );
    await database.into(database.meetingRules).insert(
          MeetingRulesCompanion.insert(
            id: 'rule-1',
            courseId: 'course-1',
            weekday: DateTime.monday,
            startSection: 3,
            endSection: 4,
            weekMask: 5,
            rawWeekText: '1,3周',
          ),
        );
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    final semester = await database.select(database.semesters).getSingle();
    final course = await database.select(database.courses).getSingle();
    expect(semester.id, '2026-2027-1');
    expect(course.name, '软件测试');
    expect(course.semesterId, semester.id);
    final snapshot =
        await DriftScheduleDataRepository(database).loadSemester(semester.id);
    expect(snapshot.courses.single.name, '软件测试');
    expect(snapshot.meetingRules.single.weekMask.weeks, [1, 3]);
    await database.close();
  });

  test('round-trips the 64th teaching-week bit through SQLite', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final created = DateTime(2026, 9, 1);
    await database.into(database.semesters).insert(
          SemestersCompanion.insert(
            id: 'semester-64',
            academicYear: '2026-2027',
            term: 1,
            label: '第 64 周测试',
            createdAt: created,
          ),
        );
    await database.into(database.courses).insert(
          CoursesCompanion.insert(
            id: 'course-64',
            semesterId: 'semester-64',
            sourceType: 'manual',
            name: '第 64 周课程',
            createdAt: created,
            updatedAt: created,
          ),
        );
    final mask = WeekMask.fromWeeks([64]);
    await database.into(database.meetingRules).insert(
          MeetingRulesCompanion.insert(
            id: 'rule-64',
            courseId: 'course-64',
            weekday: DateTime.monday,
            startSection: 1,
            endSection: 2,
            weekMask: mask.value,
            rawWeekText: '64 周',
          ),
        );

    final snapshot =
        await DriftScheduleDataRepository(database).loadSemester('semester-64');
    expect(snapshot.meetingRules.single.weekMask.weeks, [64]);
  });

  test('foreign keys prevent orphan course rows', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final created = DateTime(2026, 9, 1);
    expect(
      () => database.into(database.courses).insert(
            CoursesCompanion.insert(
              id: 'orphan',
              semesterId: 'missing',
              sourceType: 'manual',
              name: '无学期课程',
              createdAt: created,
              updatedAt: created,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('cascades every semester-owned row when a semester is deleted',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final created = DateTime(2026, 9, 1);

    await database.into(database.semesters).insert(
          SemestersCompanion.insert(
            id: 'semester-cascade',
            academicYear: '2026-2027',
            term: 1,
            label: '级联删除测试',
            createdAt: created,
          ),
        );
    await database.into(database.courses).insert(
          CoursesCompanion.insert(
            id: 'course-cascade',
            semesterId: 'semester-cascade',
            sourceType: 'imported',
            name: '级联课程',
            createdAt: created,
            updatedAt: created,
          ),
        );
    await database.into(database.meetingRules).insert(
          MeetingRulesCompanion.insert(
            id: 'rule-cascade',
            courseId: 'course-cascade',
            weekday: DateTime.monday,
            startSection: 1,
            endSection: 2,
            weekMask: 1,
            rawWeekText: '1周',
          ),
        );
    await database.into(database.courseExceptions).insert(
          CourseExceptionsCompanion.insert(
            id: 'exception-cascade',
            semesterId: 'semester-cascade',
            type: 'cancel',
            createdAt: created,
          ),
        );
    await database.into(database.importSnapshots).insert(
          ImportSnapshotsCompanion.insert(
            id: 'snapshot-cascade',
            semesterId: 'semester-cascade',
            importedAt: created,
            adapterVersion: 'test',
            schemaVersion: 1,
            normalizedJson: '{}',
            hash: 'hash',
          ),
        );
    await database.into(database.deletedSourceItems).insert(
          DeletedSourceItemsCompanion.insert(
            id: 'tombstone-cascade',
            semesterId: 'semester-cascade',
            sourceCourseKey: 'remote-course',
            deletedAt: created,
          ),
        );

    await (database.delete(database.semesters)
          ..where((table) => table.id.equals('semester-cascade')))
        .go();

    expect(await database.select(database.semesters).get(), isEmpty);
    expect(await database.select(database.courses).get(), isEmpty);
    expect(await database.select(database.meetingRules).get(), isEmpty);
    expect(await database.select(database.courseExceptions).get(), isEmpty);
    expect(await database.select(database.importSnapshots).get(), isEmpty);
    expect(await database.select(database.deletedSourceItems).get(), isEmpty);
  });
}
