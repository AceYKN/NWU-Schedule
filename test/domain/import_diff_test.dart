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
  }) =>
      ImportedCourse(
        sourceCourseKey: key,
        name: name,
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
            .firstWhere(
              (field) => field.field == meetingImportField('meeting-1', 'room'),
            )
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
            .firstWhere(
              (field) => field.field == meetingImportField('meeting-1', 'room'),
            )
            .decision,
        MergeDecision.local);
  });

  test('merges independent meeting properties without a false conflict', () {
    final remote = timetable([
      ImportedCourse(
        sourceCourseKey: 'course-1',
        name: '软件测试',
        meetings: [
          ImportedMeeting(
            sourceMeetingKey: 'meeting-1',
            weekday: 1,
            startSection: 3,
            endSection: 4,
            teacher: '教师 B',
            campus: '长安校区',
            room: '3406',
            weekMask: WeekMask.all(16),
          ),
        ],
      ),
    ]);
    final localCourse = local();
    final localSnapshot = ScheduleDataSnapshot(
      semester: localCourse.semester,
      courses: localCourse.courses,
      meetingRules: [
        localCourse.meetingRules.single.copyWith(room: '3508'),
      ],
      exceptions: const [],
    );
    final diff = const ImportDiffEngine().build(
      incoming: remote,
      local: localSnapshot,
      previousImport: timetable([course()]),
    );

    expect(diff.hasConflicts, isFalse);
    expect(
      diff.changes.single.fields
          .firstWhere(
            (field) => field.field == meetingImportField('meeting-1', 'room'),
          )
          .decision,
      MergeDecision.local,
    );
    expect(
      diff.changes.single.fields
          .firstWhere(
            (field) =>
                field.field == meetingImportField('meeting-1', 'teacher'),
          )
          .decision,
      MergeDecision.remote,
    );
  });

  test('uses a separate topology decision for added or removed meetings', () {
    final base = local();
    final secondRule = MeetingRule(
      id: 'local-meeting-2',
      courseId: base.courses.single.id,
      sourceMeetingKey: 'meeting-2',
      weekday: 3,
      startSection: 5,
      endSection: 6,
      teacher: '教师 C',
      campus: '长安校区',
      room: '1310',
      weekMask: WeekMask.all(16),
    );
    final localWithExtraMeeting = ScheduleDataSnapshot(
      semester: base.semester,
      courses: base.courses,
      meetingRules: [...base.meetingRules, secondRule],
      exceptions: const [],
    );
    final removedRemote = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: localWithExtraMeeting,
      previousImport: timetable([course()]),
    );

    expect(
      removedRemote.changes.single.fields
          .firstWhere((field) => field.field == 'meetings')
          .decision,
      MergeDecision.local,
    );
  });

  test('legacy academic metadata changes do not enter the import diff', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: local(),
      previousImport: timetable([course()]),
    );

    expect(diff.changes.single.kind, ImportChangeKind.unchanged);
    expect(
      diff.changes.single.fields.map((field) => field.field),
      containsAll(<String>[
        meetingImportField('meeting-1', 'weekday'),
        meetingImportField('meeting-1', 'startSection'),
        meetingImportField('meeting-1', 'endSection'),
        meetingImportField('meeting-1', 'weekMask'),
        meetingImportField('meeting-1', 'teacher'),
        meetingImportField('meeting-1', 'campus'),
        meetingImportField('meeting-1', 'room'),
      ]),
    );
    expect(
      diff.changes.single.fields.map((field) => field.field),
      isNot(contains('teachingClass')),
    );
  });

  test('matches a rotated source key by unique schedule identity', () {
    final base = local();
    final localCourse = Course(
      id: base.courses.single.id,
      semesterId: base.courses.single.semesterId,
      sourceType: base.courses.single.sourceType,
      sourceCourseKey: 'old-key',
      name: base.courses.single.name,
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

  test('does not guess when same-name schedule identities are ambiguous', () {
    final base = local();
    final secondCourse = Course(
      id: 'local-course-2',
      semesterId: base.courses.single.semesterId,
      sourceType: base.courses.single.sourceType,
      sourceCourseKey: 'second-key',
      name: base.courses.single.name,
    );
    final localWithDuplicateMetadata = ScheduleDataSnapshot(
      semester: base.semester,
      courses: [base.courses.single, secondCourse],
      meetingRules: [
        ...base.meetingRules,
        MeetingRule(
          id: 'local-meeting-2',
          courseId: secondCourse.id,
          sourceMeetingKey: base.meetingRules.single.sourceMeetingKey,
          weekday: base.meetingRules.single.weekday,
          startSection: base.meetingRules.single.startSection,
          endSection: base.meetingRules.single.endSection,
          teacher: base.meetingRules.single.teacher,
          campus: base.meetingRules.single.campus,
          room: base.meetingRules.single.room,
          weekMask: base.meetingRules.single.weekMask,
        ),
      ],
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
        'course-1': {
          meetingImportField('meeting-1', 'room'): MergeDecision.remote,
        },
      }),
    );
    expect(resolved.hasConflicts, isFalse);
    expect(resolved.changes.single.kind, ImportChangeKind.modified);
    expect(
      resolved.changes.single.fields
          .firstWhere(
            (field) => field.field == meetingImportField('meeting-1', 'room'),
          )
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

  test('a stale tombstone cannot override an active local course', () {
    final diff = const ImportDiffEngine().build(
      incoming: timetable([course()]),
      local: local(),
      previousImport: timetable([course()]),
      deletedSourceCourseKeys: {'course-1'},
    );
    expect(diff.changes.single.kind, ImportChangeKind.unchanged);
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
