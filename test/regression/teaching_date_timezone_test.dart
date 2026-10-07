import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/date_utils.dart';
import 'package:nwu_schedule/data/database/app_database.dart' as db;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/backup/schedule_backup.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';

void main() {
  test('new keys, legacy UTC+8 migration and backup retain teaching dates',
      () async {
    final phase = Platform.environment['NWU_DATE_PHASE'];
    final expectedOffset =
        int.tryParse(Platform.environment['NWU_DATE_EXPECTED_OFFSET'] ?? '');
    if (expectedOffset != null) {
      expect(DateTime(2026, 9, 7).timeZoneOffset.inHours, expectedOffset);
    }
    final directory =
        phase == null ? Directory.systemTemp.createTempSync('nwu-date-') : null;
    if (directory != null) {
      addTearDown(() => directory.deleteSync(recursive: true));
    }
    final path = Platform.environment['NWU_DATE_DATABASE'] ??
        '${directory!.path}/dates.sqlite';
    for (final legacy in [false, true]) {
      var database = db.AppDatabase(
          NativeDatabase(File('$path${legacy ? '.legacy' : ''}')));
      var repository = DriftScheduleDataRepository(database);
      if (phase == null || phase == 'write') {
        await repository.saveSemester(Semester(
            id: 'timezone',
            academicYear: '2026-2027',
            term: SemesterTerm.first,
            label: '合成日期测试',
            createdAt: DateTime.utc(2026, 9, 1)));
        await repository.saveCourse(
            Course(
                id: 'course',
                semesterId: 'timezone',
                sourceType: CourseSourceType.manual,
                name: '合成课程'),
            [
              MeetingRule(
                  id: 'rule',
                  courseId: 'course',
                  weekday: 1,
                  startSection: 1,
                  endSection: 1,
                  weekMask: const WeekMask(3))
            ]);
        await repository.saveException(CourseException(
            id: 'move',
            semesterId: 'timezone',
            courseId: 'course',
            sourceMeetingId: 'rule',
            sourceDate: DateTime(2026, 9, 7),
            type: CourseExceptionType.move,
            targetDate: DateTime(2026, 9, 8),
            targetStartSection: 1,
            targetEndSection: 1));
        await repository.saveException(CourseException(
            id: 'cancel',
            semesterId: 'timezone',
            courseId: 'course',
            sourceMeetingId: 'rule',
            sourceDate: DateTime(2026, 9, 14),
            type: CourseExceptionType.cancel));
        await repository.saveException(CourseException(
            id: 'add',
            semesterId: 'timezone',
            type: CourseExceptionType.add,
            targetDate: DateTime(2026, 9, 9),
            targetStartSection: 1,
            targetEndSection: 1,
            addedCourseName: '单次合成课程'));
        if (legacy) {
          // Historical dates were written at midnight in the default campus zone.
          await database.customStatement(
              "UPDATE course_exceptions SET source_date = CASE id WHEN 'move' THEN ? WHEN 'cancel' THEN ? END, "
              "target_date = CASE id WHEN 'move' THEN ? WHEN 'add' THEN ? END",
              [
                DateTime.utc(2026, 9, 6, 16).millisecondsSinceEpoch ~/ 1000,
                DateTime.utc(2026, 9, 13, 16).millisecondsSinceEpoch ~/ 1000,
                DateTime.utc(2026, 9, 7, 16).millisecondsSinceEpoch ~/ 1000,
                DateTime.utc(2026, 9, 8, 16).millisecondsSinceEpoch ~/ 1000
              ]);
          for (final column in [
            'source_date_key',
            'target_date_key',
            'color_override'
          ]) {
            await database.customStatement(
                'ALTER TABLE course_exceptions DROP COLUMN $column');
          }
          await database.customStatement('PRAGMA user_version = 3');
        }
        await database.close();
        if (legacy && phase == 'write') continue;
        database = db.AppDatabase(
            NativeDatabase(File('$path${legacy ? '.legacy' : ''}')));
        repository = DriftScheduleDataRepository(database);
      }
      try {
        final snapshot = await repository.loadSemester('timezone');
        final exceptions = {
          for (final exception in snapshot.exceptions) exception.id: exception
        };
        expect(dateKey(exceptions['move']!.sourceDate!), '2026-09-07');
        expect(dateKey(exceptions['move']!.targetDate!), '2026-09-08');
        expect(dateKey(exceptions['cancel']!.sourceDate!), '2026-09-14');
        expect(dateKey(exceptions['add']!.targetDate!), '2026-09-09');
        final backup =
            ScheduleBackup.decode((await repository.createBackup()).encode());
        await repository.restoreBackup(backup);
        expect(
            (await repository.loadSemester('timezone'))
                .exceptions
                .map((e) => dateKey(e.targetDate ?? e.sourceDate!)),
            containsAll(['2026-09-08', '2026-09-09', '2026-09-14']));
      } finally {
        await database.close();
      }
    }
  });
}
