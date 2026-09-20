import 'timetable_import.dart';

String redactImportError(Object error) {
  final redacted = error.toString().replaceAllMapped(
    RegExp(r'raw="([^"]*)"'),
    (match) {
      // A malformed week cell can contain arbitrary page text when the
      // DOM columns are shifted. Keep only structural teaching-week
      // characters in an exported diagnostic.
      final raw = match.group(1) ?? '';
      final safe = raw.replaceAll(RegExp(r'[^0-9,，、\-~～—至\s]'), '').trim();
      return 'raw="$safe"';
    },
  ).replaceAll(
    RegExp(
      r'(password|passwd|pwd|token|cookie|authorization|session|secret|username)\s*[:=]\s*[^\s,;}]+',
      caseSensitive: false,
    ),
    r'$1=<redacted>',
  );
  return redacted.length <= 512 ? redacted : '${redacted.substring(0, 512)}…';
}

class ImportDiagnostic {
  const ImportDiagnostic({
    required this.adapterVersion,
    required this.parserStage,
    this.appVersion,
    this.androidVersion,
    this.webViewVersion,
    this.currentUrlPath,
    this.httpStatus,
    this.selectedSemesterId,
    this.selectors = const [],
    this.responseSchemaKeys = const [],
    this.error,
  });

  final String adapterVersion;
  final String parserStage;
  final String? appVersion;
  final String? androidVersion;
  final String? webViewVersion;
  final String? currentUrlPath;
  final int? httpStatus;
  final String? selectedSemesterId;
  final List<String> selectors;
  final List<String> responseSchemaKeys;
  final String? error;

  ImportDiagnostic copyWith({
    String? appVersion,
    String? androidVersion,
    String? webViewVersion,
    String? currentUrlPath,
    int? httpStatus,
    String? selectedSemesterId,
    List<String>? selectors,
    List<String>? responseSchemaKeys,
    String? error,
  }) {
    return ImportDiagnostic(
      adapterVersion: adapterVersion,
      parserStage: parserStage,
      appVersion: appVersion ?? this.appVersion,
      androidVersion: androidVersion ?? this.androidVersion,
      webViewVersion: webViewVersion ?? this.webViewVersion,
      currentUrlPath: currentUrlPath ?? this.currentUrlPath,
      httpStatus: httpStatus ?? this.httpStatus,
      selectedSemesterId: selectedSemesterId ?? this.selectedSemesterId,
      selectors: selectors ?? this.selectors,
      responseSchemaKeys: responseSchemaKeys ?? this.responseSchemaKeys,
      error: error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => {
        'adapterVersion': adapterVersion,
        'parserStage': parserStage,
        if (appVersion != null) 'appVersion': appVersion,
        if (androidVersion != null) 'androidVersion': androidVersion,
        if (webViewVersion != null) 'webViewVersion': webViewVersion,
        if (currentUrlPath != null) 'currentUrlPath': currentUrlPath,
        if (httpStatus != null) 'httpStatus': httpStatus,
        if (selectedSemesterId != null)
          'selectedSemesterId': selectedSemesterId,
        'selectors': selectors,
        'responseSchemaKeys': responseSchemaKeys,
        if (error != null) 'error': error,
      };
}

class TimetableImportFailure implements Exception {
  const TimetableImportFailure(this.message, this.diagnostic);

  final String message;
  final ImportDiagnostic diagnostic;

  @override
  String toString() => message;
}

abstract interface class TimetableImporter {
  Future<List<RemoteSemester>> getSemesters();

  Future<RemoteTimetable> importSemester(RemoteSemester semester);

  Future<void> dispose();
}
