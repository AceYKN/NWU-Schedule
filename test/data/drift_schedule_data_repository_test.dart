import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/course/course.dart' as domain;
import 'package:nwu_schedule/domain/course/course_exception.dart' as domain;
import 'package:nwu_schedule/domain/course/meeting_rule.dart' as domain;
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/domain/semester/semester.dart' as domain;

void main() {
  test('writes notify watchers and preserve edited course fields', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final changes = repository.watchChanges().asBroadcastStream();
    final firstChange = changes.first;
    final createdAt = DateTime(2026, 9, 1);
    final semester = domain.Semester(
      id: 'nwu-2026-2027-1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '2026–2027 第一学期',
      calendarId: 'nwu-2026-2027-1',
      createdAt: createdAt,
    );
    await firstChange;
    await repository.saveSemester(semester);
    expect((await repository.loadSemesters()).single.id, semester.id);

    final course = domain.Course(
      id: 'manual-1',
      semesterId: semester.id,
      sourceType: domain.CourseSourceType.manual,
      name: '软件测试',
      note: '自选课',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final rule = domain.MeetingRule(
      id: 'manual-rule-1',
      courseId: course.id,
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
      room: '3508',
      weekMask: WeekMask.fromWeeks([1, 3]),
    );
    final nextChange = changes.first;
    await repository.saveCourse(course, [rule]);
    await nextChange;
    var snapshot = await repository.loadSemester(semester.id);
    expect(snapshot.courses.single.note, '自选课');
    expect(snapshot.meetingRules.single.weekMask.weeks, [1, 3]);

    await repository
        .saveCourse(course.copyWith(note: null), [rule.copyWith(room: null)]);
    snapshot = await repository.loadSemester(semester.id);
    expect(snapshot.courses.single.note, isNull);
    expect(snapshot.meetingRules.single.room, isNull);

    await repository.setCourseHidden(course.id, true);
    expect((await repository.loadSemester(semester.id)).courses.single.hidden,
        isTrue);
    await repository.setPreferredSemesterId(semester.id);
    expect(await repository.getPreferredSemesterId(), semester.id);
    expect(await repository.getPreferredSemesterSelectedAt(), isNotNull);
    await repository.setPreferredSemesterId(null);
    expect(await repository.getPreferredSemesterId(), isNull);
    expect(await repository.getPreferredSemesterSelectedAt(), isNull);
  });

  test('rejects rules for another course without partial write', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 's1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    await repository.saveSemester(semester);
    final course = domain.Course(
      id: 'c1',
      semesterId: semester.id,
      sourceType: domain.CourseSourceType.manual,
      name: '测试课程',
    );
    final wrongRule = domain.MeetingRule(
      id: 'r1',
      courseId: 'other',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weekMask: WeekMask.fromWeeks([1]),
    );
    await expectLater(
        repository.saveCourse(course, [wrongRule]), throwsArgumentError);
    expect((await repository.loadSemester(semester.id)).courses, isEmpty);
  });

  test('manual deletion removes course; imported deletion creates tombstone',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 's1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    await repository.saveSemester(semester);
    await repository.saveCourse(
      domain.Course(
        id: 'manual-1',
        semesterId: semester.id,
        sourceType: domain.CourseSourceType.manual,
        name: '自选课',
      ),
      [],
    );
    await repository.saveCourse(
      domain.Course(
        id: 'imported-1',
        semesterId: semester.id,
        sourceType: domain.CourseSourceType.imported,
        sourceCourseKey: 'remote-key',
        name: '教务课',
      ),
      [],
    );
    await repository.deleteCourse('manual-1');
    await repository.deleteCourse('imported-1');
    final snapshot = await repository.loadSemester(semester.id);
    expect(snapshot.courses, hasLength(1));
    expect(snapshot.courses.single.id, 'imported-1');
    expect(snapshot.courses.single.deleted, isTrue);
    final tombstones = await database.select(database.deletedSourceItems).get();
    expect(tombstones.single.sourceCourseKey, 'remote-key');
    await repository.restoreImportedCourse('imported-1');
    expect((await repository.loadSemester(semester.id)).courses.single.deleted,
        isFalse);
    expect(await database.select(database.deletedSourceItems).get(), isEmpty);
  });

  test('saves and deletes a temporary exception', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 's1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    await repository.saveSemester(semester);
    final exception = domain.CourseException(
      id: 'exception-1',
      semesterId: semester.id,
      type: domain.CourseExceptionType.add,
      targetDate: DateTime(2026, 9, 8),
      targetStartSection: 3,
      targetEndSection: 4,
      addedCourseName: '临时课程',
    );

    await repository.saveException(exception);
    expect(
      (await repository.loadSemester(semester.id)).exceptions,
      hasLength(1),
    );
    await repository.deleteException(exception.id);
    expect((await repository.loadSemester(semester.id)).exceptions, isEmpty);
  });

  test('deletes a semester and clears its preferred selection atomically',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 's1',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    await repository.saveSemester(semester);
    await repository.setPreferredSemesterId(semester.id);
    await repository.saveCourse(
      domain.Course(
        id: 'course-1',
        semesterId: semester.id,
        sourceType: domain.CourseSourceType.manual,
        name: '课程',
      ),
      [],
    );
    await repository.saveException(
      domain.CourseException(
        id: 'exception-1',
        semesterId: semester.id,
        type: domain.CourseExceptionType.add,
        targetDate: DateTime(2026, 9, 8),
        targetStartSection: 1,
        targetEndSection: 2,
        addedCourseName: '临时课',
      ),
    );

    await repository.deleteSemester(semester.id);

    expect(await repository.loadSemesters(), isEmpty);
    expect(await repository.getPreferredSemesterId(), isNull);
    expect(await database.select(database.courses).get(), isEmpty);
    expect(await database.select(database.courseExceptions).get(), isEmpty);
  });

  test('imports atomically, keeps snapshots, and preserves local-only fields',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    RemoteTimetable timetable({String room = '3406', String name = '软件测试'}) =>
        RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
            calendarId: 'nwu-2026-2027-1',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: 'remote-course-1',
              name: name,
              code: 'CS301',
              teachingClass: '软件工程2401',
              credits: 2,
              assessment: '考查',
              meetings: [
                ImportedMeeting(
                  sourceMeetingKey: 'remote-rule-1',
                  weekday: 1,
                  startSection: 3,
                  endSection: 4,
                  teacher: '教师 A',
                  campus: '长安校区',
                  room: room,
                  weekMask: WeekMask.all(16),
                ),
              ],
            ),
          ],
        );

    await repository.commitImportedTimetable(timetable());
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.single.sourceType, domain.CourseSourceType.imported);
    expect(loaded.meetingRules.single.room, '3406');
    expect(await repository.loadLatestImport('nwu-2026-2027-1'), isNotNull);

    final course = loaded.courses.single;
    await repository.saveCourse(
      course.copyWith(note: '我的备注', colorOverride: 0xff123456),
      [loaded.meetingRules.single],
    );
    await repository.commitImportedTimetable(timetable(room: '3508'));
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.room, '3508');
    expect(loaded.courses.single.note, '我的备注');
    expect(loaded.courses.single.colorOverride, 0xff123456);

    final locallyEdited = loaded.courses.single;
    await repository.saveCourse(
      locallyEdited,
      [loaded.meetingRules.single.copyWith(room: '3601')],
    );
    await repository.commitImportedTimetable(timetable(room: '3508'));
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.room, '3601');
    expect(
        (await database.select(database.importSnapshots).get()), hasLength(3));
  });

  test('conflicting import rolls back without adding a snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final base = RemoteTimetable(
      semester: const RemoteSemester(
        remoteTermKey: '2026-2027-1',
        academicYear: '2026-2027',
        term: 1,
        label: '2026-2027 第一学期',
      ),
      totalWeeks: 20,
      courses: [
        ImportedCourse(
          sourceCourseKey: 'c1',
          name: '软件测试',
          code: null,
          teachingClass: null,
          credits: null,
          assessment: null,
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'r1',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: null,
              campus: null,
              room: '3406',
              weekMask: WeekMask.all(16),
            ),
          ],
        ),
      ],
    );
    await repository.commitImportedTimetable(base);
    final loaded = await repository.loadSemester(base.semester.id);
    await repository.saveCourse(
      loaded.courses.single,
      [loaded.meetingRules.single.copyWith(room: '3508')],
    );
    final incoming = RemoteTimetable(
      semester: base.semester,
      totalWeeks: 20,
      courses: [
        ImportedCourse(
          sourceCourseKey: 'c1',
          name: '软件测试',
          code: null,
          teachingClass: null,
          credits: null,
          assessment: null,
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'r1',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: null,
              campus: null,
              room: '3201',
              weekMask: WeekMask.all(16),
            ),
          ],
        ),
      ],
    );
    await expectLater(
      repository.commitImportedTimetable(incoming),
      throwsA(isA<TimetableImportConflictException>()),
    );
    expect(await database.select(database.importSnapshots).get(), hasLength(1));
    expect(
        (await repository.loadSemester(base.semester.id))
            .meetingRules
            .single
            .room,
        '3508');

    await repository.commitImportedTimetable(
      incoming,
      resolution: ImportConflictResolution.copy({
        'c1': {'meetings': MergeDecision.remote},
      }),
    );
    expect(
      (await repository.loadSemester(base.semester.id))
          .meetingRules
          .single
          .room,
      '3201',
    );
    expect(await database.select(database.importSnapshots).get(), hasLength(2));
  });
}
