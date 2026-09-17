import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';

void main() {
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
}
