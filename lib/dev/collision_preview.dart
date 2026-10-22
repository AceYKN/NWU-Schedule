/// Isolated Android preview for the save-time collision warning.
///
/// flutter build apk --debug -t lib/dev/collision_preview.dart
///   --android-project-arg=nwuDesignPreview=true
///
/// The separate package and in-memory database contain only sample courses.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/bootstrap.dart';
import '../app/router.dart';
import '../core/utils/week_mask.dart';
import '../data/database/app_database.dart' show AppDatabase;
import '../data/repositories/drift_schedule_data_repository.dart';
import '../domain/calendar/calendar_definition.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/course/course.dart';
import '../domain/course/meeting_rule.dart';
import '../domain/schedule/schedule_engine.dart';
import '../domain/semester/semester.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(NativeDatabase.memory());
  final repository = DriftScheduleDataRepository(database);
  final week1 = DateTime(2026, 9, 7);
  final calendar = CalendarDefinition(
    id: 'collision-preview-calendar',
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
    id: 'collision-preview-semester',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '2026–2027 第一学期',
    calendarId: calendar.id,
    calendarRevision: 1,
    createdAt: week1,
  );
  await repository.saveSemester(semester);
  final existing = Course(
    id: 'preview-existing',
    semesterId: semester.id,
    sourceType: CourseSourceType.manual,
    name: '软件测试',
  );
  await repository.saveCourse(existing, [
    MeetingRule(
      id: 'preview-existing-rule',
      courseId: existing.id,
      weekday: DateTime.monday,
      startSection: 1,
      endSection: 2,
      campus: '长安校区',
      room: '教学楼 301',
      weekMask: WeekMask.all(20),
    ),
  ]);
  final snapshot = await repository.loadSemester(semester.id);
  final ready = ScheduleReady(
    semester: semester,
    engine: ScheduleEngine(
      semesterId: semester.id,
      calendarEngine: CalendarEngine(calendar),
      courses: snapshot.courses,
      meetingRules: snapshot.meetingRules,
      exceptions: snapshot.exceptions,
    ),
  );
  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      scheduleDataRepositoryProvider.overrideWithValue(repository),
      scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
    ],
    child: NwuScheduleApp(
      router: createAppRouter(initialLocation: '/course/new'),
      locale: const Locale('zh', 'CN'),
    ),
  ));
}
