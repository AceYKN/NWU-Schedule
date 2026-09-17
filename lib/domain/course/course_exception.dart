enum CourseExceptionType { move, cancel, add }

class CourseException {
  const CourseException({
    required this.id,
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
  });

  final String id;
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
