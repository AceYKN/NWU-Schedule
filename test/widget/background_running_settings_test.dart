import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/app.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/router.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/features/settings/presentation/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nwu_schedule/notifications');
  late AppDatabase database;
  late DriftScheduleDataRepository repository;
  late List<String> calls;
  late bool optimized;
  late bool failOpening;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftScheduleDataRepository(database);
    calls = [];
    optimized = false;
    failOpening = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getStatus') {
        return <String, Object?>{
          'systemAllowed': true,
          'channelAllowed': true,
          'batteryOptimizationIgnored': optimized,
        };
      }
      if (call.method == 'requestPermission') return true;
      if (call.method == 'openBatteryOptimizationSettings' && failOpening) {
        throw PlatformException(code: 'settings_unavailable');
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await database.close();
  });

  Future<void> openSettings(WidgetTester tester, {bool realApp = false}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        scheduleLoadProvider.overrideWith(
          (ref) => Stream.value(const ScheduleNoSemester()),
        ),
      ],
      child: realApp
          ? const NwuScheduleApp()
          : const MaterialApp(home: Scaffold(body: SettingsPage())),
    ));
    await tester.pumpAndSettle();
    if (realApp) {
      appRouter.go('/settings');
      await tester.pumpAndSettle();
    }
  }

  Future<void> toggle(WidgetTester tester, bool enabled) async {
    tester
        .widget<SwitchListTile>(find.byType(SwitchListTile))
        .onChanged!(enabled);
    await tester.pumpAndSettle();
  }

  Future<void> closeSettings(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    appRouter.go('/');
  }

  testWidgets('system settings launch and status refresh on resume',
      (tester) async {
    await openSettings(tester, realApp: true);
    final button = find.text('前往设置');
    await tester.scrollUntilVisible(button, 150);
    await tester.pumpAndSettle();
    expect(find.text('电池与后台设置'), findsOneWidget);
    expect(find.text('允许后台运行'), findsNothing);
    expect(find.textContaining('电池优化：未豁免'), findsOneWidget);
    expect(find.textContaining('可减少提醒和小组件更新延迟'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, contains('openBatteryOptimizationSettings'));

    optimized = true;
    final priorReads = calls.where((call) => call == 'getStatus').length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'getStatus').length,
        greaterThan(priorReads));
    expect(find.textContaining('电池优化：已豁免'), findsOneWidget);
    expect(find.textContaining('电池优化：未豁免'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeSettings(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'skipping battery hint keeps reminders enabled and does not repeat',
      (tester) async {
    await openSettings(tester);
    await toggle(tester, true);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('设为“不受限制”或“不优化”')),
        findsOneWidget);
    expect(await repository.getSetting('notifications.enabled'), 'true');
    await tester.tap(find.text('暂时跳过'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('openBatteryOptimizationSettings')));
    await toggle(tester, false);
    await toggle(tester, true);
    expect(find.byType(AlertDialog), findsNothing);

    await closeSettings(tester);
    await openSettings(tester);
    await toggle(tester, false);
    await toggle(tester, true);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await repository.getSetting('notifications.enabled'), 'true');
    await closeSettings(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('battery hint opens settings after reminders are saved',
      (tester) async {
    await openSettings(tester);
    await toggle(tester, true);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('前往设置')));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'openBatteryOptimizationSettings'),
        hasLength(1));
    expect(await repository.getSetting('notifications.enabled'), 'true');
    await closeSettings(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'exempt app skips hint and failed settings launch explains manual path',
      (tester) async {
    optimized = true;
    await openSettings(tester);
    await toggle(tester, true);
    expect(find.byType(AlertDialog), findsNothing);
    ScaffoldMessenger.of(tester.element(find.byType(SettingsPage)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    failOpening = true;
    final button = find.text('前往设置');
    await tester.scrollUntilVisible(button, 150);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('无法打开系统设置，请在手机设置中调整本应用的电池限制'), findsOneWidget);
    expect(await repository.getSetting('notifications.enabled'), 'true');
    expect(tester.takeException(), isNull);
    await closeSettings(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
