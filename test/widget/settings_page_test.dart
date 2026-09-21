import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/features/settings/presentation/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'permission denial disables stale reminder setting and clears alarms',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftScheduleDataRepository(database);
      await repository.setSetting('notifications.enabled', 'true');

      const channel = MethodChannel('nwu_schedule/notifications');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'requestPermission' ? false : null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(
            home: Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      tile.onChanged!(true);
      await tester.pumpAndSettle();

      expect(await repository.getSetting('notifications.enabled'), 'false');
      expect(calls, ['requestPermission', 'clearNotifications']);
      expect(find.text('未获得通知权限，提醒未开启'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
