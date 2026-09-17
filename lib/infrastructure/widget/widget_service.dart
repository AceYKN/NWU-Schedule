import 'package:flutter/services.dart';

import '../../domain/widget/widget_snapshot.dart';

class WidgetService {
  const WidgetService();

  static const _channel = MethodChannel('nwu_schedule/widget');

  Future<void> publish(WidgetSnapshot snapshot) async {
    await _channel.invokeMethod<void>(
      'updateSnapshot',
      <String, Object?>{'json': snapshot.encode()},
    );
  }

  Future<void> clear() => _channel.invokeMethod<void>('clearSnapshot');
}
