import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/campus_clock.dart';
import '../core/utils/date_utils.dart';
import '../data/database/app_database.dart' show AppDatabase;
import '../data/repositories/drift_schedule_data_repository.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/notification/notification_planner.dart';
import '../domain/schedule/schedule_data_repository.dart';
import '../domain/schedule/schedule_engine.dart';
import '../domain/semester/semester.dart';
import '../domain/semester/semester_selector.dart';
import '../domain/widget/widget_snapshot.dart';
import '../infrastructure/calendar/bundled_calendar_repository.dart';
import '../infrastructure/notifications/notification_service.dart';
import '../infrastructure/widget/widget_service.dart';
import 'theme/schedule_theme.dart';

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
  const ScheduleReady({
    required this.semester,
    required this.engine,
    this.calendarUpdated = false,
  });

  final Semester semester;
  final ScheduleEngine engine;
  final bool calendarUpdated;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(() => database.close());
  return database;
});

final scheduleDataRepositoryProvider = Provider<ScheduleDataRepository>((ref) {
  return DriftScheduleDataRepository(ref.watch(appDatabaseProvider));
});

const notificationDefaultLeadMinutes = 15;

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const NotificationService(),
);

final widgetServiceProvider = Provider<WidgetService>(
  (ref) => const WidgetService(),
);

final notificationEnabledProvider = FutureProvider<bool>((ref) async {
  final value = await ref
      .watch(scheduleDataRepositoryProvider)
      .getSetting('notifications.enabled');
  return value == 'true';
});

final notificationLeadMinutesProvider = FutureProvider<int>((ref) async {
  final value = await ref
      .watch(scheduleDataRepositoryProvider)
      .getSetting('notifications.leadMinutes');
  final parsed = int.tryParse(value ?? '');
  return const [5, 10, 15, 20, 30, 60].contains(parsed)
      ? parsed!
      : notificationDefaultLeadMinutes;
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final value = await ref
      .watch(scheduleDataRepositoryProvider)
      .getSetting('onboarding.completed');
  return value == 'true';
});

final themeIdProvider = FutureProvider<String>((ref) async {
  final value = await ref
      .watch(scheduleDataRepositoryProvider)
      .getSetting('appearance.themeId');
  if (officialThemes.any((theme) => theme.id == value)) return value!;
  return officialThemes.first.id;
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

    final calendarUpdated = selected.calendarRevision != null &&
        selected.calendarRevision != definition.revision;
    if (selected.calendarRevision == null) {
      // Existing databases created before revision tracking are initialized
      // silently. A real later revision change remains visible until the user
      // dismisses the non-blocking notice in Home.
      unawaited(
        repository.saveSemester(
          selected.copyWith(calendarRevision: definition.revision),
        ),
      );
    }

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
      calendarUpdated: calendarUpdated,
    );
  });
});

final notificationCoordinatorProvider = Provider<void>((ref) {
  ref.listen(scheduleLoadProvider, (_, next) {
    if (next.hasValue) {
      unawaited(
        rebuildNotificationsForCurrentSchedule(
          repository: ref.read(scheduleDataRepositoryProvider),
          service: ref.read(notificationServiceProvider),
          state: ref.read(scheduleLoadProvider).asData?.value,
        ),
      );
    }
  });
});

final widgetCoordinatorProvider = Provider<void>((ref) {
  ref.listen(scheduleLoadProvider, (_, next) {
    if (next.hasValue) {
      unawaited(
        rebuildWidgetForCurrentSchedule(
          service: ref.read(widgetServiceProvider),
          state: ref.read(scheduleLoadProvider).asData?.value,
        ),
      );
    }
  });
});

Future<void> rebuildWidgetForCurrentSchedule({
  required WidgetService service,
  required ScheduleLoadState? state,
}) async {
  if (state is! ScheduleReady) {
    await service.clear();
    return;
  }
  final snapshot = const WidgetSnapshotBuilder().build(
    engine: state.engine,
    now: DateTime.now().toUtc(),
  );
  await service.publish(snapshot);
}

Future<void> rebuildNotificationsForCurrentSchedule({
  required ScheduleDataRepository repository,
  required NotificationService service,
  required ScheduleLoadState? state,
}) async {
  final enabled = await repository.getSetting('notifications.enabled');
  if (enabled != 'true') {
    // Restoring a backup or clearing settings can disable reminders while
    // alarms from the previous dataset are still scheduled on Android.
    await service.clear();
    return;
  }
  if (state is! ScheduleReady) {
    await service.clear();
    return;
  }
  final rawLead = await repository.getSetting('notifications.leadMinutes');
  final parsedLead = int.tryParse(rawLead ?? '');
  final leadMinutes = const [5, 10, 15, 20, 30, 60].contains(parsedLead)
      ? parsedLead!
      : notificationDefaultLeadMinutes;
  final plan = const NotificationPlanner().build(
    engine: state.engine,
    now: DateTime.now().toUtc(),
    leadMinutes: leadMinutes,
  );
  await service.rebuild(plan);
}
