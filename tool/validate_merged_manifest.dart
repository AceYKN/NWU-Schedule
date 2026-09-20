import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.length > 2 ||
      (args.length == 2 && args[1] != '--release')) {
    throw StateError(
      'Usage: dart run tool/validate_merged_manifest.dart '
      '<AndroidManifest.xml> [--release]',
    );
  }

  final file = File(args.first);
  final releaseBuild = args.contains('--release');
  if (!file.existsSync()) {
    throw StateError('Merged Android manifest not found: ${file.path}');
  }
  final manifest = file.readAsStringSync();
  final permissions = RegExp(
    r'<uses-permission\b[^>]*android:name="([^"]+)"[^>]*/?>',
  ).allMatches(manifest).map((match) => match.group(1)!).toSet();
  const allowedPermissions = {
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
  };
  final generatedPermission = RegExp(
    r'android:name="([^"]+\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION)"',
  ).firstMatch(manifest)?.group(1);
  final unexpectedPermissions = permissions.difference({
    ...allowedPermissions,
    if (generatedPermission != null) generatedPermission,
  });
  if (unexpectedPermissions.isNotEmpty) {
    throw StateError(
      'Unexpected merged Android permissions: '
      '${unexpectedPermissions.join(', ')}',
    );
  }
  final missingPermissions = allowedPermissions.difference(permissions);
  if (missingPermissions.isNotEmpty) {
    throw StateError(
      'Missing merged Android permissions: ${missingPermissions.join(', ')}',
    );
  }
  if (!manifest.contains('android:allowBackup="false"') ||
      !manifest.contains('android:usesCleartextTraffic="false"')) {
    throw StateError('Merged backup or cleartext network policy is not locked');
  }
  if (releaseBuild && RegExp(r'android:debuggable="true"').hasMatch(manifest)) {
    throw StateError('Merged release/debug manifest is explicitly debuggable');
  }

  const requiredWidgetActions = {
    'android.appwidget.action.APPWIDGET_UPDATE',
    'android.intent.action.DATE_CHANGED',
    'android.intent.action.TIME_SET',
    'android.intent.action.TIMEZONE_CHANGED',
  };
  final missingWidgetActions = requiredWidgetActions
      .where((action) => !manifest.contains('<action android:name="$action"'))
      .toList(growable: false);
  if (missingWidgetActions.isNotEmpty) {
    throw StateError(
      'Merged Widget manifest is missing actions: ${missingWidgetActions.join(', ')}',
    );
  }

  stdout.writeln(
    'Merged manifest validation passed (${file.path}).',
  );
}
