import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(software.code, 'CS301');
    expect(software.meetings.single.room, '3508');
    expect(software.meetings.single.weekMask.weeks.length, 16);

    final network = timetable.courses.last;
    expect(network.name, '计算机网络');
    expect(network.teachingClass, '软件工程2401');
    expect(network.meetings.single.teacher, '李老师');
    expect(network.meetings.single.weekMask.weeks, [2, 4, 6, 8]);
    expect(network.meetings.single.startSection, 5);
    expect(network.meetings.single.endSection, 6);
  });

  test('preserves parser warnings for rows skipped by the DOM fallback', () {
    final timetable = const TimetableImportParser().parse({
      ...fixture,
      'issues': [
        {
          'path': 'tables[0].rows[3].sections',
          'message': '节次无法识别，已跳过该行',
          'severity': 'warning',
        },
      ],
    });

    final report = validateTimetable(timetable);
    expect(timetable.issues, hasLength(1));
    expect(report.isValid, isTrue);
    expect(report.warningCount, 1);

    final restored = const TimetableImportParser().parse(timetable.toJson());
    expect(restored.issues.single.path, 'tables[0].rows[3].sections');
    expect(restored.issues.single.message, '节次无法识别，已跳过该行');
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

  test('parser does not silently accept a missing course list', () {
    expect(
      () => const TimetableImportParser().parse({
        'semester': fixture['semester'],
      }),
      throwsFormatException,
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
