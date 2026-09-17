import 'package:flutter/services.dart';

/// Clears Android WebView data that is not reachable through the public
/// webview_flutter controller API. This is deliberately explicit so the
/// import session cannot outlive the import screen or a clear-data action.
class WebViewSessionService {
  const WebViewSessionService();

  static const _channel = MethodChannel('nwu_schedule/webview_session');

  Future<void> clear() => _channel.invokeMethod<void>('clearSession');
}
