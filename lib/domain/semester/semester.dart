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
    this.calendarRevision,
    required this.createdAt,
  });

  final String id;
  final String academicYear;
  final SemesterTerm term;
  final String label;
  final String? remoteTermKey;
  final String? calendarId;
  final int? calendarRevision;
  final DateTime createdAt;

  Semester copyWith({
    String? label,
    String? remoteTermKey,
    String? calendarId,
    int? calendarRevision,
  }) {
    return Semester(
      id: id,
      academicYear: academicYear,
      term: term,
      label: label ?? this.label,
      remoteTermKey: remoteTermKey ?? this.remoteTermKey,
      calendarId: calendarId ?? this.calendarId,
      calendarRevision: calendarRevision ?? this.calendarRevision,
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
      'calendarRevision': calendarRevision,
      'createdAt': dateKey(createdAt),
    };
  }
}
