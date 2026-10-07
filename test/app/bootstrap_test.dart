import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/core/utils/latest_task_queue.dart';
import 'package:nwu_schedule/infrastructure/notifications/notification_service.dart';
import 'package:nwu_schedule/infrastructure/widget/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a stale settings read cannot publish after a newer synchronization',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _DelayedSettingsRepository(database);
    const channel = MethodChannel('nwu_schedule/notifications');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final queue = LatestTaskQueue<ScheduleLoadState?>((state, isCurrent) {
      return rebuildNotificationsForCurrentSchedule(
        repository: repository,
        service: const NotificationService(),
        state: state,
        isCurrent: isCurrent,
      );
    });
    addTearDown(queue.dispose);
    final old = queue.schedule(null);
    await repository.started.future;
    final newer = queue.schedule(const ScheduleNoSemester());
    repository.release.complete();
    await Future.wait([old, newer]);
    expect(calls, ['clearNotifications']);
  });

  test('clears old platform alarms when reminders are disabled', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    await repository.setSetting('notifications.enabled', 'false');

    const channel = MethodChannel('nwu_schedule/notifications');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await rebuildNotificationsForCurrentSchedule(
      repository: repository,
      service: const NotificationService(),
      state: null,
    );

    expect(calls, ['clearNotifications']);
  });

  test('clears the native widget snapshot when no schedule is available',
      () async {
    const channel = MethodChannel('nwu_schedule/widget');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await rebuildWidgetForCurrentSchedule(
      service: const WidgetService(),
      state: null,
    );

    expect(calls, ['clearSnapshot']);
  });
}

class _DelayedSettingsRepository extends DriftScheduleDataRepository {
  _DelayedSettingsRepository(super.database);

  final started = Completer<void>();
  final release = Completer<void>();
  bool firstRead = true;

  @override
  Future<String?> getSetting(String key) async {
    if (firstRead) {
      firstRead = false;
      started.complete();
      await release.future;
    }
    return 'false';
  }
}
