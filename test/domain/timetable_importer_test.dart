import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/errors/app_error.dart';
import 'package:nwu_schedule/domain/import/timetable_importer.dart';
import 'package:nwu_schedule/infrastructure/import/webview_diagnostics.dart';
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
    expect(
      NwuZhengfangV9Importer.adapterVersion,
      'nwu-zhengfang-v9-dom-v6',
    );
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
        Uri.parse('https://jwgl.nwu.edu.cn:8443/jwglxt/'),
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

  test('trusts only the observed authenticated timetable paths for the bridge',
      () {
    expect(
      NwuZhengfangV9Importer.isTrustedTimetableUri(
        Uri.parse(
          'https://jwgl.nwu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html',
        ),
      ),
      isTrue,
    );
    expect(
      NwuZhengfangV9Importer.isTrustedTimetableUri(
        Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/kbcx/xskbcx_cxXsgrkb.html'),
      ),
      isTrue,
    );
    expect(
      NwuZhengfangV9Importer.isTrustedTimetableUri(
        Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/xtgl/index_initMenu.html'),
      ),
      isFalse,
    );
    expect(
      NwuZhengfangV9Importer.isTrustedTimetableUri(
        Uri.parse('https://example.com/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html'),
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

  test('prefers the Chromium WebView version over the legacy Version token',
      () {
    const userAgent =
        'Mozilla/5.0 Version/4.0 Chrome/132.0.6834.79 Mobile Safari/537.36';
    expect(
      WebViewDiagnostics.versionFromUserAgent(userAgent),
      '132.0.6834.79',
    );
    expect(
      WebViewDiagnostics.versionFromUserAgent('Mozilla/5.0 Version/4.0'),
      '4.0',
    );
    expect(WebViewDiagnostics.versionFromUserAgent('Mozilla/5.0'), isNull);
    expect(WebViewDiagnostics.versionFromUserAgent(null), isNull);
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

  test('classifies an unreadable timetable page as a parser mismatch',
      () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => throw const FormatException(
        '当前页面没有暴露可识别的课表数据，请打开个人课表页面后重试',
      ),
    );

    await expectLater(
      importer.getSemesters(),
      throwsA(
        isA<TimetableImportFailure>()
            .having(
              (failure) => failure.diagnostic.parserStage,
              'parserStage',
              'parser',
            )
            .having(
              (failure) => importFailureUserMessage(failure),
              'userMessage',
              contains('无法识别教务系统课表'),
            ),
      ),
    );
  });

  test('keeps a bridge-disabled payload read as an authentication failure',
      () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => throw const FormatException(
        '登录完成后请先打开课表页面',
      ),
    );

    await expectLater(
      importer.getSemesters(),
      throwsA(
        isA<TimetableImportFailure>()
            .having(
              (failure) => failure.diagnostic.parserStage,
              'parserStage',
              'payload-read',
            )
            .having(
              (failure) => importFailureUserMessage(failure),
              'userMessage',
              contains('登录状态已经失效'),
            ),
      ),
    );
  });

  test('wraps malformed semester payloads with schema diagnostics', () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => {
        'semesters': [
          {'academicYear': 'not-a-year'},
        ],
      },
    );

    await expectLater(
      importer.getSemesters(),
      throwsA(
        isA<TimetableImportFailure>()
            .having(
              (failure) => failure.diagnostic.parserStage,
              'parserStage',
              'semester',
            )
            .having(
              (failure) => failure.diagnostic.responseSchemaKeys,
              'responseSchemaKeys',
              contains('semesters'),
            ),
      ),
    );
  });

  test('redacts arbitrary raw week cell text from diagnostics', () {
    final redacted = redactImportError(
      const FormatException(
        'courses[0].meetings[0].weekText 无法解析：raw="教师张三 321 教室"',
      ),
    );
    expect(redacted, contains('raw="321"'));
    expect(redacted, isNot(contains('教师张三')));
    expect(redacted, isNot(contains('教室')));

    final hanWeekWord = redactImportError(
      const FormatException(
        'courses[0].meetings[0].weekText 无法解析：raw="周老师 1-18周 教室"',
      ),
    );
    expect(hanWeekWord, contains('raw="1-18"'));
    expect(hanWeekWord, isNot(contains('周老师')));
  });

  test('invalid week diagnostics retain the payload schema and field path',
      () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async => {
        ...fixture,
        'courses': [
          {
            'sourceCourseKey': 'course-321',
            'name': '软件测试',
            'meetings': [
              {
                'sourceMeetingKey': 'meeting-321',
                'weekday': 1,
                'startSection': 1,
                'endSection': 2,
                'weekText': '321',
              },
            ],
          },
        ],
      },
    );
    final semester = (await importer.getSemesters()).single;

    await expectLater(
      importer.importSemester(semester),
      throwsA(
        isA<TimetableImportFailure>().having(
          (failure) => failure.diagnostic,
          'diagnostic',
          isA<ImportDiagnostic>()
              .having(
                (diagnostic) => diagnostic.responseSchemaKeys,
                'responseSchemaKeys',
                contains('courses'),
              )
              .having(
                (diagnostic) => diagnostic.error,
                'error',
                allOf(
                  contains('courses[0].meetings[0].weekText'),
                  contains('raw="321"'),
                ),
              ),
        ),
      ),
    );
  });
}
