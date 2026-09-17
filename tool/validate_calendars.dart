import 'dart:convert';
import 'dart:io';

import 'package:nwu_schedule/domain/calendar/calendar_catalog.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';

void main() {
  final root = Directory('assets/calendars/nwu/source');
  if (!root.existsSync()) {
    stderr.writeln('Calendar directory does not exist: ${root.path}');
    exitCode = 1;
    return;
  }
  try {
    final index = File('${root.path}/index.json');
    final catalog = CalendarCatalog.fromJson(
      jsonDecode(index.readAsStringSync()) as Map<String, dynamic>,
    );
    final indexedFiles = catalog.entries.map((entry) => entry.asset).toSet();
    final actualFiles = root
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.json') && name != 'index.json')
        .toSet();
    if (indexedFiles.length != actualFiles.length ||
        !indexedFiles.containsAll(actualFiles)) {
      throw FormatException(
        'Calendar catalog/assets mismatch: indexed=$indexedFiles actual=$actualFiles',
      );
    }
    for (final entry in catalog.entries) {
      final file = File('${root.path}/${entry.asset}');
      final definition = CalendarDefinition.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      if (definition.id != entry.id) {
        throw FormatException('Calendar id mismatch: ${entry.asset}');
      }
    }
    stdout.writeln(
      'Calendar validation passed (${catalog.entries.length} file(s)).',
    );
  } on Object catch (error) {
    stderr.writeln('Calendar validation failed: $error');
    exitCode = 1;
  }
}
