import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';

void main() {
  test('exports and restores the local dataset transactionally', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final timetable = RemoteTimetable(
      semester: const RemoteSemester(
        remoteTermKey: '2026-2027-1',
        academicYear: '2026-2027',
        term: 1,
        label: '2026-2027 第一学期',
      ),
      totalWeeks: 20,
      courses: [
        ImportedCourse(
          sourceCourseKey: 'course-1',
          name: '软件测试',
          code: 'CS301',
          teachingClass: '软件工程2401',
          credits: 2,
          assessment: '考查',
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'rule-1',
              weekday: 1,
              startSection: 3,
              endSection: 4,
              teacher: '教师 A',
              campus: '长安校区',
              room: '3406',
              weekMask: WeekMask.all(16),
            ),
          ],
        ),
      ],
    );

    await repository.commitImportedTimetable(timetable);
    await repository.setPreferredSemesterId(timetable.semester.id);
    final course =
        (await repository.loadSemester(timetable.semester.id)).courses.single;
    await repository.deleteCourse(course.id);
    final backup = await repository.createBackup(
      appearance: const {'themeId': 'stone-blue'},
    );
    expect(backup.importSnapshots, hasLength(1));
    expect(backup.deletedSourceItems, hasLength(1));
    expect(backup.appearance['themeId'], 'stone-blue');

    await repository.clearAllData();
    expect(await repository.loadSemesters(), isEmpty);

    await repository.restoreBackup(backup);
    final restored = await repository.loadSemester(timetable.semester.id);
    expect(restored.courses.single.deleted, isTrue);
    expect(await repository.getPreferredSemesterId(), timetable.semester.id);
    expect(await repository.loadLatestImport(timetable.semester.id), isNotNull);
    expect(
      await database.select(database.deletedSourceItems).get(),
      hasLength(1),
    );
  });
}
