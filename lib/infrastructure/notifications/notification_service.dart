import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/notification/notification_planner.dart';

class NotificationService {
  const NotificationService();

  static String? _lastPlan;

  static const _channel = MethodChannel('nwu_schedule/notifications');

  /// A user-requested retry must also repair native state changed in the
  /// background since the last successful Flutter rebuild.
  void invalidateCachedPlan() => _lastPlan = null;

  Future<bool> requestPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  Future<void> rebuild(Iterable<PlannedNotification> requests) async {
    final plan = [for (final request in requests) request.toJson()];
    final signature = jsonEncode(plan);
    if (_lastPlan == signature) return;
    await _channel.invokeMethod<void>(
        'rebuildNotifications', <String, Object?>{'requests': plan});
    _lastPlan = signature;
  }

  Future<void> clear() async {
    await _channel.invokeMethod<void>('clearNotifications');
    _lastPlan = null;
  }

  Future<Map<String, dynamic>?> status() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getStatus');
    } on MissingPluginException {
      return null;
    }
  }
}
