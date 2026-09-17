import '../../domain/import/timetable_import.dart';
import '../../domain/import/timetable_importer.dart';

typedef TimetablePayloadReader = Future<Map<String, dynamic>> Function();

/// NWU's current public entry is a Zhengfang V9 installation. The concrete
/// page/API discovery remains outside this normalizer because the authenticated
/// endpoint and response shape must be observed in a real student session.
class NwuZhengfangV9Importer implements TimetableImporter {
  static final entryUri = Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/');

  static bool isAllowedUri(Uri uri) =>
      uri.scheme == 'https' && uri.host == 'jwgl.nwu.edu.cn';

  NwuZhengfangV9Importer({
    required this.readPayload,
    this.parser = const TimetableImportParser(),
  });

  final TimetablePayloadReader readPayload;
  final TimetableImportParser parser;
  RemoteTimetable? _cachedTimetable;

  @override
  Future<List<RemoteSemester>> getSemesters() async {
    final timetable = _cachedTimetable ??= await _read('semester-discovery');
    return [timetable.semester];
  }

  @override
  Future<RemoteTimetable> importSemester(RemoteSemester semester) async {
    final timetable = _cachedTimetable ??= await _read('timetable');
    _cachedTimetable = null;
    if (timetable.semester.id != semester.id) {
      throw TimetableImportFailure(
        '当前页面的学期与所选学期不一致',
        ImportDiagnostic(
          adapterVersion: 'nwu-zhengfang-v9',
          parserStage: 'semester-match',
        ),
      );
    }
    return timetable;
  }

  Future<RemoteTimetable> _read(String stage) async {
    try {
      final payload = await readPayload();
      final timetable = parser.parse(payload);
      final report = validateTimetable(timetable);
      if (!report.isValid) {
        throw TimetableImportFailure(
          '课表数据校验失败',
          ImportDiagnostic(
            adapterVersion: 'nwu-zhengfang-v9',
            parserStage: '$stage-validation',
            responseSchemaKeys:
                payload.keys.map((key) => key.toString()).toList(),
            error: report.issues.join('; '),
          ),
        );
      }
      return timetable;
    } on TimetableImportFailure {
      rethrow;
    } on Object catch (error) {
      throw TimetableImportFailure(
        '无法读取课表：$error',
        ImportDiagnostic(
          adapterVersion: 'nwu-zhengfang-v9',
          parserStage: stage,
          error: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {}
}
