import 'package:flutter/services.dart';

import '../../domain/notification/notification_planner.dart';

class NotificationService {
  const NotificationService();

  static const _channel = MethodChannel('nwu_schedule/notifications');

  Future<bool> requestPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  Future<void> rebuild(Iterable<PlannedNotification> requests) async {
    await _channel.invokeMethod<void>(
      'rebuildNotifications',
      <String, Object?>{
        'requests': [for (final request in requests) request.toJson()],
      },
    );
  }

  Future<void> clear() => _channel.invokeMethod<void>('clearNotifications');
}
