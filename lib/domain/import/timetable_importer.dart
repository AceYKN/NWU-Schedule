import 'timetable_import.dart';

class ImportDiagnostic {
  const ImportDiagnostic({
    required this.adapterVersion,
    required this.parserStage,
    this.currentUrlPath,
    this.httpStatus,
    this.selectors = const [],
    this.responseSchemaKeys = const [],
    this.error,
  });

  final String adapterVersion;
  final String parserStage;
  final String? currentUrlPath;
  final int? httpStatus;
  final List<String> selectors;
  final List<String> responseSchemaKeys;
  final String? error;

  Map<String, Object?> toJson() => {
        'adapterVersion': adapterVersion,
        'parserStage': parserStage,
        if (currentUrlPath != null) 'currentUrlPath': currentUrlPath,
        if (httpStatus != null) 'httpStatus': httpStatus,
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
