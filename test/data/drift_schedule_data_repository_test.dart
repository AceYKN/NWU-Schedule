import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart' as domain;
import 'package:nwu_schedule/domain/course/course_exception.dart' as domain;
import 'package:nwu_schedule/domain/course/meeting_rule.dart' as domain;
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
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
      calendarRevision: 1,
      createdAt: createdAt,
    );
    await firstChange;
    await repository.saveSemester(semester);
    expect((await repository.loadSemesters()).single.id, semester.id);
    expect((await repository.loadSemesters()).single.calendarRevision, 1);

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

  test('clears obsolete course metadata when saving over a legacy row', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = domain.Semester(
      id: 'legacy-semester',
      academicYear: '2026-2027',
      term: domain.SemesterTerm.first,
      label: '第一学期',
      createdAt: DateTime(2026, 9, 1),
    );
    await repository.saveSemester(semester);

    await database.into(database.courses).insert(
          CoursesCompanion.insert(
            id: 'legacy-course',
            semesterId: semester.id,
            sourceType: domain.CourseSourceType.manual.name,
            name: '旧课程',
            code: const Value('CS101'),
            teachingClass: const Value('教学班 A'),
            credits: const Value(3.0),
            assessment: const Value('考查'),
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    await repository.saveCourse(
      domain.Course(
        id: 'legacy-course',
        semesterId: semester.id,
        sourceType: domain.CourseSourceType.manual,
        name: '新课程',
      ),
      [
        domain.MeetingRule(
          id: 'legacy-rule',
          courseId: 'legacy-course',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weekMask: WeekMask.fromWeeks([1]),
        ),
      ],
    );

    final row = await (database.select(database.courses)
          ..where((table) => table.id.equals('legacy-course')))
        .getSingle();
    expect(row.code, isNull);
    expect(row.teachingClass, isNull);
    expect(row.credits, isNull);
    expect(row.assessment, isNull);
  });

  test('saves a course and removes deleted-rule exceptions atomically',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    const semesterId = 's1';
    await repository.saveSemester(
      domain.Semester(
        id: semesterId,
        academicYear: '2026-2027',
        term: domain.SemesterTerm.first,
        label: '第一学期',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    final course = domain.Course(
      id: 'course-1',
      semesterId: semesterId,
      sourceType: domain.CourseSourceType.manual,
      name: '软件测试',
    );
    final oldRule = domain.MeetingRule(
      id: 'rule-old',
      courseId: course.id,
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weekMask: WeekMask.all(20),
    );
    await repository.saveCourse(course, [oldRule]);
    await repository.saveException(
      domain.CourseException(
        id: 'exception-old',
        semesterId: semesterId,
        courseId: course.id,
        sourceMeetingId: oldRule.id,
        sourceDate: DateTime(2026, 9, 7),
        type: domain.CourseExceptionType.cancel,
      ),
    );

    final newRule = oldRule.copyWith(weekday: 2);
    await repository.saveCourse(
      course,
      [newRule],
      removeExceptionIds: const ['exception-old'],
    );

    final snapshot = await repository.loadSemester(semesterId);
    expect(snapshot.meetingRules.single.weekday, 2);
    expect(snapshot.exceptions, isEmpty);
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

  test('merges independent local and remote meeting properties', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    RemoteTimetable timetable({
      required String teacher,
      required String room,
    }) =>
        RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: 'course-merge',
              name: '软件测试',
              meetings: [
                ImportedMeeting(
                  sourceMeetingKey: 'meeting-merge',
                  weekday: 1,
                  startSection: 3,
                  endSection: 4,
                  teacher: teacher,
                  campus: '长安校区',
                  room: room,
                  weekMask: WeekMask.all(16),
                ),
              ],
            ),
          ],
        );

    await repository.commitImportedTimetable(
      timetable(teacher: '教师 A', room: '3406'),
    );
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    await repository.saveCourse(
      loaded.courses.single,
      [loaded.meetingRules.single.copyWith(room: '3508')],
    );

    final preview = await repository.previewImportedTimetable(
      timetable(teacher: '教师 B', room: '3406'),
    );
    expect(preview.hasConflicts, isFalse);
    await repository.commitImportedTimetable(
      timetable(teacher: '教师 B', room: '3406'),
    );

    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.teacher, '教师 B');
    expect(loaded.meetingRules.single.room, '3508');
  });

  test('preserves the course when the remote source key rotates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    RemoteTimetable timetable({
      required String key,
      String room = '3406',
    }) =>
        RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: key,
              name: '软件测试',
              meetings: [
                ImportedMeeting(
                  sourceMeetingKey: '$key-meeting',
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

    await repository.commitImportedTimetable(timetable(key: 'old-key'));
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    final originalId = loaded.courses.single.id;
    await repository.saveCourse(
      loaded.courses.single.copyWith(
        note: '我的备注',
        colorOverride: 0xff123456,
      ),
      loaded.meetingRules,
    );

    final diff = await repository.previewImportedTimetable(
      timetable(key: 'new-key', room: '3508'),
    );
    expect(diff.changes, hasLength(1));
    expect(diff.changes.single.kind, ImportChangeKind.modified);
    await repository.commitImportedTimetable(
      timetable(key: 'new-key', room: '3508'),
    );

    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.single.id, originalId);
    expect(loaded.courses.single.sourceCourseKey, 'new-key');
    expect(loaded.courses.single.note, '我的备注');
    expect(loaded.courses.single.colorOverride, 0xff123456);
    expect(loaded.meetingRules.single.room, '3508');
  });

  test('preserves CANCEL and MOVE exceptions across meeting reconciliation',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);

    RemoteTimetable timetable({
      required String meetingKey,
      required int startSection,
      required int endSection,
      required String teacher,
      required String room,
      String weekText = '1-16周',
    }) {
      return RemoteTimetable(
        semester: const RemoteSemester(
          remoteTermKey: '2026-2027-1',
          academicYear: '2026-2027',
          term: 1,
          label: '2026-2027 第一学期',
        ),
        totalWeeks: 16,
        courses: [
          ImportedCourse(
            sourceCourseKey: 'course-identity-regression',
            name: '软件测试',
            meetings: [
              ImportedMeeting(
                sourceMeetingKey: meetingKey,
                weekday: 1,
                startSection: startSection,
                endSection: endSection,
                teacher: teacher,
                campus: '长安校区',
                room: room,
                weekMask: WeekMask.parse(weekText, maxWeek: 16),
              ),
            ],
          ),
        ],
      );
    }

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'remote-rule-v1',
        startSection: 3,
        endSection: 4,
        teacher: '教师 A',
        room: '3406',
      ),
    );
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    final course = loaded.courses.single;
    final originalRule = loaded.meetingRules.single;
    await repository.saveException(
      domain.CourseException(
        id: 'cancel-after-reimport',
        semesterId: course.semesterId,
        courseId: course.id,
        sourceMeetingId: originalRule.id,
        sourceDate: DateTime(2026, 9, 7),
        type: domain.CourseExceptionType.cancel,
      ),
    );
    await repository.saveException(
      domain.CourseException(
        id: 'move-after-reimport',
        semesterId: course.semesterId,
        courseId: course.id,
        sourceMeetingId: originalRule.id,
        sourceDate: DateTime(2026, 9, 14),
        type: domain.CourseExceptionType.move,
        targetDate: DateTime(2026, 9, 15),
        targetStartSection: 7,
        targetEndSection: 8,
      ),
    );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'remote-rule-v2',
        startSection: 5,
        endSection: 6,
        teacher: '教师 B',
        room: '3508',
        // Keep the effective weeks unchanged while changing the remote text;
        // this exercises reconciliation independently from the WeekMask value.
        weekText: '1-8周,9-16周',
      ),
    );

    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.id, originalRule.id);
    expect(loaded.meetingRules.single.sourceMeetingKey, 'remote-rule-v2');
    expect(loaded.meetingRules.single.startSection, 5);
    expect(loaded.meetingRules.single.endSection, 6);
    expect(loaded.meetingRules.single.teacher, '教师 B');
    expect(loaded.meetingRules.single.room, '3508');
    expect(
      loaded.exceptions.map((exception) => exception.sourceMeetingId),
      everyElement(originalRule.id),
    );

    final calendar = CalendarDefinition(
      id: 'nwu-2026-2027-1',
      school: 'NWU',
      academicYear: '2026-2027',
      term: 1,
      semesterStartDate: DateTime(2026, 9, 1),
      week1StartDate: DateTime(2026, 9, 7),
      semesterEndDate: DateTime(2026, 10, 4),
      totalWeeks: 4,
      revision: 1,
      dateOverrides: const [],
    );
    final snapshot = ScheduleEngine(
      semesterId: course.semesterId,
      calendarEngine: CalendarEngine(calendar),
      courses: loaded.courses,
      meetingRules: loaded.meetingRules,
      exceptions: loaded.exceptions,
    );

    expect(snapshot.getCoursesForDate(DateTime(2026, 9, 7)), isEmpty);
    expect(snapshot.getCoursesForDate(DateTime(2026, 9, 14)), isEmpty);
    final moved = snapshot.getCoursesForDate(DateTime(2026, 9, 15));
    expect(moved, hasLength(1));
    expect(moved.single.isException, isTrue);
    expect(moved.single.startSection, 7);
    expect(moved.single.endSection, 8);
  });

  test('removes stale tombstones when a deleted course key rotates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    RemoteTimetable timetable(String key) => RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: key,
              name: '软件测试',
              meetings: [
                ImportedMeeting(
                  sourceMeetingKey: '$key-meeting',
                  weekday: 1,
                  startSection: 3,
                  endSection: 4,
                  teacher: null,
                  campus: null,
                  room: '3406',
                  weekMask: WeekMask.all(20),
                ),
              ],
            ),
          ],
        );

    await repository.commitImportedTimetable(timetable('old-key'));
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    await repository.deleteCourse(loaded.courses.single.id);

    await repository.commitImportedTimetable(timetable('new-key'));
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.single.deleted, isTrue);
    expect(
      (await database.select(database.deletedSourceItems).get())
          .map((row) => row.sourceCourseKey),
      contains('old-key'),
    );

    await repository.commitImportedTimetable(
      timetable('new-key'),
      resolution: ImportConflictResolution.copy(
        const {},
        restoreDeletedCourseKeys: {'new-key'},
      ),
    );
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.single.deleted, isFalse);
    expect(await database.select(database.deletedSourceItems).get(), isEmpty);

    await repository.commitImportedTimetable(timetable('old-key'));
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.single.deleted, isFalse);
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
        'c1': {
          meetingImportField('r1', 'room'): MergeDecision.remote,
        },
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

  test('restoring a locally deleted import removes its tombstone', () async {
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
          name: '已删除课程',
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'rule-1',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: null,
              campus: null,
              room: '3406',
              weekMask: WeekMask.all(20),
            ),
          ],
        ),
      ],
    );
    await repository.commitImportedTimetable(timetable);
    final course =
        (await repository.loadSemester(timetable.semester.id)).courses.single;
    await repository.deleteCourse(course.id);

    final preview = await repository.previewImportedTimetable(timetable);
    expect(preview.hasLocallyDeleted, isTrue);
    expect(preview.locallyDeletedCount, 1);

    await repository.commitImportedTimetable(timetable);
    final keptDeleted =
        (await repository.loadSemester(timetable.semester.id)).courses.single;
    expect(keptDeleted.deleted, isTrue);
    expect(
      (await database.select(database.deletedSourceItems).get())
          .single
          .sourceCourseKey,
      'course-1',
    );

    await repository.commitImportedTimetable(
      timetable,
      resolution: ImportConflictResolution.copy(
        const {},
        restoreDeletedCourseKeys: {'course-1'},
      ),
    );

    final restored = await repository.loadSemester(timetable.semester.id);
    expect(restored.courses.single.deleted, isFalse);
    expect(await database.select(database.deletedSourceItems).get(), isEmpty);
  });

  test('rejects a partial DOM import before it can delete a course', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);

    RemoteTimetable timetable({required bool partial}) => RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            for (final entry in const [
              ('a', '课程 A'),
              ('b', '课程 B'),
            ])
              if (!partial || entry.$1 == 'a')
                ImportedCourse(
                  sourceCourseKey: entry.$1,
                  name: entry.$2,
                  meetings: [
                    ImportedMeeting(
                      sourceMeetingKey: 'rule-${entry.$1}',
                      weekday: 1,
                      startSection: entry.$1 == 'a' ? 1 : 3,
                      endSection: entry.$1 == 'a' ? 2 : 4,
                      teacher: null,
                      campus: null,
                      room: '3406',
                      weekMask: WeekMask.all(20),
                    ),
                  ],
                ),
          ],
          issues: partial
              ? const [
                  ImportIssue(
                    path: 'tables[0].rows[2].sections',
                    message: '节次无法识别，已跳过该行',
                    severity: ImportIssueSeverity.error,
                  ),
                ]
              : const [],
        );

    await repository.commitImportedTimetable(timetable(partial: false));
    await expectLater(
      repository.commitImportedTimetable(timetable(partial: true)),
      throwsA(isA<TimetableImportValidationException>()),
    );

    final loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.courses.map((course) => course.sourceCourseKey),
        containsAll(<String>['a', 'b']));
    expect(loaded.courses.every((course) => !course.deleted), isTrue);
    expect(await database.select(database.deletedSourceItems).get(), isEmpty);
    expect(await database.select(database.importSnapshots).get(), hasLength(1));
  });

  test('rejects invalid timetable previews before reading the local diff',
      () async {
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
          sourceCourseKey: 'course-a',
          name: '课程 A',
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'rule-a',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: null,
              campus: null,
              room: null,
              weekMask: WeekMask.all(20),
            ),
          ],
        ),
      ],
      issues: [
        const ImportIssue(
          path: 'tables[0].rows[2].sections',
          message: '节次无法识别，已跳过该行',
          severity: ImportIssueSeverity.error,
        ),
      ],
    );

    await expectLater(
      repository.previewImportedTimetable(timetable),
      throwsA(isA<TimetableImportValidationException>()),
    );
    expect(await database.select(database.semesters).get(), isEmpty);
    expect(await database.select(database.courses).get(), isEmpty);
    expect(await database.select(database.importSnapshots).get(), isEmpty);
  });

  test('preserves meeting identity when mutable timetable fields change',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);

    RemoteTimetable timetable({
      required String meetingKey,
      required String teacher,
      required String room,
      required WeekMask weekMask,
      int weekday = 1,
      int startSection = 3,
      int endSection = 4,
      bool omitMeeting = false,
    }) =>
        RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: 'course-identity',
              name: '软件测试',
              meetings: omitMeeting
                  ? const <ImportedMeeting>[]
                  : [
                      ImportedMeeting(
                        sourceMeetingKey: meetingKey,
                        weekday: weekday,
                        startSection: startSection,
                        endSection: endSection,
                        teacher: teacher,
                        campus: '长安校区',
                        room: room,
                        weekMask: weekMask,
                      ),
                    ],
            ),
          ],
        );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'dom|1|3|4|教师 A|3406|1-20周',
        teacher: '教师 A',
        room: '3406',
        weekMask: WeekMask.all(20),
      ),
    );
    var loaded = await repository.loadSemester('nwu-2026-2027-1');
    final originalRule = loaded.meetingRules.single;
    await repository.saveException(
      domain.CourseException(
        id: 'cancel-identity',
        semesterId: loaded.semester.id,
        courseId: loaded.courses.single.id,
        sourceMeetingId: originalRule.id,
        sourceDate: DateTime(2026, 9, 7),
        type: domain.CourseExceptionType.cancel,
      ),
    );
    await repository.saveException(
      domain.CourseException(
        id: 'move-identity',
        semesterId: loaded.semester.id,
        courseId: loaded.courses.single.id,
        sourceMeetingId: originalRule.id,
        sourceDate: DateTime(2026, 9, 14),
        type: domain.CourseExceptionType.move,
        targetDate: DateTime(2026, 9, 15),
        targetStartSection: 7,
        targetEndSection: 8,
      ),
    );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'dom|1|3|4|教师 B|3508|1-20周双周',
        teacher: '教师 B',
        room: '3508',
        weekMask: WeekMask.fromWeeks(
          [1, 3, 5, 7, 9, 11, 13, 15, 17, 19],
          rawText: '1-20周单周',
        ),
      ),
    );

    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.id, originalRule.id);
    expect(loaded.meetingRules.single.teacher, '教师 B');
    expect(loaded.meetingRules.single.room, '3508');
    expect(
      loaded.exceptions.map((exception) => exception.sourceMeetingId),
      everyElement(originalRule.id),
    );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'dom|2|5|6|教师 B|3508|1-20周单周',
        teacher: '教师 B',
        room: '3508',
        weekMask: WeekMask.fromWeeks(
          [1, 3, 5, 7, 9, 11, 13, 15, 17, 19],
          rawText: '1-20周单周',
        ),
        weekday: 2,
        startSection: 5,
        endSection: 6,
      ),
    );

    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.id, originalRule.id);
    expect(loaded.meetingRules.single.startSection, 5);
    expect(loaded.meetingRules.single.endSection, 6);
    expect(
      loaded.exceptions.map((exception) => exception.sourceMeetingId),
      everyElement(originalRule.id),
    );

    await expectLater(
      repository.commitImportedTimetable(
        timetable(
          meetingKey: 'dom|removed',
          teacher: '教师 B',
          room: '3508',
          weekMask: WeekMask.all(20),
          omitMeeting: true,
        ),
      ),
      throwsA(isA<TimetableImportValidationException>()),
    );
    loaded = await repository.loadSemester('nwu-2026-2027-1');
    expect(loaded.meetingRules.single.id, originalRule.id);
    expect(loaded.exceptions, hasLength(2));

    final definition = CalendarDefinition.fromJson({
      'id': 'nwu-2026-2027-1',
      'school': 'NWU',
      'academicYear': '2026-2027',
      'term': 1,
      'semesterStartDate': '2026-09-01',
      'week1StartDate': '2026-09-07',
      'semesterEndDate': '2026-10-31',
      'totalWeeks': 8,
      'revision': 1,
      'dateOverrides': [],
    });
    final engine = ScheduleEngine(
      semesterId: loaded.semester.id,
      calendarEngine: CalendarEngine(definition),
      courses: loaded.courses,
      meetingRules: loaded.meetingRules,
      exceptions: loaded.exceptions,
    );
    expect(engine.getCoursesForDate(DateTime(2026, 9, 7)), isEmpty);
  });

  test('does not merge a meeting when its structural shape has no overlap',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);

    RemoteTimetable timetable({
      required String meetingKey,
      required int weekday,
      required int startSection,
      required int endSection,
      required WeekMask weekMask,
    }) =>
        RemoteTimetable(
          semester: const RemoteSemester(
            remoteTermKey: '2026-2027-1',
            academicYear: '2026-2027',
            term: 1,
            label: '2026-2027 第一学期',
          ),
          totalWeeks: 20,
          courses: [
            ImportedCourse(
              sourceCourseKey: 'course-structural-identity',
              name: '软件测试',
              meetings: [
                ImportedMeeting(
                  sourceMeetingKey: meetingKey,
                  weekday: weekday,
                  startSection: startSection,
                  endSection: endSection,
                  teacher: '同一教师',
                  campus: '长安校区',
                  room: '同一教室',
                  weekMask: weekMask,
                ),
              ],
            ),
          ],
        );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'old-meeting',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        weekMask: WeekMask.fromWeeks([1, 2, 3, 4]),
      ),
    );
    final first = await repository.loadSemester('nwu-2026-2027-1');
    final oldRule = first.meetingRules.single;
    await repository.saveException(
      domain.CourseException(
        id: 'cancel-structural-identity',
        semesterId: first.semester.id,
        courseId: first.courses.single.id,
        sourceMeetingId: oldRule.id,
        sourceDate: DateTime(2026, 9, 7),
        type: domain.CourseExceptionType.cancel,
      ),
    );

    await repository.commitImportedTimetable(
      timetable(
        meetingKey: 'new-meeting',
        weekday: 5,
        startSection: 7,
        endSection: 8,
        weekMask: WeekMask.fromWeeks([17, 18, 19, 20]),
      ),
    );

    final second = await repository.loadSemester('nwu-2026-2027-1');
    expect(second.meetingRules.single.id, isNot(oldRule.id));
    expect(second.meetingRules.single.weekday, 5);
    expect(second.exceptions, isEmpty);
  });
}
