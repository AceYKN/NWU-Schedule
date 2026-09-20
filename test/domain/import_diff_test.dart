import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/domain/schedule/schedule_data_repository.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';

void main() {
  final semester = Semester(
    id: 'nwu-2026-2027-1',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    createdAt: DateTime(2026, 9, 1),
  );

  ImportedMeeting meeting({String room = '3406'}) => ImportedMeeting(
        sourceMeetingKey: 'meeting-1',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        teacher: '教师 A',
        campus: '长安校区',
        room: room,
        weekMask: WeekMask.all(16),
      );

  ImportedCourse course({
    String key = 'course-1',
    String room = '3406',
    String name = '软件测试',
    String? code = 'CS301',
    String? teachingClass = '软件工程2401',
    double? credits = 2,
    String? assessment = '考查',
  }) =>
      ImportedCourse(
        sourceCourseKey: key,
        name: name,
        code: code,
        teachingClass: teachingClass,
        credits: credits,
        assessment: assessment,
        meetings: [meeting(room: room)],
      );

  RemoteTimetable timetable(List<ImportedCourse> courses) => RemoteTimetable(
        semester: const RemoteSemester(
          remoteTermKey: '2026-2027-1',
          academicYear: '2026-2027',
          term: 1,
          label: '2026-2027 第一学期',
        ),
        totalWeeks: 20,
        courses: courses,
      );

  ScheduleDataSnapshot local({String room = '3406', String name = '软件测试'}) {
    final localCourse = Course(
      id: 'local-course-1',
      semesterId: semester.id,
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'course-1',
      name: name,
      code: 'CS301',
      teachingClass: '软件工程2401',
      credits: 2,
      assessment: '考查',
    );
    return ScheduleDataSnapshot(
      semester: semester,
      courses: [localCourse],
      meetingRules: [
        MeetingRule(
          id: 'local-meeting-1',
          courseId: localCourse.id,
          sourceMeetingKey: 'meeting-1',
          weekday: 1,
          startSection: 3,
          endSection: 4,
          teacher: '教师 A',
          campus: '长安校区',
          room: room,
          weekMask: WeekMask.all(16),
        ),
      ],
      exceptions: const [],
    );
  }

  test('remote-only change is modified without conflict', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(room: '3508')]),
      local: local(),
      previousImport: timetable([course()]),
    );
    expect(diff.changes.single.kind, ImportChangeKind.modified);
    expect(diff.hasConflicts, isFalse);
    expect(
        diff.changes.single.fields
            .firstWhere((field) => field.field == 'meetings')
            .decision,
        MergeDecision.remote);
  });

  test('marks a different semester as a new local timetable', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: null,
      previousImport: null,
    );

    expect(diff.isNewSemester, isTrue);
    expect(diff.resolve(ImportConflictResolution.empty).isNewSemester, isTrue);
  });

  test('local-only change is retained without conflict', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: local(room: '3508'),
      previousImport: timetable([course()]),
    );
    expect(diff.changes.single.kind, ImportChangeKind.modified);
    expect(diff.hasConflicts, isFalse);
    expect(
        diff.changes.single.fields
            .firstWhere((field) => field.field == 'meetings')
            .decision,
        MergeDecision.local);
  });

  test('includes academic metadata changes in the import diff', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable(
        [
          course(
            code: 'REMOTE-CODE',
            teachingClass: 'REMOTE-CLASS',
            credits: 99,
            assessment: 'REMOTE-ASSESSMENT',
          ),
        ],
      ),
      local: local(),
      previousImport: timetable([course()]),
    );

    expect(diff.changes.single.kind, ImportChangeKind.modified);
    expect(
      diff.changes.single.fields.map((field) => field.field),
      [
        'name',
        'code',
        'teachingClass',
        'credits',
        'assessment',
        'meetings',
      ],
    );
    expect(
      diff.changes.single.fields
          .firstWhere((field) => field.field == 'code')
          .decision,
      MergeDecision.remote,
    );
  });

  test('matches a rotated source key by unique course code and teaching class',
      () {
    final base = local();
    final localCourse = Course(
      id: base.courses.single.id,
      semesterId: base.courses.single.semesterId,
      sourceType: base.courses.single.sourceType,
      sourceCourseKey: 'old-key',
      name: base.courses.single.name,
      code: base.courses.single.code,
      teachingClass: base.courses.single.teachingClass,
      credits: base.courses.single.credits,
      assessment: base.courses.single.assessment,
    );
    final localWithRotatedKey = ScheduleDataSnapshot(
      semester: base.semester,
      courses: [localCourse],
      meetingRules: base.meetingRules,
      exceptions: base.exceptions,
    );
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(key: 'new-key')]),
      local: localWithRotatedKey,
      previousImport: timetable([course(key: 'old-key')]),
    );

    expect(diff.changes, hasLength(1));
    expect(diff.changes.single.kind, ImportChangeKind.modified);
    expect(diff.changes.single.localCourse?.id, 'local-course-1');
    expect(diff.changes.single.remoteCourse?.sourceCourseKey, 'new-key');
  });

  test('does not guess when code and teaching class are not unique', () {
    final base = local();
    final secondCourse = Course(
      id: 'local-course-2',
      semesterId: base.courses.single.semesterId,
      sourceType: base.courses.single.sourceType,
      sourceCourseKey: 'second-key',
      name: base.courses.single.name,
      code: base.courses.single.code,
      teachingClass: base.courses.single.teachingClass,
      credits: base.courses.single.credits,
      assessment: base.courses.single.assessment,
    );
    final localWithDuplicateMetadata = ScheduleDataSnapshot(
      semester: base.semester,
      courses: [base.courses.single, secondCourse],
      meetingRules: base.meetingRules,
      exceptions: base.exceptions,
    );
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(key: 'new-key')]),
      local: localWithDuplicateMetadata,
      previousImport: null,
    );

    expect(diff.changes.where((item) => item.kind == ImportChangeKind.added),
        hasLength(1));
    expect(
      diff.changes.where((item) => item.kind == ImportChangeKind.removed),
      hasLength(2),
    );
  });

  test('divergent local and remote changes produce a conflict', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(room: '3201')]),
      local: local(room: '3508'),
      previousImport: timetable([course()]),
    );
    expect(diff.changes.single.kind, ImportChangeKind.conflict);
    expect(diff.hasConflicts, isTrue);
  });

  test('explicit conflict resolution turns a conflict into an import choice',
      () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(room: '3201')]),
      local: local(room: '3508'),
      previousImport: timetable([course()]),
    );
    final resolved = diff.resolve(
      ImportConflictResolution.copy({
        'course-1': {'meetings': MergeDecision.remote},
      }),
    );
    expect(resolved.hasConflicts, isFalse);
    expect(resolved.changes.single.kind, ImportChangeKind.modified);
    expect(
      resolved.changes.single.fields
          .firstWhere((field) => field.field == 'meetings')
          .decision,
      MergeDecision.remote,
    );
  });

  test('handles remote add, delete and manual-course exclusion', () {
    final manual = Course(
      id: 'manual',
      semesterId: semester.id,
      sourceType: CourseSourceType.manual,
      name: '手动课程',
    );
    final localWithManual = local();
    final removedCourse = Course(
      id: 'local-course-removed',
      semesterId: semester.id,
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'course-removed',
      name: '远端已删除课程',
    );
    final snapshot = ScheduleDataSnapshot(
      semester: localWithManual.semester,
      courses: [...localWithManual.courses, manual, removedCourse],
      meetingRules: localWithManual.meetingRules,
      exceptions: const [],
    );
    final diff = const ImportDiffEngine().build(
      incoming: timetable([
        course(),
        course(key: 'course-new', name: '新增课程'),
      ]),
      local: snapshot,
      previousImport: timetable([
        course(),
        course(key: 'course-removed', name: '远端已删除课程'),
      ]),
    );
    expect(
        diff.changes.where((change) => change.kind == ImportChangeKind.added),
        hasLength(1));
    expect(
        diff.changes.any((change) =>
            change.kind == ImportChangeKind.unchanged &&
            change.sourceCourseKey == 'course-1'),
        isTrue);
    expect(
        diff.changes.any((change) =>
            change.kind == ImportChangeKind.removed &&
            change.sourceCourseKey == 'course-removed'),
        isTrue);
    expect(diff.changes.any((change) => change.sourceCourseKey == 'manual'),
        isFalse);
  });

  test('tombstone prevents a remote course from silently returning', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: null,
      previousImport: timetable([course()]),
      deletedSourceCourseKeys: {'course-1'},
    );
    expect(diff.changes.single.kind, ImportChangeKind.locallyDeleted);
  });

  test('explicitly restoring a tombstone turns it into an added course', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course(name: '已恢复课程')]),
      local: null,
      previousImport: timetable([course()]),
      deletedSourceCourseKeys: {'course-1'},
    );
    final restored = diff.resolve(
      ImportConflictResolution.copy(
        const {},
        restoreDeletedCourseKeys: {'course-1'},
      ),
    );

    expect(restored.changes.single.kind, ImportChangeKind.added);
    expect(restored.hasLocallyDeleted, isFalse);
  });
}
