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
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/features/calendar/presentation/calendar_page.dart';
import 'package:nwu_schedule/features/home/presentation/home_page.dart';
import 'package:nwu_schedule/features/import/presentation/timetable_import_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/course_detail_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/schedule_page.dart';

void main() {
  final previousComparator = goldenFileComparator;

  setUpAll(() {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.file(
        '${Directory.current.path}${Platform.pathSeparator}'
        'test${Platform.pathSeparator}golden${Platform.pathSeparator}'
        'actual_schedule_pages_golden_test.dart',
      ),
      precisionTolerance: 0.015,
    );
  });

  tearDownAll(() => goldenFileComparator = previousComparator);

  for (final theme in officialThemes) {
    for (final item in _homeCases) {
      testWidgets(
        '${theme.id} Home ${item.id} golden',
        (tester) async {
          final fixture = await _createFixture();
          addTearDown(fixture.dispose);
          await _pumpPage(
            tester,
            fixture,
            theme,
            HomePage(now: item.now),
          );
          await expectLater(
            find.byType(HomePage),
            matchesGoldenFile('goldens/actual/home/${theme.id}_${item.id}.png'),
          );
        },
      );
    }

    testWidgets(
      '${theme.id} actual Week page golden',
      (tester) async {
        final fixture = await _createFixture();
        addTearDown(fixture.dispose);
        await _pumpPage(
          tester,
          fixture,
          theme,
          SchedulePage(now: _fixedMondayMorning),
        );
        await expectLater(
          find.byType(SchedulePage),
          matchesGoldenFile('goldens/actual/pages/${theme.id}_week.png'),
        );
      },
    );

    testWidgets(
      '${theme.id} actual Month page golden',
      (tester) async {
        final fixture = await _createFixture();
        addTearDown(fixture.dispose);
        await _pumpPage(
          tester,
          fixture,
          theme,
          CalendarPage(
            now: _fixedMondayMorning,
            initialMonth: DateTime(2026, 9),
          ),
        );
        await expectLater(
          find.byType(CalendarPage),
          matchesGoldenFile('goldens/actual/pages/${theme.id}_month.png'),
        );
      },
    );

    testWidgets(
      '${theme.id} actual Course Detail page golden',
      (tester) async {
        final fixture = await _createFixture();
        addTearDown(fixture.dispose);
        await _pumpPage(
          tester,
          fixture,
          theme,
          const CourseDetailPage(courseId: 'golden-course'),
        );
        await expectLater(
          find.byType(CourseDetailPage),
          matchesGoldenFile(
              'goldens/actual/pages/${theme.id}_course_detail.png'),
        );
      },
    );

    testWidgets(
      '${theme.id} actual Diff golden',
      (tester) async {
        final fixture = await _createFixture();
        addTearDown(fixture.dispose);
        final timetable = _diffTimetable();
        final diff = ImportDiff([
          ImportChange(
            kind: ImportChangeKind.added,
            sourceCourseKey: 'new-course',
            remoteCourse: timetable.courses.single,
          ),
          ImportChange(
            kind: ImportChangeKind.removed,
            sourceCourseKey: 'old-course',
            localCourse: fixture.course,
          ),
          ImportChange(
            kind: ImportChangeKind.conflict,
            sourceCourseKey: 'golden-course',
            localCourse: fixture.course,
            remoteCourse: timetable.courses.single,
            fields: [
              const ImportFieldChange(
                field: 'room',
                decision: MergeDecision.conflict,
                localValue: '3406',
                remoteValue: '3508',
              ),
            ],
          ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TimetableImportPreviewCard(
                  timetable: timetable,
                  diff: diff,
                  saving: false,
                  hasConflictItems: true,
                  onConfirm: () {},
                  onRetry: () {},
                  onCancel: () {},
                  onResolveConflicts: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(TimetableImportPreviewCard),
          matchesGoldenFile('goldens/actual/pages/${theme.id}_diff.png'),
        );
      },
    );
  }
}

final _fixedMondayMorning = DateTime.utc(2026, 9, 7, 2);

final _homeCases = [
  (id: 'now', now: DateTime.utc(2026, 9, 7, 2, 30)),
  (id: 'next', now: DateTime.utc(2026, 9, 7, 1)),
  (id: 'done', now: DateTime.utc(2026, 9, 7, 10)),
  (id: 'no_class', now: DateTime.utc(2026, 9, 8, 1)),
];

Future<void> _pumpPage(
  WidgetTester tester,
  _GoldenFixture fixture,
  ScheduleThemeDefinition theme,
  Widget page,
) async {
  tester.view.physicalSize = const Size(480, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(fixture.database),
        scheduleLoadProvider.overrideWith(
          (ref) => Stream.value(fixture.ready),
        ),
        scheduleDisplayPreferencesProvider.overrideWith(
          (ref) async => const ScheduleDisplayPreferences.defaults(),
        ),
      ],
      child: MaterialApp(
        theme: theme.light(),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<_GoldenFixture> _createFixture() async {
  final database = AppDatabase(NativeDatabase.memory());
  final repository = DriftScheduleDataRepository(database);
  final week1 = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: 'golden-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: week1,
    week1StartDate: week1,
    semesterEndDate: week1.add(const Duration(days: 20 * 7 - 1)),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: const [],
  );
  final semester = Semester(
    id: 'golden-semester',
    academicYear: calendar.academicYear,
    term: SemesterTerm.first,
    label: '2026-2027 第一学期',
    calendarId: calendar.id,
    calendarRevision: calendar.revision,
    createdAt: week1,
  );
  final course = Course(
    id: 'golden-course',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '软件测试',
    code: 'CS301',
    teachingClass: '软件工程2401',
    credits: 2,
    assessment: '考查',
    note: 'Golden fixture',
    createdAt: week1,
    updatedAt: week1,
  );
  final rules = [
    MeetingRule(
      id: 'golden-rule-monday',
      courseId: course.id,
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
      teacher: '教师甲',
      campus: '长安校区',
      room: '3406',
      weekMask: WeekMask.all(calendar.totalWeeks),
    ),
    MeetingRule(
      id: 'golden-rule-thursday',
      courseId: course.id,
      weekday: DateTime.thursday,
      startSection: 5,
      endSection: 6,
      teacher: '教师乙',
      campus: '太白校区',
      room: '1310',
      weekMask: WeekMask.all(calendar.totalWeeks),
    ),
  ];
  await repository.saveSemester(semester);
  await repository.saveCourse(course, rules);
  final snapshot = await repository.loadSemester(semester.id);
  final engine = ScheduleEngine(
    semesterId: semester.id,
    calendarEngine: CalendarEngine(calendar),
    courses: snapshot.courses,
    meetingRules: snapshot.meetingRules,
    exceptions: snapshot.exceptions,
  );
  return _GoldenFixture(
    database: database,
    course: course,
    ready: ScheduleReady(semester: semester, engine: engine),
  );
}

RemoteTimetable _diffTimetable() {
  return RemoteTimetable(
    semester: const RemoteSemester(
      remoteTermKey: '2026-2027-1',
      academicYear: '2026-2027',
      term: 1,
      label: '2026-2027 第一学期',
    ),
    totalWeeks: 20,
    courses: [
      ImportedCourse(
        sourceCourseKey: 'new-course',
        name: '软件测试',
        code: 'CS301',
        teachingClass: '软件工程2401',
        credits: 2,
        assessment: '考查',
        meetings: [
          ImportedMeeting(
            sourceMeetingKey: 'new-meeting',
            weekday: DateTime.monday,
            startSection: 3,
            endSection: 4,
            teacher: '教师甲',
            campus: '长安校区',
            room: '3508',
            weekMask: WeekMask.all(20),
          ),
        ],
      ),
    ],
  );
}

class _GoldenFixture {
  const _GoldenFixture({
    required this.database,
    required this.course,
    required this.ready,
  });

  final AppDatabase database;
  final Course course;
  final ScheduleReady ready;

  Future<void> dispose() => database.close();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    // The month grid is denser than the other real pages. Its date labels
    // produce a stable 1.50%–1.51% Windows/Linux font-rasterization delta,
    // so allow a narrowly larger tolerance for month goldens only.
    final tolerance = golden.pathSegments.last.endsWith('_month.png')
        ? 0.016
        : _precisionTolerance;
    final passed = result.passed || result.diffPercent <= tolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
