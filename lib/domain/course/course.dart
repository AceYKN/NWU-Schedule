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
        updatedAt = updatedAt ?? createdAt ?? DateTime.now() {
    if (id.trim().isEmpty || semesterId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Course id, semesterId and name must be non-empty');
    }
    if (credits != null && (!credits!.isFinite || credits! < 0)) {
      throw ArgumentError.value(credits, 'credits');
    }
  }

  static const Object _unset = Object();

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
    Object? code = _unset,
    Object? teachingClass = _unset,
    Object? credits = _unset,
    Object? assessment = _unset,
    Object? note = _unset,
    Object? colorOverride = _unset,
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
      code: identical(code, _unset) ? this.code : code as String?,
      teachingClass: identical(teachingClass, _unset)
          ? this.teachingClass
          : teachingClass as String?,
      credits: identical(credits, _unset) ? this.credits : credits as double?,
      assessment: identical(assessment, _unset)
          ? this.assessment
          : assessment as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      colorOverride: identical(colorOverride, _unset)
          ? this.colorOverride
          : colorOverride as int?,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
