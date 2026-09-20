import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart' as domain;
import 'package:nwu_schedule/domain/course/course_exception.dart' as domain;
import 'package:nwu_schedule/domain/course/meeting_rule.dart' as domain;
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart' as domain;

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

  test('restores an ADD exception with date-only schedule semantics', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final calendar = CalendarDefinition(
      id: 'nwu-2026-2027-1',
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
    final semester = domain.Semester(
      id: 'nwu-2026-2027-1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '2026-2027 第一学期',
      calendarId: calendar.id,
      calendarRevision: calendar.revision,
      createdAt: DateTime(2026, 9, 1),
    );
    final targetDate = DateTime(2026, 9, 8);
    await repository.saveSemester(semester);
    await repository.saveException(
      domain.CourseException(
        id: 'add-exception-1',
        semesterId: semester.id,
        type: domain.CourseExceptionType.add,
        targetDate: targetDate,
        targetStartSection: 1,
        targetEndSection: 2,
        addedCourseName: '临时加课',
        roomOverride: '3406',
      ),
    );

    final backup = await repository.createBackup();
    await repository.clearAllData();
    await repository.restoreBackup(backup);

    final restored = await repository.loadSemester(semester.id);
    final engine = ScheduleEngine(
      semesterId: semester.id,
      calendarEngine: CalendarEngine(calendar),
      courses: restored.courses,
      meetingRules: restored.meetingRules,
      exceptions: restored.exceptions,
    );

    expect(restored.exceptions.single.targetDate, targetDate);
    expect(
      engine.getCoursesForDate(targetDate).map((item) => item.courseName),
      contains('临时加课'),
    );
    expect(
      engine.getCoursesForDate(
        targetDate.subtract(const Duration(days: 1)),
      ),
      isEmpty,
    );
  });

  test('restores manual course, exception, settings, and appearance data',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 'manual-backup-semester',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '2026-2027 第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    final course = domain.Course(
      id: 'manual-backup-course',
      semesterId: semester.id,
      sourceType: domain.CourseSourceType.manual,
      name: '手工课程',
      note: '本地备注',
      colorOverride: 0xff123456,
    );
    final rule = domain.MeetingRule(
      id: 'manual-backup-rule',
      courseId: course.id,
      weekday: 3,
      startSection: 5,
      endSection: 6,
      teacher: '教师 B',
      campus: '长安校区',
      room: '1310',
      weekMask: WeekMask.all(16),
    );
    final exception = domain.CourseException(
      id: 'manual-backup-exception',
      semesterId: semester.id,
      type: domain.CourseExceptionType.add,
      targetDate: DateTime(2026, 9, 16),
      targetStartSection: 1,
      targetEndSection: 2,
      addedCourseName: '备份临时课',
    );
    await repository.saveSemester(semester);
    await repository.saveCourse(course, [rule]);
    await repository.saveException(exception);
    await repository.setSetting('notifications.enabled', 'true');
    await repository.setSetting('notifications.leadMinutes', '10');

    final backup = await repository.createBackup(
      appearance: const {'themeId': 'cedar-green'},
    );
    await repository.clearAllData();
    await repository.restoreBackup(backup);

    final restored = await repository.loadSemester(semester.id);
    final restoredCourse = restored.courses.single;
    expect(restoredCourse.id, course.id);
    expect(restoredCourse.name, course.name);
    expect(restoredCourse.note, course.note);
    expect(restoredCourse.colorOverride, course.colorOverride);
    expect(restored.meetingRules.single.room, '1310');
    expect(restored.exceptions.single.addedCourseName, '备份临时课');
    expect(await repository.getSetting('notifications.enabled'), 'true');
    expect(await repository.getSetting('notifications.leadMinutes'), '10');
    expect(backup.appearance['themeId'], 'cedar-green');
  });
}
