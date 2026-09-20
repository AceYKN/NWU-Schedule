import 'dart:convert';
import 'dart:io';

import 'package:nwu_schedule/domain/import/timetable_import.dart';

const zhengfangTimetableFixturePath =
    'test/fixtures/zhengfang/timetable_response.json';

Map<String, dynamic> readJsonFixture(String path) {
  final value = jsonDecode(File(path).readAsStringSync());
  if (value is! Map) {
    throw FormatException('Fixture must contain a JSON object: $path');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> readZhengfangTimetableFixture() =>
    readJsonFixture(zhengfangTimetableFixturePath);

RemoteTimetable parseZhengfangTimetableFixture() =>
    const TimetableImportParser().parse(readZhengfangTimetableFixture());

/// Returns an independent JSON tree for tests that mutate an import payload.
Map<String, dynamic> cloneJsonObject(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
  );
}
