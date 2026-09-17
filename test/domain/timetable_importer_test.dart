import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/import/timetable_importer.dart';
import 'package:nwu_schedule/infrastructure/import/nwu_zhengfang_v9_importer.dart';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = jsonDecode(File(
      'test/fixtures/zhengfang/timetable_response.json',
    ).readAsStringSync()) as Map<String, dynamic>;
  });

  test('adapter normalizes a payload without storing login data', () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => fixture,
    );
    final semesters = await importer.getSemesters();
    final timetable = await importer.importSemester(semesters.single);

    expect(semesters.single.id, 'nwu-2026-2027-1');
    expect(timetable.courses, hasLength(2));
    expect(importer.runtimeType.toString(), contains('NwuZhengfangV9Importer'));
  });

  test('only allows the official HTTPS host', () {
    expect(
      NwuZhengfangV9Importer.isAllowedUri(
        Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/'),
      ),
      isTrue,
    );
    expect(
      NwuZhengfangV9Importer.isAllowedUri(
        Uri.parse('http://jwgl.nwu.edu.cn/jwglxt/'),
      ),
      isFalse,
    );
    expect(
      NwuZhengfangV9Importer.isAllowedUri(
        Uri.parse('https://example.com/jwglxt/'),
      ),
      isFalse,
    );
  });

  test('adapter failure exposes only redacted diagnostics', () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => {'username': 'student', 'password': 'secret'},
    );

    await expectLater(
      importer.getSemesters(),
      throwsA(
        isA<TimetableImportFailure>().having(
          (error) => error.diagnostic.toJson().toString(),
          'diagnostic',
          isNot(contains('secret')),
        ),
      ),
    );
  });
}
