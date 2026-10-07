import 'package:flutter/services.dart';

/// Clears Android WebView data that is not reachable through the public
/// webview_flutter controller API. This is deliberately explicit so the
/// import session cannot outlive the import screen or a clear-data action.
class WebViewSessionService {
  const WebViewSessionService();

  static Future<void> _cleanupTail = Future<void>.value();

  static Future<void> get waitForCleanup => _cleanupTail;

  static Future<void> serializeCleanup(Future<void> Function() operation) {
    final task = _cleanupTail.then((_) => operation());
    _cleanupTail = task.catchError((Object _) {});
    return task;
  }

  static const _channel = MethodChannel('nwu_schedule/webview_session');

  Future<void> clear() => _channel.invokeMethod<void>('clearSession');
}
