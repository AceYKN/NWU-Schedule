import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/campus_clock.dart';
import '../core/utils/date_utils.dart';
import '../data/database/app_database.dart' show AppDatabase;
import '../data/repositories/drift_schedule_data_repository.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/schedule/schedule_data_repository.dart';
import '../domain/schedule/schedule_engine.dart';
import '../domain/semester/semester.dart';
import '../domain/semester/semester_selector.dart';
import '../infrastructure/calendar/bundled_calendar_repository.dart';

sealed class ScheduleLoadState {
  const ScheduleLoadState();
}

final class ScheduleNoSemester extends ScheduleLoadState {
  const ScheduleNoSemester();
}

final class ScheduleCalendarMissing extends ScheduleLoadState {
  const ScheduleCalendarMissing(this.semester);

  final Semester semester;
}

final class ScheduleReady extends ScheduleLoadState {
  const ScheduleReady({required this.semester, required this.engine});

  final Semester semester;
  final ScheduleEngine engine;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(() => database.close());
  return database;
});

final scheduleDataRepositoryProvider = Provider<ScheduleDataRepository>((ref) {
  return DriftScheduleDataRepository(ref.watch(appDatabaseProvider));
});

final bundledCalendarRepositoryProvider = Provider<BundledCalendarRepository>(
  (ref) => const BundledCalendarRepository(),
);

final scheduleLoadProvider = StreamProvider<ScheduleLoadState>((ref) {
  final today = dateOnly(CampusClock.now());
  final nextMidnightUtc = CampusClock.campusWallTimeToUtc(
    today.add(const Duration(days: 1)),
  );
  final midnightTimer = Timer(
    nextMidnightUtc.difference(DateTime.now().toUtc()) +
        const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(midnightTimer.cancel);
  final repository = ref.watch(scheduleDataRepositoryProvider);
  final calendars = ref.watch(bundledCalendarRepositoryProvider);
  return repository.watchChanges().asyncMap((_) async {
    final semesters = await repository.loadSemesters();
    if (semesters.isEmpty) return const ScheduleNoSemester();

    final preferred = await repository.getPreferredSemesterId();
    final preferredSelectedAt =
        await repository.getPreferredSemesterSelectedAt();
    final selected = await selectSemester(
      semesters: semesters,
      preferredId: preferred,
      preferredSelectedAt: preferredSelectedAt,
      calendarById: calendars.findById,
      today: CampusClock.now(),
    );
    final calendarId = selected.calendarId;
    final definition =
        calendarId == null ? null : await calendars.findById(calendarId);
    if (definition == null) return ScheduleCalendarMissing(selected);

    final data = await repository.loadSemester(selected.id);
    return ScheduleReady(
      semester: selected,
      engine: ScheduleEngine(
        semesterId: selected.id,
        calendarEngine: CalendarEngine(definition),
        courses: data.courses,
        meetingRules: data.meetingRules,
        exceptions: data.exceptions,
      ),
    );
  });
});
