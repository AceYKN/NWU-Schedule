import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/infrastructure/notifications/notification_service.dart';
import 'package:nwu_schedule/infrastructure/widget/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
