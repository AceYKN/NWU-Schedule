import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';

void main() {
  test('migrates a schema v1 database to v3 without losing data', () async {
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
            nameKey: const Value('迁移保留课程'),
            createdAt: created,
            updatedAt: created,
          ),
        );
    await database.customStatement('DROP INDEX courses_semester_name_key_uq');
    await database.customStatement(
      'ALTER TABLE semesters DROP COLUMN calendar_revision',
    );
    await database.customStatement('ALTER TABLE courses DROP COLUMN name_key');
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 3);
    final semester = await database.select(database.semesters).getSingle();
    final course = await database.select(database.courses).getSingle();
    expect(semester.calendarRevision, isNull);
    expect(course.id, 'legacy-course');
    expect(course.name, '迁移保留课程');
    await database.close();
  });

  test('schema v3 survives close and reopen with its course data', () async {
    final directory = Directory.systemTemp.createTempSync('nwu-schedule-db-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/schedule.sqlite');
    final created = DateTime(2026, 9, 1);

    var database = AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 3);
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
            nameKey: const Value('软件测试'),
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

  test(
    'migrates v2 duplicate courses and remaps schedules and exceptions',
    () async {
      final directory = Directory.systemTemp.createTempSync('nwu-schedule-db-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/duplicate-courses.sqlite');
      final created = DateTime(2026, 9, 1);
      final oldUpdated = DateTime(2026, 9, 2);
      final newUpdated = DateTime(2026, 9, 3);

      var database = AppDatabase(NativeDatabase(file));
      await database.into(database.semesters).insert(
            SemestersCompanion.insert(
              id: 'semester-merge',
              academicYear: '2026-2027',
              term: 1,
              label: '第一学期',
              createdAt: created,
            ),
          );
      await database.customStatement('DROP INDEX courses_semester_name_key_uq');
      await database.into(database.courses).insert(
            CoursesCompanion.insert(
              id: 'manual-course',
              semesterId: 'semester-merge',
              sourceType: 'manual',
              name: '机器学习',
              nameKey: const Value('old-manual-key'),
              note: const Value('旧备注'),
              colorOverride: const Value(0xff123456),
              createdAt: created,
              updatedAt: oldUpdated,
            ),
          );
      await database.into(database.courses).insert(
            CoursesCompanion.insert(
              id: 'imported-course',
              semesterId: 'semester-merge',
              sourceType: 'imported',
              sourceCourseKey: const Value('remote-course'),
              name: ' 机器学习\u00a0',
              nameKey: const Value('old-import-key'),
              note: const Value('新备注'),
              colorOverride: const Value(0xff654321),
              hidden: const Value(true),
              createdAt: DateTime(2026, 9, 2),
              updatedAt: newUpdated,
            ),
          );
      await database.into(database.meetingRules).insert(
            MeetingRulesCompanion.insert(
              id: 'manual-duplicate-rule',
              courseId: 'manual-course',
              weekday: DateTime.monday,
              startSection: 1,
              endSection: 2,
              teacher: const Value('教师甲'),
              weekMask: 3,
              rawWeekText: '1-2周',
            ),
          );
      await database.into(database.meetingRules).insert(
            MeetingRulesCompanion.insert(
              id: 'imported-duplicate-rule',
              courseId: 'imported-course',
              sourceMeetingKey: const Value('remote-meeting'),
              weekday: DateTime.monday,
              startSection: 1,
              endSection: 2,
              campus: const Value('长安校区'),
              room: const Value('3406'),
              weekMask: 3,
              rawWeekText: '1-2周',
            ),
          );
      await database.into(database.meetingRules).insert(
            MeetingRulesCompanion.insert(
              id: 'second-rule',
              courseId: 'manual-course',
              weekday: DateTime.thursday,
              startSection: 5,
              endSection: 6,
              weekMask: 1,
              rawWeekText: '1周',
            ),
          );
      await database.into(database.courseExceptions).insert(
            CourseExceptionsCompanion.insert(
              id: 'cancel-exception',
              semesterId: 'semester-merge',
              courseId: const Value('manual-course'),
              sourceMeetingId: const Value('manual-duplicate-rule'),
              sourceDate: Value(DateTime(2026, 9, 7)),
              type: 'cancel',
              createdAt: created,
            ),
          );
      await database.into(database.courseExceptions).insert(
            CourseExceptionsCompanion.insert(
              id: 'move-exception',
              semesterId: 'semester-merge',
              courseId: const Value('imported-course'),
              sourceMeetingId: const Value('imported-duplicate-rule'),
              sourceDate: Value(DateTime(2026, 9, 7)),
              type: 'move',
              targetDate: Value(DateTime(2026, 9, 8)),
              targetStartSection: const Value(3),
              targetEndSection: const Value(4),
              createdAt: created,
            ),
          );
      await database
          .customStatement('ALTER TABLE courses DROP COLUMN name_key');
      await database.customStatement('PRAGMA user_version = 2');
      await database.close();

      database = AppDatabase(NativeDatabase(file));
      final courses = await database.select(database.courses).get();
      final rules = await database.select(database.meetingRules).get();
      final exceptions = await database.select(database.courseExceptions).get();
      expect(courses, hasLength(1));
      expect(courses.single.id, 'imported-course');
      expect(courses.single.nameKey, '机器学习');
      expect(courses.single.sourceCourseKey, 'remote-course');
      expect(courses.single.note, '新备注');
      expect(courses.single.colorOverride, 0xff654321);
      expect(courses.single.hidden, isFalse);
      expect(courses.single.deleted, isFalse);
      expect(rules, hasLength(2));
      expect(rules.map((rule) => rule.id).toSet(), {
        'imported-duplicate-rule',
        'second-rule',
      });
      expect(rules.every((rule) => rule.courseId == 'imported-course'), isTrue);
      expect(exceptions, hasLength(2));
      expect(
        exceptions.every((item) => item.courseId == 'imported-course'),
        isTrue,
      );
      expect(exceptions.map((item) => item.sourceMeetingId).toSet(), {
        'imported-duplicate-rule',
      });
      await expectLater(
        database.into(database.courses).insert(
              CoursesCompanion.insert(
                id: 'duplicate-course',
                semesterId: 'semester-merge',
                sourceType: 'manual',
                name: '机器学习',
                nameKey: const Value('机器学习'),
                createdAt: created,
                updatedAt: created,
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await database.close();
    },
  );

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
            nameKey: const Value('第 64 周课程'),
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
              nameKey: const Value('无学期课程'),
              createdAt: created,
              updatedAt: created,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'cascades every semester-owned row when a semester is deleted',
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
              nameKey: const Value('级联课程'),
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

      await (database.delete(
        database.semesters,
      )..where((table) => table.id.equals('semester-cascade')))
          .go();

      expect(await database.select(database.semesters).get(), isEmpty);
      expect(await database.select(database.courses).get(), isEmpty);
      expect(await database.select(database.meetingRules).get(), isEmpty);
      expect(await database.select(database.courseExceptions).get(), isEmpty);
      expect(await database.select(database.importSnapshots).get(), isEmpty);
      expect(await database.select(database.deletedSourceItems).get(), isEmpty);
    },
  );
}
