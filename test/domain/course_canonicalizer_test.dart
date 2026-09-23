import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_canonicalizer.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';

void main() {
  test('merges same-name courses and remaps rules and exceptions', () {
    final created = DateTime(2026, 9, 1);
    final updatedA = DateTime(2026, 9, 2);
    final updatedB = DateTime(2026, 9, 3);
    final manual = Course(
      id: 'manual-course',
      semesterId: 'semester',
      sourceType: CourseSourceType.manual,
      name: '机器学习',
      note: '旧备注',
      colorOverride: 0xff123456,
      hidden: false,
      deleted: false,
      createdAt: created,
      updatedAt: updatedA,
    );
    final imported = Course(
      id: 'imported-course',
      semesterId: 'semester',
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'remote-key',
      name: ' 机器学习\u00a0',
      note: '新备注',
      colorOverride: 0xff654321,
      hidden: true,
      deleted: false,
      createdAt: DateTime(2026, 9, 2),
      updatedAt: updatedB,
    );
    final manualRule = MeetingRule(
      id: 'manual-rule',
      courseId: manual.id,
      weekday: DateTime.monday,
      startSection: 1,
      endSection: 2,
      teacher: '教师甲',
      weekMask: WeekMask(3, rawText: '1-2周'),
    );
    final importedRule = MeetingRule(
      id: 'imported-rule',
      courseId: imported.id,
      sourceMeetingKey: 'remote-meeting',
      weekday: DateTime.monday,
      startSection: 1,
      endSection: 2,
      campus: '长安校区',
      room: '3406',
      weekMask: WeekMask(3, rawText: '1-2周'),
    );
    final exception = CourseException(
      id: 'exception',
      semesterId: 'semester',
      courseId: manual.id,
      sourceMeetingId: manualRule.id,
      sourceDate: DateTime(2026, 9, 7),
      type: CourseExceptionType.cancel,
    );

    final result = CourseCanonicalizer.canonicalize(
      courses: [manual, imported],
      meetingRules: [manualRule, importedRule],
      exceptions: [exception],
    );

    expect(result.courses, hasLength(1));
    final course = result.courses.single;
    expect(course.id, imported.id);
    expect(course.sourceType, CourseSourceType.imported);
    expect(course.sourceCourseKey, 'remote-key');
    expect(course.note, '新备注');
    expect(course.colorOverride, 0xff654321);
    expect(course.hidden, isFalse);
    expect(course.deleted, isFalse);
    expect(course.createdAt, created);
    expect(course.updatedAt, updatedB);

    expect(result.meetingRules, hasLength(1));
    expect(result.meetingRules.single.id, importedRule.id);
    expect(result.meetingRules.single.courseId, imported.id);
    expect(result.meetingRules.single.teacher, '教师甲');
    expect(result.meetingRules.single.campus, '长安校区');
    expect(result.meetingRules.single.room, '3406');

    expect(result.exceptions.single.courseId, imported.id);
    expect(result.exceptions.single.sourceMeetingId, importedRule.id);
  });

  test('canonical course favors active imported, then active manual', () {
    final now = DateTime(2026, 9, 1);
    Course course(String id, CourseSourceType type, {bool deleted = false}) =>
        Course(
          id: id,
          semesterId: 'semester',
          sourceType: type,
          name: '同一课程',
          deleted: deleted,
          createdAt: now,
          updatedAt: now,
        );

    final importedDeleted = course(
      'imported-deleted',
      CourseSourceType.imported,
      deleted: true,
    );
    final manualActive = course('manual-active', CourseSourceType.manual);
    final importedActive = course('imported-active', CourseSourceType.imported);

    expect(
      CourseCanonicalizer.canonicalize(
        courses: [importedDeleted, manualActive, importedActive],
        meetingRules: const [],
        exceptions: const [],
      ).courses.single.id,
      importedActive.id,
    );
    expect(
      CourseCanonicalizer.canonicalize(
        courses: [importedDeleted, manualActive],
        meetingRules: const [],
        exceptions: const [],
      ).courses.single.id,
      manualActive.id,
    );
  });
}
