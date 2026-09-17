import '../../core/utils/date_utils.dart';

enum SemesterTerm { first, second, summer }

class Semester {
  const Semester({
    required this.id,
    required this.academicYear,
    required this.term,
    required this.label,
    this.remoteTermKey,
    this.calendarId,
    required this.createdAt,
  });

  final String id;
  final String academicYear;
  final SemesterTerm term;
  final String label;
  final String? remoteTermKey;
  final String? calendarId;
  final DateTime createdAt;

  Semester copyWith({
    String? label,
    String? remoteTermKey,
    String? calendarId,
  }) {
    return Semester(
      id: id,
      academicYear: academicYear,
      term: term,
      label: label ?? this.label,
      remoteTermKey: remoteTermKey ?? this.remoteTermKey,
      calendarId: calendarId ?? this.calendarId,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'academicYear': academicYear,
      'term': term.name,
      'label': label,
      'remoteTermKey': remoteTermKey,
      'calendarId': calendarId,
      'createdAt': dateKey(createdAt),
    };
  }
}
