import 'dart:convert';

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
    final matches = [
      for (final candidate in candidates)
        if (_sameCourseName(candidate.name, remote.name))
          (
            course: candidate,
            score: courseShapeScore(
              remote.meetings,
              localRules[candidate.id] ?? const [],
            ),
          ),
    ];
    return _uniqueBest(matches);
  }

  ImportedCourse? matchPreviousCourse(
    ImportedCourse remote,
    Iterable<ImportedCourse> candidates,
  ) {
    final matches = [
      for (final candidate in candidates)
        if (_sameCourseName(candidate.name, remote.name))
          (
            course: candidate,
            score: courseShapeScore(remote.meetings, candidate.meetings),
          ),
    ];
    return _uniqueBest(matches);
  }

  /// Matches a meeting by its source key first, then by an unambiguous
  /// structural/property score. Callers remove a selected candidate from the
  /// remaining collection after this method returns.
  T? matchMeeting<T extends Object>(
    ImportedMeeting remote,
    Iterable<T> candidates,
  ) {
    final scored = <({T candidate, int score})>[];
    for (final candidate in candidates) {
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
  static int courseShapeScore(
    List<ImportedMeeting> remote,
    List<Object> local,
  ) {
    final remoteShapes = remote.map(_remoteShape).toSet();
    final localShapes = local.map(_shape).toSet();
    final overlap = remoteShapes.intersection(localShapes).length;
    final sameWeekdays = remote
        .map((item) => item.weekday)
        .toSet()
        .intersection(local.map(_weekday).toSet())
        .length;
    final sameCount = remote.length == local.length ? 1 : 0;
    return overlap * 100 + sameWeekdays * 10 + sameCount;
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
    // A name-only match is safe only when it is the sole local candidate.
    // If several same-name courses exist, require a structural anchor.
    if (matches.length > 1 && matches.first.score == 0) return null;
    return matches.first.course;
  }

  static bool _sameCourseName(String left, String right) =>
      _normalizeText(left) == _normalizeText(right);

  static String _remoteShape(ImportedMeeting meeting) => jsonEncode([
        meeting.weekday,
        meeting.startSection,
        meeting.endSection,
        meeting.weekMask.value,
      ]);

  static String _shape(Object meeting) => switch (meeting) {
        MeetingRule value => jsonEncode([
            value.weekday,
            value.startSection,
            value.endSection,
            value.weekMask.value,
          ]),
        ImportedMeeting value => _remoteShape(value),
        _ => throw ArgumentError('Unsupported meeting shape'),
      };

  static int _weekday(Object meeting) => switch (meeting) {
        MeetingRule value => value.weekday,
        ImportedMeeting value => value.weekday,
        _ => throw ArgumentError('Unsupported meeting weekday'),
      };

  static String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  static bool _sameMeetingText(String? left, String? right) =>
      (left ?? '').trim() == (right ?? '').trim();
}
