import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/backup/schedule_backup.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';

void main() {
  final semester = Semester(
    id: 'nwu-2026-2027-1',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    calendarId: 'nwu-2026-2027-1',
    calendarRevision: 1,
    createdAt: DateTime.utc(2026, 9, 1),
  );
  final course = Course(
    id: 'course-1',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '软件测试',
    code: 'CS301',
    note: '带自己的备注',
    colorOverride: 0xff123456,
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 1, 9),
  );
  final rule = MeetingRule(
    id: 'rule-1',
    courseId: course.id,
    weekday: 1,
    startSection: 3,
    endSection: 4,
    teacher: '教师 A',
    campus: '长安校区',
    room: '3406',
    weekMask: WeekMask.all(16, rawText: '1-16周'),
  );
  final exception = CourseException(
    id: 'exception-1',
    semesterId: semester.id,
    courseId: course.id,
    sourceMeetingId: rule.id,
    sourceDate: DateTime.utc(2026, 10, 1),
    type: CourseExceptionType.cancel,
    note: '国庆停课',
  );

  test('encodes and decodes a complete local backup', () {
    final original = ScheduleBackup(
      createdAt: DateTime.utc(2026, 9, 17, 12),
      semesters: [semester],
      courses: [course],
      meetingRules: [rule],
      exceptions: [exception],
      settings: const {'preferredSemesterId': 'nwu-2026-2027-1'},
      appearance: const {'themeId': 'stone-blue'},
    );

    final restored = ScheduleBackup.decode(original.encode());

    expect(restored.semesters.single.toJson(), semester.toJson());
    expect(restored.courses.single.name, '软件测试');
    expect(restored.courses.single.note, '带自己的备注');
    expect(restored.meetingRules.single.weekMask.value, rule.weekMask.value);
    expect(restored.meetingRules.single.weekMask.rawText, '1-16周');
    expect(restored.exceptions.single.type, CourseExceptionType.cancel);
    expect(restored.settings['preferredSemesterId'], semester.id);
    expect(restored.appearance['themeId'], 'stone-blue');
  });

  test('rejects credentials and broken references', () {
    final source = ScheduleBackup(
      createdAt: DateTime.utc(2026, 9, 17),
      semesters: [semester],
      courses: [course],
      meetingRules: [rule],
      exceptions: [exception],
      settings: const {},
      appearance: const {},
    ).toJson();

    expect(
      () => ScheduleBackup.fromJson({
        ...source,
        'settings': {'password': 'x'}
      }),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => ScheduleBackup.fromJson({
        ...source,
        'meetingRules': [
          {
            ...(source['meetingRules'] as List).single as Map,
            'courseId': 'missing'
          },
        ],
      }),
      throwsA(isA<BackupValidationException>()),
    );
  });
}
