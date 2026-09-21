import 'dart:io';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final permissions = RegExp(
    r'<uses-permission\s+android:name="([^"]+)"\s*/>',
  ).allMatches(manifest).map((match) => match.group(1)!).toSet();
  const allowedPermissions = {
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
  };
  final unexpectedPermissions = permissions.difference(allowedPermissions);
  if (unexpectedPermissions.isNotEmpty) {
    throw StateError(
      'Unexpected Android permissions: ${unexpectedPermissions.join(', ')}',
    );
  }
  final missingPermissions = allowedPermissions.difference(permissions);
  if (missingPermissions.isNotEmpty) {
    throw StateError(
      'Missing Android permissions: ${missingPermissions.join(', ')}',
    );
  }
  if (!manifest.contains('android:allowBackup="false"') ||
      !manifest.contains('android:usesCleartextTraffic="false"')) {
    throw StateError(
      'Android backup or cleartext network policy is not locked down',
    );
  }

  final mainActivity = File(
    'android/app/src/main/kotlin/io/github/aceykn/nwuschedule/MainActivity.kt',
  ).readAsStringSync();
  if (!mainActivity.contains('ApplicationInfo.FLAG_DEBUGGABLE') ||
      !mainActivity.contains('WebView.setWebContentsDebuggingEnabled(false)')) {
    throw StateError('Release WebView debugging is not explicitly disabled');
  }

  final gitignore = File('.gitignore').readAsStringSync();
  final gitignorePatterns = gitignore
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
  const requiredSigningIgnores = {
    '/android/key.properties',
    '*.jks',
    '*.keystore',
    '*.p12',
  };
  final missingSigningIgnores = requiredSigningIgnores
      .where((pattern) => !gitignorePatterns.contains(pattern))
      .toList(growable: false);
  if (missingSigningIgnores.isNotEmpty) {
    throw StateError(
      'Release signing files are not ignored: '
      '${missingSigningIgnores.join(', ')}',
    );
  }

  final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
  const forbiddenPackages = [
    'firebase',
    'crashlytics',
    'sentry',
    'amplitude',
    'mixpanel',
    'segment',
    'appsflyer',
    'admob',
    'google_mobile_ads',
    'posthog',
  ];
  final foundPackages = forbiddenPackages
      .where((package) =>
          RegExp('(?:^|[\\s":])${RegExp.escape(package)}').hasMatch(pubspec))
      .toList(growable: false);
  if (foundPackages.isNotEmpty) {
    throw StateError(
      'Forbidden analytics/advertising packages found: ${foundPackages.join(', ')}',
    );
  }

  stdout.writeln(
    'Privacy validation passed (permissions, backup policy, cleartext policy, '
    'WebView debugging, signing ignores, dependencies).',
  );
}
