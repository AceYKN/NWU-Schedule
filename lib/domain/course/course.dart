enum CourseSourceType { imported, manual }

class Course {
  Course({
    required this.id,
    required this.semesterId,
    required this.sourceType,
    this.sourceCourseKey,
    required this.name,
    this.code,
    this.teachingClass,
    this.credits,
    this.assessment,
    this.note,
    this.colorOverride,
    this.hidden = false,
    this.deleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String semesterId;
  final CourseSourceType sourceType;
  final String? sourceCourseKey;
  final String name;
  final String? code;
  final String? teachingClass;
  final double? credits;
  final String? assessment;
  final String? note;

  /// ARGB color value. Domain stays independent from Flutter's Color class.
  final int? colorOverride;
  final bool hidden;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course copyWith({
    String? name,
    String? code,
    String? teachingClass,
    double? credits,
    String? assessment,
    String? note,
    int? colorOverride,
    bool? hidden,
    bool? deleted,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id,
      semesterId: semesterId,
      sourceType: sourceType,
      sourceCourseKey: sourceCourseKey,
      name: name ?? this.name,
      code: code ?? this.code,
      teachingClass: teachingClass ?? this.teachingClass,
      credits: credits ?? this.credits,
      assessment: assessment ?? this.assessment,
      note: note ?? this.note,
      colorOverride: colorOverride ?? this.colorOverride,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
