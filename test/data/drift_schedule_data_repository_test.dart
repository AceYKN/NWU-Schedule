import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/course/course.dart' as domain;
import 'package:nwu_schedule/domain/course/meeting_rule.dart' as domain;
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
}
