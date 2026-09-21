import '../../core/nwu/periods.dart';

enum CourseExceptionType { move, cancel, add }

/// Stores only a changed value in an exception. An empty string is retained
/// when it intentionally clears an existing value; null means "use the
/// effective course value".
String? exceptionOverrideIfChanged(String? edited, String? original) {
  final next = edited?.trim() ?? '';
  final baseline = original?.trim() ?? '';
  return next == baseline ? null : next;
}

class CourseException {
  CourseException({
    required this.id,
    required this.semesterId,
    this.courseId,
    this.sourceMeetingId,
    this.sourceDate,
    required this.type,
    this.targetDate,
    this.targetStartSection,
    this.targetEndSection,
    this.teacherOverride,
    this.campusOverride,
    this.roomOverride,
    this.addedCourseName,
    this.note,
  }) {
    if (id.trim().isEmpty || semesterId.trim().isEmpty) {
      throw ArgumentError('Exception id and semesterId must be non-empty');
    }
    switch (type) {
      case CourseExceptionType.move:
        if (_blank(courseId) ||
            _blank(sourceMeetingId) ||
            sourceDate == null ||
            targetDate == null ||
            targetStartSection == null ||
            targetEndSection == null) {
          throw ArgumentError('MOVE requires source and target course details');
        }
      case CourseExceptionType.cancel:
        if (_blank(courseId) || _blank(sourceMeetingId) || sourceDate == null) {
          throw ArgumentError('CANCEL requires source course details');
        }
      case CourseExceptionType.add:
        if (targetDate == null ||
            targetStartSection == null ||
            targetEndSection == null ||
            (_blank(courseId) && _blank(addedCourseName))) {
          throw ArgumentError('ADD requires a target and a course');
        }
    }
    if ((targetStartSection == null) != (targetEndSection == null) ||
        (targetStartSection != null &&
            (targetStartSection! < 1 ||
                targetEndSection! > NwuPeriodRepository.all.length ||
                targetStartSection! > targetEndSection!))) {
      throw ArgumentError('Invalid exception section range');
    }
  }

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  final String id;
  final String semesterId;
  final String? courseId;
  final String? sourceMeetingId;
  final DateTime? sourceDate;
  final CourseExceptionType type;

  /// Required for MOVE/ADD and omitted for CANCEL.
  final DateTime? targetDate;
  final int? targetStartSection;
  final int? targetEndSection;
  final String? teacherOverride;
  final String? campusOverride;
  final String? roomOverride;
  final String? addedCourseName;
  final String? note;
}
