import '../course/course.dart';
import '../course/course_identity.dart';
import '../course/meeting_rule.dart';
import 'timetable_import.dart';

/// Matches imported courses and meetings across snapshots when the source
/// system has not supplied a stable opaque identifier.
///
/// Course identity is the normalized name. Meeting structure is used only to
/// reconcile arrangements after a course has been identified.
class ImportIdentityMatcher {
  const ImportIdentityMatcher();

  Course? matchLocalCourse(
    ImportedCourse remote,
    Iterable<Course> candidates,
    Map<String, List<MeetingRule>> localRules,
  ) {
    final matches = candidates
        .where(
          (candidate) => CourseIdentity.sameName(candidate.name, remote.name),
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  ImportedCourse? matchPreviousCourse(
    ImportedCourse remote,
    Iterable<ImportedCourse> candidates,
  ) {
    final matches = candidates
        .where(
          (candidate) => CourseIdentity.sameName(candidate.name, remote.name),
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
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
    //
    // Use a one-to-one assignment instead of taking the best candidate for
    // each remote meeting in input order. A greedy pass can consume a local
    // meeting that is also the only viable match for a later remote meeting,
    // making a valid multi-meeting course look only partially compatible.
    final pairScores = [
      for (final remoteMeeting in remote)
        [
          for (final candidate in local)
            _courseMeetingMatchScore(remoteMeeting, candidate),
        ],
    ];
    final weights = [
      for (final row in pairScores)
        [
          for (final score in row)
            score == null ? _unavailableWeight : 100 + score,
          // Each remote meeting gets a private zero-weight column so a
          // genuinely added meeting can remain unmatched.
          ...List<int>.filled(remote.length, 0),
        ],
    ];
    final assignment = _maximumAssignment(weights);
    if (!assignment.columns.any(
      (column) => column >= 0 && column < local.length,
    )) {
      return null;
    }

    // Multiple dummy columns are intentionally interchangeable. Only test
    // real local edges for an equally-scored alternative mapping.
    for (var row = 0; row < assignment.columns.length; row++) {
      final column = assignment.columns[row];
      if (column < 0 || column >= local.length) continue;
      final alternative = _maximumAssignment(
        weights,
        blockedRow: row,
        blockedColumn: column,
      );
      if (alternative.score == assignment.score) return null;
    }
    return assignment.score + (remote.length == local.length ? 1 : 0);
  }

  /// Returns null when the remote meeting cannot be matched unambiguously.
  /// Structural anchors are required; teacher, campus and room only refine
  /// the score and are intentionally not identity fields.
  static int? meetingMatchScore(ImportedMeeting remote, Object candidate) {
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
    final structuralAnchors = [
      sameWeekday,
      sameSections,
      sameWeeks,
    ].where((value) => value).length;
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

  static int? _courseMeetingMatchScore(
    ImportedMeeting remote,
    Object candidate,
  ) {
    // A unique source meeting key is a stronger identity signal than a
    // changed schedule shape. It is still scoped to the already matched
    // course, and duplicate keys remain ambiguous in the assignment search.
    if (_sourceMeetingKey(candidate) == remote.sourceMeetingKey) return 1000;
    return meetingMatchScore(remote, candidate);
  }

  static const _unavailableWeight = -1073741824;

  /// Returns the maximum-weight assignment for rows <= columns. Invalid
  /// meeting pairs use [_unavailableWeight] and are never selected because
  /// every row has an additional zero-weight dummy column.
  static ({int score, List<int> columns}) _maximumAssignment(
    List<List<int>> weights, {
    int? blockedRow,
    int? blockedColumn,
  }) {
    final rowCount = weights.length;
    final columnCount = weights.isEmpty ? 0 : weights.first.length;
    if (rowCount == 0 || columnCount < rowCount) {
      return (score: 0, columns: List<int>.filled(rowCount, -1));
    }

    // Hungarian algorithm for minimum-cost assignment, with negated weights.
    final u = List<int>.filled(rowCount + 1, 0);
    final v = List<int>.filled(columnCount + 1, 0);
    final parent = List<int>.filled(columnCount + 1, 0);
    final way = List<int>.filled(columnCount + 1, 0);
    const infinity = 1 << 60;

    for (var row = 1; row <= rowCount; row++) {
      parent[0] = row;
      var column0 = 0;
      final minimum = List<int>.filled(columnCount + 1, infinity);
      final used = List<bool>.filled(columnCount + 1, false);
      do {
        used[column0] = true;
        final row0 = parent[column0];
        var delta = infinity;
        var column1 = 0;
        for (var column = 1; column <= columnCount; column++) {
          if (used[column]) continue;
          final blocked = row0 - 1 == blockedRow && column - 1 == blockedColumn;
          final weight =
              blocked ? _unavailableWeight : weights[row0 - 1][column - 1];
          final current = -weight - u[row0] - v[column];
          if (current < minimum[column]) {
            minimum[column] = current;
            way[column] = column0;
          }
          if (minimum[column] < delta) {
            delta = minimum[column];
            column1 = column;
          }
        }
        for (var column = 0; column <= columnCount; column++) {
          if (used[column]) {
            u[parent[column]] += delta;
            v[column] -= delta;
          } else {
            minimum[column] -= delta;
          }
        }
        column0 = column1;
      } while (parent[column0] != 0);

      do {
        final previous = way[column0];
        parent[column0] = parent[previous];
        column0 = previous;
      } while (column0 != 0);
    }

    final columns = List<int>.filled(rowCount, -1);
    for (var column = 1; column <= columnCount; column++) {
      final row = parent[column];
      if (row != 0) columns[row - 1] = column - 1;
    }
    var score = 0;
    for (var row = 0; row < rowCount; row++) {
      final column = columns[row];
      if (column >= 0) score += weights[row][column];
    }
    return (score: score, columns: columns);
  }

  static String? _sourceMeetingKey(Object candidate) => switch (candidate) {
        MeetingRule value => value.sourceMeetingKey,
        ImportedMeeting value => value.sourceMeetingKey,
        _ => null,
      };

  static bool _sameMeetingText(String? left, String? right) =>
      (left ?? '').trim() == (right ?? '').trim();
}
