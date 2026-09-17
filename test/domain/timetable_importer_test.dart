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
    expect(
      NwuZhengfangV9Importer.isAllowedUri(
        Uri.parse('https://jwgl.nwu.edu.cn/other/'),
      ),
      isFalse,
    );
  });

  test('diagnostic export contains runtime metadata fields', () {
    final diagnostic = const ImportDiagnostic(
      adapterVersion: 'nwu-zhengfang-v9',
      parserStage: 'bridge-message',
      appVersion: '0.1.0+1',
      androidVersion: 'Android 15',
      webViewVersion: '132.0.0',
      currentUrlPath: '/jwglxt/xk/list',
      selectedSemesterId: 'nwu-2026-2027-1',
      selectors: ['table'],
      responseSchemaKeys: ['courses'],
    );
    final json = diagnostic.toJson();
    expect(json['appVersion'], '0.1.0+1');
    expect(json['androidVersion'], 'Android 15');
    expect(json['webViewVersion'], '132.0.0');
    expect(json['selectedSemesterId'], 'nwu-2026-2027-1');
    expect(json['selectors'], ['table']);
  });

  test('adapter failure exposes only redacted diagnostics', () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => throw StateError(
        '{username: student, password: secret, token: abc123}',
      ),
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
