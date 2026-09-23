import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart' show AppDatabase;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/schedule/presentation/schedule_page.dart';

void main() {
  final previousComparator = goldenFileComparator;

  setUpAll(() {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.file(
        '${Directory.current.path}${Platform.pathSeparator}'
        'test${Platform.pathSeparator}golden${Platform.pathSeparator}'
        'schedule_week_view_golden_test.dart',
      ),
      precisionTolerance: .02,
    );
  });

  tearDownAll(() => goldenFileComparator = previousComparator);

  const sizes = {
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
    '430x932': Size(430, 932),
  };
  final scenarios = [
    for (final entry in sizes.entries)
      _WeekGoldenScenario(
        label: entry.key,
        size: entry.value,
        showWeekend: false,
      ),
    for (final entry in sizes.entries.where((entry) => entry.key != '430x932'))
      _WeekGoldenScenario(
        label: '${entry.key}_7days',
        size: entry.value,
        showWeekend: true,
      ),
  ];

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final scenario in scenarios) {
      testWidgets(
        'week view ${scenario.label} ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = scenario.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final fixture = await _createFixture();
          addTearDown(fixture.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(fixture.database),
                scheduleLoadProvider.overrideWith(
                  (ref) => Stream.value(fixture.ready),
                ),
                scheduleDisplayPreferencesProvider.overrideWith(
                  (ref) async => const ScheduleDisplayPreferences.defaults()
                      .copyWith(showWeekend: scenario.showWeekend),
                ),
              ],
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? officialThemes.first.light()
                    : officialThemes.first.dark(),
                home: SchedulePage(now: _fixedNow),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(SchedulePage),
            matchesGoldenFile(
              'goldens/actual/pages/week_${scenario.label}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }
}

final _fixedNow = DateTime.utc(2026, 9, 11, 2, 30);

Future<_WeekFixture> _createFixture() async {
  final database = AppDatabase(NativeDatabase.memory());
  final repository = DriftScheduleDataRepository(database);
  final week1 = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: 'week-golden-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: week1,
    week1StartDate: week1,
    semesterEndDate: week1.add(const Duration(days: 20 * 7 - 1)),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: [
      CalendarDateOverride(
        date: DateTime(2026, 9, 8),
        type: CalendarOverrideType.holiday,
        label: '校历假日',
      ),
      CalendarDateOverride(
        date: DateTime(2026, 9, 11),
        type: CalendarOverrideType.useScheduleOf,
        sourceDate: DateTime(2026, 9, 13),
        label: '工作日调休',
      ),
      CalendarDateOverride(
        date: DateTime(2026, 9, 12),
        type: CalendarOverrideType.useScheduleOf,
        sourceDate: DateTime(2026, 9, 10),
        label: '周末补课',
      ),
    ],
  );
  final semester = Semester(
    id: 'week-golden-semester',
    academicYear: calendar.academicYear,
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    calendarId: calendar.id,
    calendarRevision: calendar.revision,
    createdAt: week1,
  );
  final course = Course(
    id: 'week-golden-course',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '计算机网络',
  );
  final weekendCourse = Course(
    id: 'week-golden-weekend-course',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '机器学习实验（双语）',
  );
  await repository.saveSemester(semester);
  await repository.saveCourse(
    course,
    [
      MeetingRule(
        id: 'week-golden-rule',
        courseId: course.id,
        weekday: DateTime.monday,
        startSection: 3,
        endSection: 4,
        teacher: '教师甲',
        campus: '长安校区',
        room: '3406',
        weekMask: WeekMask.all(calendar.totalWeeks),
      ),
    ],
  );
  await repository.saveCourse(
    weekendCourse,
    [
      MeetingRule(
        id: 'week-golden-thursday-rule',
        courseId: weekendCourse.id,
        weekday: DateTime.thursday,
        startSection: 1,
        endSection: 2,
        teacher: '教师乙',
        campus: '太白校区',
        room: '实验室-321',
        weekMask: WeekMask.all(calendar.totalWeeks),
      ),
      MeetingRule(
        id: 'week-golden-sunday-rule',
        courseId: weekendCourse.id,
        weekday: DateTime.sunday,
        startSection: 5,
        endSection: 6,
        teacher: '教师乙',
        campus: '太白校区',
        room: '实验室-321',
        weekMask: WeekMask.all(calendar.totalWeeks),
      ),
    ],
  );
  final snapshot = await repository.loadSemester(semester.id);
  return _WeekFixture(
    database: database,
    ready: ScheduleReady(
      semester: semester,
      engine: ScheduleEngine(
        semesterId: semester.id,
        calendarEngine: CalendarEngine(calendar),
        courses: snapshot.courses,
        meetingRules: snapshot.meetingRules,
        exceptions: snapshot.exceptions,
      ),
    ),
  );
}

class _WeekFixture {
  const _WeekFixture({required this.database, required this.ready});

  final AppDatabase database;
  final ScheduleReady ready;

  Future<void> dispose() => database.close();
}

class _WeekGoldenScenario {
  const _WeekGoldenScenario({
    required this.label,
    required this.size,
    required this.showWeekend,
  });

  final String label;
  final Size size;
  final bool showWeekend;
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
