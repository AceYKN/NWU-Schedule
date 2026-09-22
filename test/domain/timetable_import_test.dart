import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = jsonDecode(File(
      'test/fixtures/zhengfang/timetable_response.json',
    ).readAsStringSync()) as Map<String, dynamic>;
  });

  test('normalizes canonical and Zhengfang-style field names', () {
    final timetable = const TimetableImportParser().parse(fixture);
    expect(timetable.semester.id, 'nwu-2026-2027-1');
    expect(timetable.courses, hasLength(2));

    final software = timetable.courses.first;
    expect(software.name, '软件测试');
    expect(software.meetings.single.room, '3508');
    expect(software.meetings.single.weekMask.weeks.length, 16);

    final network = timetable.courses.last;
    expect(network.name, '计算机网络');
    expect(network.meetings.single.teacher, '李老师');
    expect(network.meetings.single.weekMask.weeks, [2, 4, 6, 8]);
    expect(network.meetings.single.startSection, 5);
    expect(network.meetings.single.endSection, 6);
  });

  test('strips imported teacher campus and room labels defensively', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        {
          'sourceCourseKey': 'labeled-fields',
          'name': '软件测试',
          'meetings': [
            {
              'sourceMeetingKey': 'labeled-fields-meeting',
              'weekday': 1,
              'startSection': 3,
              'endSection': 4,
              'weekText': '1-18周',
              'teacher': '教师：  杨建锋',
              'campus': '校区:长安校区',
              'room': '上课地点：1405',
            },
          ],
        },
      ],
    });

    final meeting = timetable.courses.single.meetings.single;
    expect(meeting.teacher, '杨建锋');
    expect(meeting.campus, '长安校区');
    expect(meeting.room, '1405');
  });

  test('ignores explicitly marked self-study courses', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        ...(fixture['courses'] as List<Object?>),
        {
          'sourceCourseKey': 'self-study',
          'name': '[自修]自修课程',
          'meetings': [
            {
              'sourceMeetingKey': 'self-study-meeting',
              'weekday': 1,
              'startSection': 1,
              'endSection': 2,
              'weekText': '1-18周',
            },
          ],
        },
      ],
    });

    expect(timetable.courses, hasLength(2));
    expect(
        timetable.courses.any((course) => course.name.contains('自修')), isFalse);
    expect(timetable.ignoredSelfStudyCourseCount, 1);
    expect(validateTimetable(timetable).isValid, isTrue);

    final restored = const TimetableImportParser().parse(timetable.toJson());
    expect(restored.ignoredSelfStudyCourseCount, 1);
    expect(restored.courses, hasLength(2));

    final onlySelfStudy = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        {
          'sourceCourseKey': 'only-self-study',
          'name': '自修',
          'meetings': [
            {
              'sourceMeetingKey': 'only-self-study-meeting',
              'weekday': 2,
              'startSection': 3,
              'endSection': 4,
              'weekText': '1-18周',
            },
          ],
        },
      ],
    });
    expect(onlySelfStudy.courses, isEmpty);
    expect(onlySelfStudy.ignoredSelfStudyCourseCount, 1);
    expect(validateTimetable(onlySelfStudy).isValid, isTrue);
  });

  test('preserves parser errors for rows skipped by the DOM fallback', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'issues': [
        {
          'path': 'tables[0].rows[3].sections',
          'message': '节次无法识别，已跳过该行',
          'severity': 'error',
        },
      ],
    });

    final report = validateTimetable(timetable);
    expect(timetable.issues, hasLength(1));
    expect(report.isValid, isFalse);
    expect(report.errorCount, 1);
    expect(report.warningCount, 0);

    final restored = const TimetableImportParser().parse(timetable.toJson());
    expect(restored.issues.single.path, 'tables[0].rows[3].sections');
    expect(restored.issues.single.message, '节次无法识别，已跳过该行');
  });

  test('round-trips safe structural details on import issues', () {
    const original = ImportIssue(
      path: 'tables[0].rows[2].weeks',
      message: '周次格式无效，已跳过该行',
      severity: ImportIssueSeverity.error,
      details: {
        'tableId': 'kblist_table',
        'tableIndex': 0,
        'rowIndex': 2,
        'courseIndex': 1,
        'rowCount': 9,
        'columnCount': 8,
        'rawLength': 3,
        'rawShape': 'mixed',
        'parsedNumbers': [321],
        'unexpectedCharacterClasses': ['han'],
        'unexpectedCharacterCount': 2,
      },
    );
    final restored = ImportIssue.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.details['tableId'], 'kblist_table');
    expect(restored.details['courseIndex'], 1);
    expect(restored.details['rowCount'], 9);
    expect(restored.details['rawShape'], 'mixed');
    expect(restored.details['parsedNumbers'], [321]);
    expect(restored.details['unexpectedCharacterClasses'], ['han']);
    expect(restored.details['unexpectedCharacterCount'], 2);
    expect(restored.toString(), contains('parsedNumbers=[321]'));
    expect(
      const ImportIssue(
        path: 'tables[0].rows[2].weeks',
        message: '周次格式无效',
        severity: ImportIssueSeverity.error,
        details: {
          'courseName': '不得输出',
          'parsedNumbers': [321]
        },
      ).toString(),
      isNot(contains('不得输出')),
    );
    final details = const ImportIssue(
      path: 'tables[0].rows[2].weeks',
      message: '周次格式无效',
      severity: ImportIssueSeverity.error,
      details: {
        'courseName': '不得输出',
        'parsedNumbers': [321]
      },
    ).toJson()['details'] as Map;
    expect(details.containsKey('courseName'), isFalse);
    expect(details['parsedNumbers'], [321]);
  });

  test('validates empty IDs, bad weekday, section and duplicate rules', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        {
          'sourceCourseKey': 'same',
          'name': '课程 A',
          'meetings': [
            {
              'sourceMeetingKey': 'same-meeting',
              'weekday': 8,
              'startSection': 4,
              'endSection': 2,
              'weekText': '1-30周',
            },
            {
              'sourceMeetingKey': 'same-meeting',
              'weekday': 1,
              'startSection': 1,
              'endSection': 2,
              'weekText': '1周',
            },
          ],
        },
        {
          'sourceCourseKey': 'same',
          'name': '课程 B',
          'meetings': [],
        },
      ],
    });
    final report = validateTimetable(timetable);
    expect(report.isValid, isFalse);
    expect(report.errorCount, greaterThanOrEqualTo(4));
    expect(
        report.issues.any((issue) => issue.path.contains('weekday')), isTrue);
    expect(report.issues.any((issue) => issue.message.contains('重复')), isTrue);
  });

  test('rejects a course with no meetings before destructive import', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        {
          'sourceCourseKey': 'empty-meetings',
          'name': '课程 A',
          'meetings': <Object?>[],
        },
      ],
    });

    final report = validateTimetable(timetable);

    expect(report.isValid, isFalse);
    expect(report.errorCount, 1);
    expect(report.issues.single.path, 'courses[0].meetings');
    expect(report.issues.single.severity, ImportIssueSeverity.error);
  });

  test('rejects blank identity fields and duplicate meeting structures', () {
    final timetable = RemoteTimetable(
      semester: const RemoteSemester(
        remoteTermKey: ' ',
        academicYear: '2026-2027',
        term: 1,
        label: ' ',
      ),
      totalWeeks: 20,
      courses: [
        ImportedCourse(
          sourceCourseKey: ' ',
          name: '重复安排课程',
          meetings: [
            ImportedMeeting(
              sourceMeetingKey: 'meeting-a',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: '教师甲',
              campus: '长安校区',
              room: '101',
              weekMask: WeekMask.all(20),
            ),
            ImportedMeeting(
              sourceMeetingKey: 'meeting-b',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              teacher: '教师甲',
              campus: '长安校区',
              room: '101',
              weekMask: WeekMask.all(20),
            ),
          ],
        ),
      ],
    );

    final report = validateTimetable(timetable);
    expect(report.isValid, isFalse);
    expect(
      report.issues.map((issue) => issue.path),
      containsAll([
        'semester.remoteTermKey',
        'semester.label',
        'courses[0].sourceCourseKey',
        'courses[0].meetings[1]',
      ]),
    );
    expect(
      report.issues.any((issue) => issue.message.contains('完全重复')),
      isTrue,
    );
  });

  test('does not clamp invalid total weeks or accept an empty timetable', () {
    final tooManyWeeks = const TimetableImportParser().parse({
      ...fixture,
      'semester': {
        ...(fixture['semester'] as Map<String, dynamic>),
        'totalWeeks': 65,
      },
      'totalWeeks': 65,
    });
    expect(tooManyWeeks.totalWeeks, 65);
    expect(validateTimetable(tooManyWeeks).isValid, isFalse);

    final empty = const TimetableImportParser().parse({
      ...fixture,
      'courses': <Object?>[],
    });
    expect(validateTimetable(empty).isValid, isFalse);
  });

  test('rejects numeric week masks that bypass text parsing', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'courses': [
        {
          'sourceCourseKey': 'numeric-mask',
          'name': '软件测试',
          'meetings': [
            {
              'sourceMeetingKey': 'numeric-mask-meeting',
              'weekday': 1,
              'startSection': 1,
              'endSection': 2,
              'weekMask': 0,
            },
          ],
        },
      ],
    });

    final report = validateTimetable(timetable);
    expect(report.isValid, isFalse);
    expect(
      report.issues.any((issue) => issue.path.endsWith('.weekMask')),
      isTrue,
    );
  });

  test('rejects non-integral numeric scalar fields', () {
    expect(
      () => const TimetableImportParser().parse({
        ...fixture,
        'semester': {
          ...(fixture['semester'] as Map<String, dynamic>),
          'totalWeeks': 20.5,
        },
      }),
      throwsFormatException,
    );
    expect(
      () => const TimetableImportParser().parse({
        ...fixture,
        'courses': [
          {
            'sourceCourseKey': 'fractional-mask',
            'name': '软件测试',
            'meetings': [
              {
                'sourceMeetingKey': 'fractional-mask-meeting',
                'weekday': 1,
                'startSection': 1,
                'endSection': 2,
                'weekMask': 1.5,
              },
            ],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('parser does not silently accept a missing course list', () {
    expect(
      () => const TimetableImportParser().parse({
        'semester': fixture['semester'],
      }),
      throwsFormatException,
    );
  });

  test('reports the exact week field when a DOM row has an invalid week', () {
    expect(
      () => const TimetableImportParser().parse({
        ...fixture,
        'courses': [
          {
            'sourceCourseKey': 'room-regression',
            'name': '软件测试',
            'meetings': [
              {
                'sourceMeetingKey': 'room-regression-meeting',
                'weekday': 1,
                'startSection': 1,
                'endSection': 2,
                'weekText': '321',
              },
            ],
          },
        ],
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('courses[0].meetings[0].weekText'),
            contains('raw="321"'),
            contains('Teaching week out of range: 321'),
          ),
        ),
      ),
    );
  });

  test('round-trips canonical week masks from an import snapshot', () {
    final original = const TimetableImportParser().parse(fixture);
    final restored = const TimetableImportParser().parse(original.toJson());

    expect(
      restored.courses.first.meetings.single.weekMask.value,
      original.courses.first.meetings.single.weekMask.value,
    );
    expect(
      restored.courses.last.meetings.single.weekMask.value,
      original.courses.last.meetings.single.weekMask.value,
    );
    expect(
      restored.courses.first.meetings.single.weekMask.rawText,
      original.courses.first.meetings.single.weekMask.rawText,
    );
  });
}
