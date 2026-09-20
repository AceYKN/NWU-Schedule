import '../../domain/import/timetable_import.dart';
import '../../domain/import/timetable_importer.dart';

typedef TimetablePayloadReader = Future<Map<String, dynamic>> Function();

/// NWU's current public entry is a Zhengfang V9 installation. The concrete
/// page/API discovery remains outside this normalizer because the authenticated
/// endpoint and response shape must be observed in a real student session.
class NwuZhengfangV9Importer implements TimetableImporter {
  static const adapterVersion = 'nwu-zhengfang-v9-dom-v4';
  static final entryUri = Uri.parse('https://jwgl.nwu.edu.cn/jwglxt/');

  static bool isAllowedUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'jwgl.nwu.edu.cn' &&
      (uri.path == '/jwglxt' || uri.path.startsWith('/jwglxt/'));

  /// The public Zhengfang entry path renders the login form itself. Keep it
  /// explicit here so the WebView layer cannot mistake the entry page for an
  /// authenticated timetable context just because it is on the allow-listed
  /// host.
  static bool isLoginUri(Uri uri) {
    if (!isAllowedUri(uri)) return false;
    final path = uri.path.toLowerCase();
    return path == '/jwglxt' ||
        path == '/jwglxt/' ||
        path.contains('/login') ||
        path.contains('/sso') ||
        path.contains('/auth');
  }

  /// Paths observed for the authenticated Zhengfang personal timetable pages.
  ///
  /// This is deliberately narrower than [isAllowedUri]. The latter protects
  /// the navigation host boundary; this allowlist protects the JavaScript
  /// bridge boundary. The endpoint and response schema remain unverified.
  static bool isTrustedTimetableUri(Uri uri) {
    if (!isAllowedUri(uri) || isLoginUri(uri)) return false;
    final path = uri.path.toLowerCase();
    return path == '/jwglxt/kbcx/xskbcx_cxxskbcxindex.html' ||
        path == '/jwglxt/kbcx/xskbcx_cxxsgrkb.html';
  }

  NwuZhengfangV9Importer({
    required this.readPayload,
    this.parser = const TimetableImportParser(),
  });

  final TimetablePayloadReader readPayload;
  final TimetableImportParser parser;
  Map<String, dynamic>? _cachedPayload;

  @override
  Future<List<RemoteSemester>> getSemesters() async {
    final payload = await _payload();
    try {
      final candidates = _semesterCandidates(payload);
      if (candidates.isEmpty) {
        throw const FormatException('semester candidates must be a list');
      }
      final semesters = <RemoteSemester>[];
      for (final candidate in candidates) {
        final semester = parser.parseSemester(candidate);
        if (semesters.every((item) => item.id != semester.id)) {
          semesters.add(semester);
        }
      }
      return List.unmodifiable(semesters);
    } on TimetableImportFailure {
      rethrow;
    } on Object catch (error) {
      throw TimetableImportFailure(
        '无法识别教务系统返回的学期数据',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'semester',
          responseSchemaKeys:
              payload.keys.map((key) => key.toString()).toList(),
          error: redactImportError(error),
        ),
      );
    }
  }

  @override
  Future<RemoteTimetable> importSemester(RemoteSemester semester) async {
    final payload = await _payload();
    final selectedPayload = _payloadForSemester(payload, semester);
    final timetable = await _read(selectedPayload, 'timetable');
    _cachedPayload = null;
    if (timetable.semester.id != semester.id) {
      throw TimetableImportFailure(
        '当前页面的学期与所选学期不一致',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'semester-match',
          selectedSemesterId: semester.id,
        ),
      );
    }
    return timetable;
  }

  Future<Map<String, dynamic>> _payload() async {
    if (_cachedPayload != null) return _cachedPayload!;
    try {
      return _cachedPayload = await readPayload();
    } on Object catch (error) {
      final safeError = redactImportError(error);
      final parserMismatch =
          error is FormatException && error.message.contains('没有暴露可识别的课表数据');
      throw TimetableImportFailure(
        parserMismatch ? '当前版本暂时无法识别教务系统课表' : '无法读取课表：$safeError',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: parserMismatch ? 'parser' : 'payload-read',
          error: safeError,
        ),
      );
    }
  }

  Future<RemoteTimetable> _read(
    Map<String, dynamic> payload,
    String stage,
  ) async {
    try {
      final timetable = parser.parse(payload);
      final report = validateTimetable(timetable);
      if (!report.isValid) {
        throw TimetableImportFailure(
          '课表数据校验失败',
          ImportDiagnostic(
            adapterVersion: NwuZhengfangV9Importer.adapterVersion,
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
      final safeError = redactImportError(error);
      throw TimetableImportFailure(
        '无法读取课表：$safeError',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: stage,
          responseSchemaKeys:
              payload.keys.map((key) => key.toString()).toList(),
          error: redactImportError(error),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _semesterCandidates(
    Map<String, dynamic> payload,
  ) {
    final raw =
        payload['semesters'] ?? payload['semesterOptions'] ?? payload['terms'];
    if (raw is! List || raw.isEmpty) return [payload];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic> _payloadForSemester(
    Map<String, dynamic> payload,
    RemoteSemester selected,
  ) {
    for (final candidate in _semesterCandidates(payload)) {
      final semester = parser.parseSemester(candidate);
      if (semester.id != selected.id) continue;
      if (_hasCourses(candidate)) return candidate;
      final nested = _nestedTimetable(payload, semester);
      if (nested != null) {
        return {...nested, 'semester': candidate};
      }
    }
    if (_hasCourses(payload)) return payload;
    throw TimetableImportFailure(
      '未找到所选学期的课表数据',
      ImportDiagnostic(
        adapterVersion: NwuZhengfangV9Importer.adapterVersion,
        parserStage: 'semester-payload',
        selectedSemesterId: selected.id,
        responseSchemaKeys: payload.keys.map((key) => key.toString()).toList(),
      ),
    );
  }

  Map<String, dynamic>? _nestedTimetable(
    Map<String, dynamic> payload,
    RemoteSemester semester,
  ) {
    final raw = payload['timetables'] ?? payload['semesterTimetables'];
    if (raw is! Map) return null;
    final value = raw[semester.id] ?? raw[semester.remoteTermKey];
    if (value is! Map) return null;
    final nested = Map<String, dynamic>.from(value);
    return _hasCourses(nested) ? nested : null;
  }

  static bool _hasCourses(Map<String, dynamic> payload) =>
      (payload['courses'] ?? payload['courseList'] ?? payload['rows']) is List;

  @override
  Future<void> dispose() async {
    _cachedPayload = null;
  }
}
