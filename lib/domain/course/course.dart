enum CourseSourceType { imported, manual }

class Course {
  Course({
    required this.id,
    required this.semesterId,
    required this.sourceType,
    this.sourceCourseKey,
    required this.name,
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
  }

  static const Object _unset = Object();

  final String id;
  final String semesterId;
  final CourseSourceType sourceType;
  final String? sourceCourseKey;
  final String name;

  final String? note;

  /// ARGB color value. Domain stays independent from Flutter's Color class.
  final int? colorOverride;
  final bool hidden;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course copyWith({
    String? name,
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
      note: identical(note, _unset) ? this.note : note as String?,
      colorOverride: identical(colorOverride, _unset)
          ? this.colorOverride
          : colorOverride as int?,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
