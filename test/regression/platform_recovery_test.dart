import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/infrastructure/import/webview_session_service.dart';
import 'package:nwu_schedule/infrastructure/notifications/notification_service.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification retry repairs an identical plan after native failure',
      () async {
    const service = NotificationService();
    const channel = MethodChannel('nwu_schedule/notifications');
    var rebuilds = 0;
    var fail = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'rebuildNotifications') {
        rebuilds++;
        if (fail) throw PlatformException(code: 'schedule_failed');
      }
      return null;
    });
    service.invalidateCachedPlan();
    addTearDown(() {
      service.invalidateCachedPlan();
      messenger.setMockMethodCallHandler(channel, null);
    });
    final plan = [
      PlannedNotification(
          id: 1,
          fireAtUtc: DateTime.utc(2026, 12, 1),
          title: '合成课程',
          body: '合成教室',
          payload: 'synthetic',
          route: '/course/synthetic')
    ];
    await service.rebuild(plan);
    await service.rebuild(plan);
    expect(rebuilds, 1);
    service.invalidateCachedPlan();
    fail = true;
    await expectLater(service.rebuild(plan), throwsA(isA<PlatformException>()));
    fail = false;
    await service.rebuild(plan);
    expect(rebuilds, 3);
  });

  test(
      'new WebView session waits for every old cleanup and can recover from errors',
      () async {
    final release = Completer<void>();
    final started = Completer<void>();
    final events = <String>[];
    final first = WebViewSessionService.serializeCleanup(() async {
      events.add('old-cleanup-start');
      started.complete();
      await release.future;
      events.add('old-cleanup-end');
    });
    await started.future;
    final second = WebViewSessionService.serializeCleanup(() async {
      events.add('second-cleanup');
      throw StateError('synthetic cleanup failure');
    });
    final expectedFailure = expectLater(second, throwsStateError);
    final newSession = WebViewSessionService.waitForCleanup
        .then((_) => events.add('new-load'));
    expect(events, ['old-cleanup-start']);
    release.complete();
    await Future.wait([first, expectedFailure, newSession]);
    expect(events,
        ['old-cleanup-start', 'old-cleanup-end', 'second-cleanup', 'new-load']);
  });
}
