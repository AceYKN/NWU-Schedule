import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/import/import_identity.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';

void main() {
  const matcher = ImportIdentityMatcher();

  ImportedMeeting importedMeeting({
    String key = 'remote-meeting',
    int weekday = 1,
    int startSection = 3,
    int endSection = 4,
    String? teacher = '教师甲',
    String? campus = '长安校区',
    String? room = '3406',
    WeekMask? weeks,
  }) {
    return ImportedMeeting(
      sourceMeetingKey: key,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      teacher: teacher,
      campus: campus,
      room: room,
      weekMask: weeks ?? WeekMask.all(16),
    );
  }

  MeetingRule localMeeting({
    String id = 'local-meeting',
    String? sourceKey = 'old-meeting',
    int weekday = 1,
    int startSection = 3,
    int endSection = 4,
    String? teacher = '教师甲',
    String? campus = '长安校区',
    String? room = '3406',
    WeekMask? weeks,
  }) {
    return MeetingRule(
      id: id,
      courseId: 'local-course',
      sourceMeetingKey: sourceKey,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      teacher: teacher,
      campus: campus,
      room: room,
      weekMask: weeks ?? WeekMask.all(16),
    );
  }

  test('matches a rotated course key without academic metadata fields', () {
    final remote = ImportedCourse(
      sourceCourseKey: 'CS301|class-B|4|考试',
      name: '软件测试',
      meetings: [importedMeeting()],
    );
    final local = Course(
      id: 'local-course',
      semesterId: 'semester',
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'CS301|class-A|2|考查',
      name: '软件测试',
    );

    expect(
      matcher.matchLocalCourse(
        remote,
        [local],
        {
          local.id: [localMeeting()],
        },
      ),
      same(local),
    );
  });

  test('preserves meeting identity when mutable properties change', () {
    final remote = importedMeeting(
      key: 'new-meeting-key',
      teacher: '教师乙',
      room: '3508',
    );
    final result = matcher.matchMeeting(remote, [
      localMeeting(teacher: '教师甲', room: '3406'),
    ]);

    expect(result, isNotNull);
    expect(result?.id, 'local-meeting');
  });

  test(
    'prefers an exact source meeting key over a competing structural match',
    () {
      final remote = importedMeeting(key: 'target-key');
      final exact = localMeeting(id: 'exact', sourceKey: 'target-key');
      final competing = localMeeting(id: 'competing', sourceKey: 'other-key');

      expect(matcher.matchMeeting(remote, [competing, exact])?.id, 'exact');
    },
  );

  test('rejects duplicate exact source meeting keys as ambiguous', () {
    final remote = importedMeeting(key: 'duplicate-key');

    expect(
      matcher.matchMeeting(remote, [
        localMeeting(id: 'first', sourceKey: 'duplicate-key'),
        localMeeting(id: 'second', sourceKey: 'duplicate-key'),
      ]),
      isNull,
    );
  });

  test('preserves meeting identity when sections or weeks change', () {
    final remote = importedMeeting(
      startSection: 5,
      endSection: 6,
      weeks: WeekMask.fromWeeks([2, 4, 6, 8]),
    );
    final result = matcher.matchMeeting(remote, [localMeeting()]);

    expect(result, isNotNull);
    expect(result?.id, 'local-meeting');
  });

  test('does not guess between same-name courses with equal shape', () {
    final remote = ImportedCourse(
      sourceCourseKey: 'new-key',
      name: '软件测试',
      meetings: [importedMeeting()],
    );
    final first = Course(
      id: 'first',
      semesterId: 'semester',
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'first-key',
      name: '软件测试',
    );
    final second = Course(
      id: 'second',
      semesterId: 'semester',
      sourceType: CourseSourceType.imported,
      sourceCourseKey: 'second-key',
      name: '软件测试',
    );

    expect(
      matcher.matchLocalCourse(
        remote,
        [first, second],
        {
          first.id: [localMeeting(id: 'first-meeting')],
          second.id: [localMeeting(id: 'second-meeting')],
        },
      ),
      isNull,
    );
  });

  test(
    'matches the unique same-name course even after all meetings change',
    () {
      final remote = ImportedCourse(
        sourceCourseKey: 'new-key',
        name: '软件测试',
        meetings: [
          importedMeeting(
            weekday: 5,
            startSection: 9,
            endSection: 10,
            weeks: WeekMask.fromWeeks([9, 11, 13, 15]),
          ),
        ],
      );
      final local = Course(
        id: 'local-course',
        semesterId: 'semester',
        sourceType: CourseSourceType.imported,
        sourceCourseKey: 'old-key',
        name: '软件测试',
      );

      expect(
        matcher.matchLocalCourse(
          remote,
          [local],
          {
            local.id: [localMeeting()],
          },
        ),
        same(local),
      );
    },
  );

  test('uses a one-to-one best assignment for multi-meeting courses', () {
    final remote = [
      importedMeeting(
        key: 'remote-a',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        teacher: '教师甲',
        campus: '长安校区',
        room: '3406',
      ),
      importedMeeting(
        key: 'remote-b',
        weekday: 2,
        startSection: 5,
        endSection: 6,
        teacher: '教师乙',
        campus: '太白校区',
        room: '3508',
      ),
    ];
    final local = [
      localMeeting(
        id: 'shared-candidate',
        sourceKey: 'old-a',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        teacher: '教师乙',
        campus: '长安校区',
        room: '3508',
      ),
      localMeeting(
        id: 'later-only-candidate',
        sourceKey: 'old-b',
        weekday: 3,
        startSection: 9,
        endSection: 10,
        teacher: '教师甲',
        campus: '长安校区',
        room: '3406',
      ),
    ];

    expect(
      ImportIdentityMatcher.courseShapeScore(remote, local),
      greaterThan(200),
    );
  });
}
