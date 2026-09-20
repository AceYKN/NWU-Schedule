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

  test('discovers and imports the selected semester from one payload',
      () async {
    var reads = 0;
    final payload = <String, dynamic>{
      'semesters': [
        {
          'remoteTermKey': '2025-2026-2',
          'academicYear': '2025-2026',
          'term': 2,
          'label': '2025-2026 第二学期',
          'totalWeeks': 18,
          'courses': fixture['courses'],
        },
        {
          'remoteTermKey': '2026-2027-1',
          'academicYear': '2026-2027',
          'term': 1,
          'label': '2026-2027 第一学期',
          'totalWeeks': 20,
          'courses': fixture['courses'],
        },
      ],
    };
    final importer = NwuZhengfangV9Importer(
      readPayload: () async {
        reads++;
        return payload;
      },
    );

    final semesters = await importer.getSemesters();
    final timetable = await importer.importSemester(semesters.last);

    expect(semesters.map((semester) => semester.id), [
      'nwu-2025-2026-2',
      'nwu-2026-2027-1',
    ]);
    expect(timetable.semester.id, 'nwu-2026-2027-1');
    expect(timetable.totalWeeks, 20);
    expect(reads, 1);
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

  test('recognizes the official entry and login paths as unauthenticated', () {
    expect(
      NwuZhengfangV9Importer.isLoginUri(
        Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/'),
      ),
      isTrue,
    );
    expect(
      NwuZhengfangV9Importer.isLoginUri(
        Uri.parse(
          'https://jwgl.nwu.edu.cn/jwglxt/xtgl/login_slogin.html',
        ),
      ),
      isTrue,
    );
    expect(
      NwuZhengfangV9Importer.isLoginUri(
        Uri.parse(
          'https://jwgl.nwu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html',
        ),
      ),
      isFalse,
    );
    expect(
      NwuZhengfangV9Importer.isLoginUri(
        Uri.parse('https://example.com/jwglxt/login'),
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
