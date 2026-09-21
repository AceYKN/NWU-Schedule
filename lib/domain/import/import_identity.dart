import '../course/course.dart';
import '../course/meeting_rule.dart';
import 'timetable_import.dart';

/// Matches imported courses and meetings across snapshots when the source
/// system has not supplied a stable opaque identifier.
///
/// The fallback deliberately uses the course name and recurring meeting
/// shape. It does not use display metadata such as course code, teaching
/// class, credits, assessment, teacher, or room as identity. Meeting
/// properties may still contribute to a match score as tie-breakers; they do
/// not become part of the identity persisted by the importer.
class ImportIdentityMatcher {
  const ImportIdentityMatcher();

  Course? matchLocalCourse(
    ImportedCourse remote,
    Iterable<Course> candidates,
    Map<String, List<MeetingRule>> localRules,
  ) {
    final matches = <({Course course, int score})>[];
    for (final candidate in candidates) {
      if (!_sameCourseName(candidate.name, remote.name)) continue;
      final score = courseShapeScore(
        remote.meetings,
        localRules[candidate.id] ?? const [],
      );
      if (score != null) matches.add((course: candidate, score: score));
    }
    return _uniqueBest(matches);
  }

  ImportedCourse? matchPreviousCourse(
    ImportedCourse remote,
    Iterable<ImportedCourse> candidates,
  ) {
    final matches = <({ImportedCourse course, int score})>[];
    for (final candidate in candidates) {
      if (!_sameCourseName(candidate.name, remote.name)) continue;
      final score = courseShapeScore(remote.meetings, candidate.meetings);
      if (score != null) matches.add((course: candidate, score: score));
    }
    return _uniqueBest(matches);
  }

  /// Matches a meeting by its source key first, then by an unambiguous
  /// structural/property score. Callers remove a selected candidate from the
  /// remaining collection after this method returns.
  T? matchMeeting<T extends Object>(
    ImportedMeeting remote,
    Iterable<T> candidates,
  ) {
    final available = candidates.toList(growable: false);
    final exact = available
        .where(
          (candidate) =>
              _sourceMeetingKey(candidate) == remote.sourceMeetingKey,
        )
        .toList(growable: false);
    if (exact.length == 1) return exact.single;
    if (exact.length > 1) return null;

    final scored = <({T candidate, int score})>[];
    for (final candidate in available) {
      final score = meetingMatchScore(remote, candidate);
      if (score != null) scored.add((candidate: candidate, score: score));
    }
    scored.sort((left, right) => right.score.compareTo(left.score));
    if (scored.isEmpty ||
        (scored.length > 1 && scored[0].score == scored[1].score)) {
      return null;
    }
    return scored.first.candidate;
  }

  /// Scores the stable recurring shape of a course, independent of mutable
  /// display properties.
  static int? courseShapeScore(
    List<ImportedMeeting> remote,
    List<Object> local,
  ) {
    if (remote.isEmpty || local.isEmpty) return null;

    // A course-level match is valid only when at least one meeting has a
    // unique schedule-structure match. This prevents a same-name course with
    // a completely different timetable from being silently merged merely
    // because it is the only same-name candidate.
    final unmatched = [...local];
    var matchedCount = 0;
    var totalScore = 0;
    for (final remoteMeeting in remote) {
      final scored = <({Object candidate, int score})>[];
      for (final candidate in unmatched) {
        final score = meetingMatchScore(remoteMeeting, candidate);
        if (score != null) {
          scored.add((candidate: candidate, score: score));
        }
      }
      if (scored.isEmpty) continue;
      scored.sort((left, right) => right.score.compareTo(left.score));
      if (scored.length > 1 && scored[0].score == scored[1].score) {
        return null;
      }
      final best = scored.first;
      unmatched.remove(best.candidate);
      matchedCount++;
      totalScore += best.score;
    }
    if (matchedCount == 0) return null;
    return matchedCount * 100 +
        totalScore +
        (remote.length == local.length ? 1 : 0);
  }

  /// Returns null when the remote meeting cannot be matched unambiguously.
  /// Structural anchors are required; teacher, campus and room only refine
  /// the score and are intentionally not identity fields.
  static int? meetingMatchScore(
    ImportedMeeting remote,
    Object candidate,
  ) {
    final weekday = switch (candidate) {
      MeetingRule value => value.weekday,
      ImportedMeeting value => value.weekday,
      _ => null,
    };
    final startSection = switch (candidate) {
      MeetingRule value => value.startSection,
      ImportedMeeting value => value.startSection,
      _ => null,
    };
    final endSection = switch (candidate) {
      MeetingRule value => value.endSection,
      ImportedMeeting value => value.endSection,
      _ => null,
    };
    final weekMask = switch (candidate) {
      MeetingRule value => value.weekMask,
      ImportedMeeting value => value.weekMask,
      _ => null,
    };
    final teacher = switch (candidate) {
      MeetingRule value => value.teacher,
      ImportedMeeting value => value.teacher,
      _ => null,
    };
    final campus = switch (candidate) {
      MeetingRule value => value.campus,
      ImportedMeeting value => value.campus,
      _ => null,
    };
    final room = switch (candidate) {
      MeetingRule value => value.room,
      ImportedMeeting value => value.room,
      _ => null,
    };
    if (weekday == null ||
        startSection == null ||
        endSection == null ||
        weekMask == null) {
      return null;
    }
    final sameWeekday = weekday == remote.weekday;
    final sameSections =
        startSection == remote.startSection && endSection == remote.endSection;
    final sameWeeks = weekMask.value == remote.weekMask.value;
    final structuralAnchors =
        [sameWeekday, sameSections, sameWeeks].where((value) => value).length;
    if (structuralAnchors == 0) return null;
    final sameTeacher = _sameMeetingText(teacher, remote.teacher);
    final sameCampus = _sameMeetingText(campus, remote.campus);
    final sameRoom = _sameMeetingText(room, remote.room);
    final anchors = [
      sameWeekday,
      sameSections,
      sameWeeks,
      sameTeacher,
      sameCampus,
      sameRoom,
    ].where((value) => value).length;
    if (anchors < 2) return null;
    var score = 0;
    if (sameWeekday) score += 8;
    if (sameSections) {
      score += 6;
    } else if (startSection == remote.startSection ||
        endSection == remote.endSection) {
      score += 2;
    }
    if (sameWeeks) {
      score += 5;
    } else if ((weekMask.value & remote.weekMask.value) != 0) {
      score += 1;
    }
    if (sameTeacher) score += 3;
    if (sameCampus) score += 2;
    if (sameRoom) score += 3;
    return score;
  }

  static T? _uniqueBest<T extends Object>(
    List<({T course, int score})> matches,
  ) {
    if (matches.isEmpty) return null;
    matches.sort((left, right) => right.score.compareTo(left.score));
    if (matches.length > 1 && matches[0].score == matches[1].score) {
      return null;
    }
    return matches.first.course;
  }

  static bool _sameCourseName(String left, String right) =>
      _normalizeText(left) == _normalizeText(right);

  static String? _sourceMeetingKey(Object candidate) => switch (candidate) {
        MeetingRule value => value.sourceMeetingKey,
        ImportedMeeting value => value.sourceMeetingKey,
        _ => null,
      };

  static String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  static bool _sameMeetingText(String? left, String? right) =>
      (left ?? '').trim() == (right ?? '').trim();
}
