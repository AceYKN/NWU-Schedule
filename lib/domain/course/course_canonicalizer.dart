import 'course.dart';
import 'course_exception.dart';
import 'course_identity.dart';
import 'meeting_rule.dart';

class CanonicalizedSchedule {
  const CanonicalizedSchedule({
    required this.courses,
    required this.meetingRules,
    required this.exceptions,
  });

  final List<Course> courses;
  final List<MeetingRule> meetingRules;
  final List<CourseException> exceptions;
}

/// Merges legacy duplicate course rows while preserving their schedule data.
class CourseCanonicalizer {
  const CourseCanonicalizer._();

  static CanonicalizedSchedule canonicalize({
    required Iterable<Course> courses,
    required Iterable<MeetingRule> meetingRules,
    required Iterable<CourseException> exceptions,
  }) {
    final inputCourses = courses.toList(growable: false);
    final rulesByCourse = <String, List<MeetingRule>>{};
    for (final rule in meetingRules) {
      rulesByCourse.putIfAbsent(rule.courseId, () => []).add(rule);
    }

    final groups = <String, List<Course>>{};
    for (final course in inputCourses) {
      final key =
          '${course.semesterId}\u0000${CourseIdentity.nameKey(course.name)}';
      groups.putIfAbsent(key, () => []).add(course);
    }

    final courseIdRemap = <String, String>{};
    final ruleIdRemap = <String, String>{};
    final canonicalCourses = <Course>[];
    final canonicalRules = <MeetingRule>[];
    for (final group in groups.values) {
      final ordered = [...group]..sort(_compareCanonicalPriority);
      final canonical = ordered.first;
      final merged = _mergeCourse(ordered, canonical);
      canonicalCourses.add(merged);
      for (final course in ordered) {
        courseIdRemap[course.id] = canonical.id;
      }

      final ownedRules = [
        for (final course in ordered) ...rulesByCourse[course.id] ?? const [],
      ];
      final rulesByStructure = <String, List<MeetingRule>>{};
      for (final rule in ownedRules) {
        final key = _meetingKey(rule);
        rulesByStructure.putIfAbsent(key, () => []).add(rule);
      }
      for (final duplicateGroup in rulesByStructure.values) {
        duplicateGroup.sort((left, right) {
          final leftCanonical = left.courseId == canonical.id ? 0 : 1;
          final rightCanonical = right.courseId == canonical.id ? 0 : 1;
          final byCourse = leftCanonical.compareTo(rightCanonical);
          if (byCourse != 0) return byCourse;
          final byImported = (right.sourceMeetingKey != null ? 1 : 0).compareTo(
            left.sourceMeetingKey != null ? 1 : 0,
          );
          if (byImported != 0) return byImported;
          return left.id.compareTo(right.id);
        });
        final retained = duplicateGroup.first;
        final mergedRule = _mergeRule(duplicateGroup, canonical.id, retained);
        canonicalRules.add(mergedRule);
        for (final rule in duplicateGroup) {
          ruleIdRemap[rule.id] = retained.id;
        }
      }
    }

    final canonicalExceptions = [
      for (final exception in exceptions)
        _remapException(exception, courseIdRemap, ruleIdRemap),
    ];
    return CanonicalizedSchedule(
      courses: List.unmodifiable(canonicalCourses),
      meetingRules: List.unmodifiable(canonicalRules),
      exceptions: List.unmodifiable(canonicalExceptions),
    );
  }

  static int _compareCanonicalPriority(Course left, Course right) {
    int rank(Course course) {
      if (course.deleted) return 2;
      return course.sourceType == CourseSourceType.imported ? 0 : 1;
    }

    final byRank = rank(left).compareTo(rank(right));
    if (byRank != 0) return byRank;
    final byCreated = left.createdAt.compareTo(right.createdAt);
    if (byCreated != 0) return byCreated;
    return left.id.compareTo(right.id);
  }

  static Course _mergeCourse(List<Course> group, Course canonical) {
    final imported = group
        .where(
          (course) =>
              course.sourceType == CourseSourceType.imported &&
              course.sourceCourseKey?.trim().isNotEmpty == true,
        )
        .toList()
      ..sort((left, right) {
        final byUpdated = right.updatedAt.compareTo(left.updatedAt);
        if (byUpdated != 0) return byUpdated;
        return left.id.compareTo(right.id);
      });
    String? latestNonEmptyNote() {
      final candidates = group
          .where((course) => course.note?.trim().isNotEmpty == true)
          .toList()
        ..sort((left, right) {
          final byUpdated = right.updatedAt.compareTo(left.updatedAt);
          if (byUpdated != 0) return byUpdated;
          return left.id.compareTo(right.id);
        });
      return candidates.isEmpty ? null : candidates.first.note;
    }

    final colors =
        group.where((course) => course.colorOverride != null).toList()
          ..sort((left, right) {
            final byUpdated = right.updatedAt.compareTo(left.updatedAt);
            if (byUpdated != 0) return byUpdated;
            return left.id.compareTo(right.id);
          });
    final createdAt = group
        .map((course) => course.createdAt)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final updatedAt = group
        .map((course) => course.updatedAt)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    return Course(
      id: canonical.id,
      semesterId: canonical.semesterId,
      sourceType:
          group.any((course) => course.sourceType == CourseSourceType.imported)
              ? CourseSourceType.imported
              : CourseSourceType.manual,
      sourceCourseKey: imported.isEmpty ? null : imported.first.sourceCourseKey,
      name: canonical.name,
      note: latestNonEmptyNote(),
      colorOverride: colors.isEmpty ? null : colors.first.colorOverride,
      hidden: group.every((course) => course.hidden),
      deleted: group.every((course) => course.deleted),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static MeetingRule _mergeRule(
    List<MeetingRule> group,
    String canonicalCourseId,
    MeetingRule retained,
  ) {
    String? preferred(String? Function(MeetingRule) select) {
      for (final rule in group) {
        final value = select(rule);
        if (value?.trim().isNotEmpty == true) return value;
      }
      return null;
    }

    return MeetingRule(
      id: retained.id,
      courseId: canonicalCourseId,
      sourceMeetingKey: retained.sourceMeetingKey,
      weekday: retained.weekday,
      startSection: retained.startSection,
      endSection: retained.endSection,
      weekMask: retained.weekMask,
      teacher: preferred((rule) => rule.teacher),
      campus: preferred((rule) => rule.campus),
      room: preferred((rule) => rule.room),
    );
  }

  static String _meetingKey(MeetingRule rule) =>
      '${rule.weekday}|${rule.startSection}|${rule.endSection}|${rule.weekMask.value}';

  static CourseException _remapException(
    CourseException exception,
    Map<String, String> courseIdRemap,
    Map<String, String> ruleIdRemap,
  ) {
    return CourseException(
      id: exception.id,
      semesterId: exception.semesterId,
      courseId: exception.courseId == null
          ? null
          : courseIdRemap[exception.courseId] ?? exception.courseId,
      sourceMeetingId: exception.sourceMeetingId == null
          ? null
          : ruleIdRemap[exception.sourceMeetingId] ?? exception.sourceMeetingId,
      sourceDate: exception.sourceDate,
      type: exception.type,
      targetDate: exception.targetDate,
      targetStartSection: exception.targetStartSection,
      targetEndSection: exception.targetEndSection,
      teacherOverride: exception.teacherOverride,
      campusOverride: exception.campusOverride,
      roomOverride: exception.roomOverride,
      addedCourseName: exception.addedCourseName,
      note: exception.note,
    );
  }
}
