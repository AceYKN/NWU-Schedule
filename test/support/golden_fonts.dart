import 'dart:io';

import 'package:flutter/services.dart';

/// Uses checked-in fonts rather than Ahem or an operating system fallback.
/// The alias matches the Android text theme; only the test process is affected.
Future<void> loadGoldenFonts() async {
  final loader = FontLoader('Roboto');
  for (final style in ['Regular', 'Bold']) {
    final bytes =
        await File('test/fonts/NwuScheduleGolden-$style.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
