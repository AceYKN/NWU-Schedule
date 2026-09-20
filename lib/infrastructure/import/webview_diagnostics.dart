/// Small, privacy-safe helpers for WebView runtime diagnostics.
class WebViewDiagnostics {
  const WebViewDiagnostics._();

  static String? versionFromUserAgent(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return null;
    final chrome = RegExp(r'Chrome/([0-9.]+)').firstMatch(userAgent)?.group(1);
    if (chrome != null) return chrome;
    return RegExp(r'Version/([0-9.]+)').firstMatch(userAgent)?.group(1) ??
        userAgent;
  }
}
