import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/features/settings/presentation/schedule_display_settings_page.dart';
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

  testWidgets('restoring a hidden course can be undone', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    const hiddenKey = 'schedule.weekView.hiddenCourseIds';
    await repository.setSetting(hiddenKey, '["course-1"]');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          scheduleDisplayPreferencesProvider.overrideWith(
            (ref) async => const ScheduleDisplayPreferences.defaults()
                .copyWith(hiddenCourseIds: {'course-1'}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ScheduleDisplaySettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('已隐藏课程'), findsOneWidget);
    await tester.tap(find.text('显示'));
    await tester.pumpAndSettle();

    expect(
        decodeHiddenCourseIds(await repository.getSetting(hiddenKey)), isEmpty);
    expect(find.text('已恢复“course-1”'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(
      decodeHiddenCourseIds(await repository.getSetting(hiddenKey)),
      {'course-1'},
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
