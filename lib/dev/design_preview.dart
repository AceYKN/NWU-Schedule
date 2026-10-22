/// Local visual review entry point using the production router and pages.
///
/// flutter build apk --debug -t lib/dev/design_preview.dart
///   --android-project-arg=nwuDesignPreview=true
///
/// The separate Android package and in-memory database keep the installed
/// application and its saved courses untouched. Sample data is never imported
/// into the normal application's database.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap.dart';
import '../app/app.dart';
import '../app/router.dart';
import '../app/theme/schedule_theme.dart';
import '../app/theme/campus_design.dart';
import '../core/utils/week_mask.dart';
import '../data/database/app_database.dart' show AppDatabase;
import '../data/repositories/drift_schedule_data_repository.dart';
import '../domain/calendar/calendar_definition.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/course/course.dart';
import '../domain/course/meeting_rule.dart';
import '../domain/schedule/schedule_engine.dart';
import '../domain/semester/semester.dart';
import '../infrastructure/calendar/bundled_calendar_repository.dart';

class _PreviewCalendarRepository extends BundledCalendarRepository {
  const _PreviewCalendarRepository(this.calendar);

  final CalendarDefinition calendar;

  @override
  Future<CalendarDefinition?> findById(String id) async =>
      id == calendar.id ? calendar : super.findById(id);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(NativeDatabase.memory());
  final repository = DriftScheduleDataRepository(database);
  final week1 = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: 'design-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: week1,
    week1StartDate: week1,
    semesterEndDate: DateTime(2027, 1, 24),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: const [],
  );
  final semester = Semester(
    id: 'design-semester',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '2026–2027 第一学期',
    calendarId: calendar.id,
    calendarRevision: 1,
    createdAt: week1,
  );
  await repository.saveSemester(semester);
  final samples = [
    (
      name: '软件测试',
      room: '3406',
      teacher: '教师甲',
      slots: [(1, 3, 4), (4, 5, 6)],
    ),
    (
      name: '计算机网络',
      room: '3208',
      teacher: '教师乙',
      slots: [(1, 5, 6), (3, 1, 2)],
    ),
    (
      name: '机器学习实习（双语）',
      room: '实验室-321',
      teacher: '教师丙',
      slots: [(1, 7, 8), (5, 5, 6)],
    ),
    (
      name: '数据库系统',
      room: '3302',
      teacher: '教师丁',
      slots: [(2, 1, 2), (4, 3, 4)],
    ),
    (
      name: '操作系统',
      room: '3402',
      teacher: '教师戊',
      slots: [(2, 5, 6), (5, 1, 2)],
    ),
    (
      name: '编译原理',
      room: '3106',
      teacher: '教师己',
      slots: [(3, 5, 6), (4, 7, 8)],
    ),
  ];
  for (var index = 0; index < samples.length; index++) {
    final sample = samples[index];
    final course = Course(
      id: 'design-course-$index',
      semesterId: semester.id,
      sourceType: CourseSourceType.manual,
      name: sample.name,
      createdAt: week1,
      updatedAt: week1,
    );
    await repository.saveCourse(course, [
      for (var slot = 0; slot < sample.slots.length; slot++)
        MeetingRule(
          id: 'design-rule-$index-$slot',
          courseId: course.id,
          weekday: sample.slots[slot].$1,
          startSection: sample.slots[slot].$2,
          endSection: sample.slots[slot].$3,
          teacher: sample.teacher,
          campus: '长安校区',
          room: sample.room,
          weekMask: WeekMask.all(20),
        ),
    ]);
  }
  final snapshot = await repository.loadSemester(semester.id);
  final engine = ScheduleEngine(
    semesterId: semester.id,
    calendarEngine: CalendarEngine(calendar),
    courses: snapshot.courses,
    meetingRules: snapshot.meetingRules,
    exceptions: snapshot.exceptions,
  );
  final ready = ScheduleReady(semester: semester, engine: engine);
  const dark = bool.fromEnvironment('DESIGN_PREVIEW_DARK');
  final theme = officialThemes.first;
  await repository.setSetting('appearance.themeMode', dark ? 'dark' : 'light');
  await repository.setSetting(
      scheduleDisplaySettingKeys['showCampus']!, 'false');
  await repository.setSetting(
      scheduleDisplaySettingKeys['showTeacher']!, 'false');
  final design = CampusDesign.preview(dark: dark);
  final router = createAppRouter(now: DateTime.utc(2026, 10, 19, 1, 41));
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: design.paper,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
  ));
  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      scheduleDataRepositoryProvider.overrideWithValue(repository),
      bundledCalendarRepositoryProvider
          .overrideWithValue(_PreviewCalendarRepository(calendar)),
      scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
    ],
    child: NwuScheduleApp(
      router: router,
      theme: CampusDesign.preview().applyTo(theme.light()),
      darkTheme: CampusDesign.preview(dark: true).applyTo(theme.dark()),
      locale: const Locale('ja', 'JP'),
    ),
  ));
}
