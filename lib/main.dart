import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/nwu/constants.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    nwuAppVersion = await const MethodChannel('nwu_schedule/app')
            .invokeMethod<String>('getAppVersion') ??
        nwuAppVersion;
  } on MissingPluginException {
    // Non-Android previews use the generated pubspec version.
  } on PlatformException {
    // Metadata failure must not prevent access to offline courses.
  }
  runApp(const NwuScheduleAppRoot());
}
