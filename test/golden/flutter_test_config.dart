import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/golden_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGoldenFonts);
  await testMain();
}
