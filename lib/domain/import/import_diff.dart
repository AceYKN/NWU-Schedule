import 'dart:convert';

import '../course/course.dart';
import '../course/meeting_rule.dart';
import '../schedule/schedule_data_repository.dart';
import 'timetable_import.dart';
import 'three_way_merge.dart';

/// Stable key used by the diff UI and repository when a single imported
/// meeting property needs an independent three-way merge decision.
String meetingImportField(String sourceMeetingKey, String property) =>
    'meeting:$sourceMeetingKey:$property';

enum ImportChangeKind {
  unchanged,
  added,
  removed,
  modified,
  conflict,
  locallyDeleted,
}

class ImportFieldChange {
  const ImportFieldChange({
    required this.field,
    required this.decision,
    required this.localValue,
    required this.remoteValue,
  });

  final String field;
  final MergeDecision decision;
  final Object? localValue;
  final Object? remoteValue;

  bool get hasConflict => decision == MergeDecision.conflict;
}

class ImportChange {
  const ImportChange({
    required this.kind,
    required this.sourceCourseKey,
    this.localCourse,
    this.remoteCourse,
    this.fields = const [],
  });

  final ImportChangeKind kind;
  final String sourceCourseKey;
  final Course? localCourse;
  final ImportedCourse? remoteCourse;
  final List<ImportFieldChange> fields;

  bool get hasConflict => fields.any((field) => field.hasConflict);
}

class ImportDiff {
  const ImportDiff(this.changes, {this.isNewSemester = false});

  final List<ImportChange> changes;
  final bool isNewSemester;

  bool get hasChanges => changes.any(
        (change) => change.kind != ImportChangeKind.unchanged,
      );

  bool get hasConflicts => changes.any((change) => change.hasConflict);

  bool get hasLocallyDeleted => changes.any(
        (change) => change.kind == ImportChangeKind.locallyDeleted,
      );

  int get locallyDeletedCount => changes
      .where((change) => change.kind == ImportChangeKind.locallyDeleted)
      .length;

  int get addedCount =>
      changes.where((change) => change.kind == ImportChangeKind.added).length;

  int get removedCount =>
      changes.where((change) => change.kind == ImportChangeKind.removed).length;

  int get modifiedCount => changes
      .where((change) => change.kind == ImportChangeKind.modified)
      .length;

  int get conflictCount => changes.where((change) => change.hasConflict).length;

  ImportDiff resolve(ImportConflictResolution resolution) {
    if (!hasConflicts && !hasLocallyDeleted) return this;
    return ImportDiff([
      for (final change in changes) _resolveChange(change, resolution),
    ], isNewSemester: isNewSemester);
  }

  static ImportChange _resolveChange(
    ImportChange change,
    ImportConflictResolution resolution,
  ) {
    if (change.kind == ImportChangeKind.locallyDeleted &&
        resolution.shouldRestore(change.sourceCourseKey)) {
      return ImportChange(
        kind: ImportChangeKind.added,
        sourceCourseKey: change.sourceCourseKey,
        localCourse: change.localCourse,
        remoteCourse: change.remoteCourse,
      );
    }
    if (!change.hasConflict) return change;
    final fields = [
      for (final field in change.fields)
        ImportFieldChange(
          field: field.field,
          decision: field.hasConflict
              ? resolution.choiceFor(change.sourceCourseKey, field.field) ??
                  field.decision
              : field.decision,
          localValue: field.localValue,
          remoteValue: field.remoteValue,
        ),
    ];
    final hasConflict = fields.any((field) => field.hasConflict);
    final changed = fields.any(
      (field) =>
          field.decision != MergeDecision.local ||
          !_sameImportValue(field.localValue, field.remoteValue),
    );
    return ImportChange(
      kind: hasConflict
          ? ImportChangeKind.conflict
          : changed
              ? ImportChangeKind.modified
              : ImportChangeKind.unchanged,
      sourceCourseKey: change.sourceCourseKey,
      localCourse: change.localCourse,
      remoteCourse: change.remoteCourse,
      fields: fields,
    );
  }
}

class ImportConflictResolution {
  const ImportConflictResolution({
    required this.choices,
    this.restoreDeletedCourseKeys = const {},
  });

  factory ImportConflictResolution.copy(
    Map<String, Map<String, MergeDecision>> choices, {
    Set<String> restoreDeletedCourseKeys = const {},
  }) {
    return ImportConflictResolution(
      choices: {
        for (final entry in choices.entries)
          entry.key: Map<String, MergeDecision>.from(entry.value),
      },
      restoreDeletedCourseKeys: restoreDeletedCourseKeys,
    );
  }

  static const empty = ImportConflictResolution(choices: {});

  final Map<String, Map<String, MergeDecision>> choices;
  final Set<String> restoreDeletedCourseKeys;

  MergeDecision? choiceFor(String sourceCourseKey, String field) =>
      choices[sourceCourseKey]?[field];

  bool shouldRestore(String sourceCourseKey) =>
      restoreDeletedCourseKeys.contains(sourceCourseKey);
}

class ImportDiffEngine {
  const ImportDiffEngine();

  ImportDiff build({
    required RemoteTimetable incoming,
    required ScheduleDataSnapshot? local,
    required RemoteTimetable? previousImport,
    Set<String> deletedSourceCourseKeys = const {},
  }) {
    final localImported = <String, Course>{};
    final localRules = <String, List<MeetingRule>>{};
    for (final course in local?.courses ?? const <Course>[]) {
      if (course.sourceType != CourseSourceType.imported ||
          course.sourceCourseKey == null) {
        continue;
      }
      localImported[course.sourceCourseKey!] = course;
      localRules[course.id] = [
        for (final rule in local?.meetingRules ?? const <MeetingRule>[])
          if (rule.courseId == course.id) rule,
      ];
    }
    final previousByKey = {
      for (final course in previousImport?.courses ?? const <ImportedCourse>[])
        course.sourceCourseKey: course,
    };
    final matchedLocalKeys = <String>{};
    final matchedPreviousKeys = <String>{};
    final changes = <ImportChange>[];

    for (final remote in incoming.courses) {
      var localCourse = localImported[remote.sourceCourseKey];
      if (localCourse != null &&
          matchedLocalKeys.contains(localCourse.sourceCourseKey)) {
        localCourse = null;
      }
      localCourse ??= _uniqueLocalStructuralMatch(
        remote,
        localImported.values.where(
          (course) =>
              course.sourceCourseKey != null &&
              !matchedLocalKeys.contains(course.sourceCourseKey),
        ),
        localRules,
      );
      if (localCourse == null) {
        changes.add(ImportChange(
          kind: deletedSourceCourseKeys.contains(remote.sourceCourseKey)
              ? ImportChangeKind.locallyDeleted
              : ImportChangeKind.added,
          sourceCourseKey: remote.sourceCourseKey,
          remoteCourse: remote,
        ));
        continue;
      }
      matchedLocalKeys.add(localCourse.sourceCourseKey!);
      // A tombstone without a matching local course is handled above. Once a
      // live course has been matched, its deleted flag is authoritative; a
      // stale tombstone must not silently delete the live row again.
      if (localCourse.deleted) {
        changes.add(ImportChange(
          kind: ImportChangeKind.locallyDeleted,
          sourceCourseKey: remote.sourceCourseKey,
          localCourse: localCourse,
          remoteCourse: remote,
        ));
        continue;
      }
      var previous = previousByKey[remote.sourceCourseKey];
      if (previous != null &&
          matchedPreviousKeys.contains(previous.sourceCourseKey)) {
        previous = null;
      }
      previous ??= _uniquePreviousStructuralMatch(
        remote,
        (previousImport?.courses ?? const <ImportedCourse>[]).where(
          (course) => !matchedPreviousKeys.contains(course.sourceCourseKey),
        ),
      );
      if (previous != null) matchedPreviousKeys.add(previous.sourceCourseKey);
      final fields = _fields(
        localCourse: localCourse,
        localRules: localRules[localCourse.id] ?? const [],
        previous: previous,
        remote: remote,
      );
      final conflict = fields.any((field) => field.hasConflict);
      final sourceKeyChanged =
          localCourse.sourceCourseKey != remote.sourceCourseKey;
      final changed = fields.any(
            (field) =>
                field.decision != MergeDecision.local ||
                !_same(field.localValue, field.remoteValue),
          ) ||
          sourceKeyChanged;
      changes.add(ImportChange(
        kind: conflict
            ? ImportChangeKind.conflict
            : changed
                ? ImportChangeKind.modified
                : ImportChangeKind.unchanged,
        sourceCourseKey: remote.sourceCourseKey,
        localCourse: localCourse,
        remoteCourse: remote,
        fields: fields,
      ));
    }

    for (final localCourse in localImported.values) {
      final key = localCourse.sourceCourseKey!;
      if (matchedLocalKeys.contains(key) || localCourse.deleted) continue;
      changes.add(ImportChange(
        kind: ImportChangeKind.removed,
        sourceCourseKey: key,
        localCourse: localCourse,
      ));
    }

    for (final change in changes) {
      // Keep the preview deterministic and easy to inspect.
      if (change.remoteCourse == null && change.localCourse == null) {
        throw StateError('Import diff item has no local or remote course');
      }
    }
    return ImportDiff(
      List.unmodifiable(changes),
      isNewSemester: local == null,
    );
  }

  Course? _uniqueLocalStructuralMatch(
    ImportedCourse remote,
    Iterable<Course> candidates,
    Map<String, List<MeetingRule>> localRules,
  ) {
    final matches = [
      for (final candidate in candidates)
        if (_sameCourseName(candidate.name, remote.name))
          (
            course: candidate,
            score: _courseShapeScore(
              remote.meetings,
              localRules[candidate.id] ?? const [],
            ),
          ),
    ];
    return _uniqueBest(matches);
  }

  ImportedCourse? _uniquePreviousStructuralMatch(
    ImportedCourse remote,
    Iterable<ImportedCourse> candidates,
  ) {
    final matches = [
      for (final candidate in candidates)
        if (_sameCourseName(candidate.name, remote.name))
          (
            course: candidate,
            score: _courseShapeScore(
              remote.meetings,
              candidate.meetings,
            ),
          ),
    ];
    return _uniqueBest(matches);
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

  static int _courseShapeScore(
    List<ImportedMeeting> remote,
    List<Object> local,
  ) {
    final remoteShapes = remote.map(_remoteShape).toSet();
    final localShapes = local.map(_shape).toSet();
    final overlap = remoteShapes.intersection(localShapes).length;
    final sameWeekdays = remote
        .map((item) => item.weekday)
        .toSet()
        .intersection(
          local.map(_weekday).toSet(),
        )
        .length;
    final sameCount = remote.length == local.length ? 1 : 0;
    return overlap * 100 + sameWeekdays * 10 + sameCount;
  }

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

  List<ImportFieldChange> _fields({
    required Course localCourse,
    required List<MeetingRule> localRules,
    required ImportedCourse? previous,
    required ImportedCourse remote,
  }) {
    final fields = <ImportFieldChange>[
      _mergeField(
        field: 'name',
        previousValue: previous?.name,
        localValue: localCourse.name,
        remoteValue: remote.name,
      ),
    ];

    final unmatchedLocal = [...localRules];
    final unmatchedPrevious = [...?previous?.meetings];

    for (final remoteMeeting in remote.meetings) {
      final localMeeting = _takeLocalMeeting(
        remoteMeeting,
        unmatchedLocal,
      );
      final previousMeeting = _takePreviousMeeting(
        remoteMeeting,
        unmatchedPrevious,
      );

      // A meeting that is only being added/removed is represented by the
      // topology field below. There is no meaningful per-property conflict
      // until both sides identify the same logical meeting.
      if (localMeeting == null || previousMeeting == null) continue;
      for (final property in _meetingProperties) {
        fields.add(
          _mergeField(
            field: meetingImportField(remoteMeeting.sourceMeetingKey, property),
            previousValue: _meetingProperty(previousMeeting, property),
            localValue: _meetingProperty(localMeeting, property),
            remoteValue: _meetingProperty(remoteMeeting, property),
          ),
        );
      }
    }

    final localTopology = _meetingTopology(localRules);
    final remoteTopology = _meetingTopology(remote.meetings);
    if (!_same(localTopology, remoteTopology)) {
      fields.add(
        _mergeField(
          field: 'meetings',
          previousValue:
              previous == null ? null : _meetingTopology(previous.meetings),
          localValue: localTopology,
          remoteValue: remoteTopology,
        ),
      );
    }
    return fields;
  }

  static const _meetingProperties = [
    'weekday',
    'startSection',
    'endSection',
    'weekMask',
    'teacher',
    'campus',
    'room',
  ];

  MeetingRule? _takeLocalMeeting(
    ImportedMeeting remote,
    List<MeetingRule> candidates,
  ) {
    final exact = candidates
        .where((candidate) =>
            candidate.sourceMeetingKey == remote.sourceMeetingKey)
        .toList();
    final matched = switch (exact.length) {
      0 => _uniqueMeetingMatch<MeetingRule>(remote, candidates),
      1 => exact.single,
      _ => null,
    };
    if (matched == null) return null;
    candidates.remove(matched);
    return matched;
  }

  ImportedMeeting? _takePreviousMeeting(
    ImportedMeeting remote,
    List<ImportedMeeting> candidates,
  ) {
    final exact = candidates
        .where((candidate) =>
            candidate.sourceMeetingKey == remote.sourceMeetingKey)
        .toList();
    final matched = switch (exact.length) {
      0 => _uniqueMeetingMatch<ImportedMeeting>(remote, candidates),
      1 => exact.single,
      _ => null,
    };
    if (matched == null) return null;
    candidates.remove(matched);
    return matched;
  }

  T? _uniqueMeetingMatch<T extends Object>(
    ImportedMeeting remote,
    Iterable<T> candidates,
  ) {
    final scored = <({T candidate, int score})>[];
    for (final candidate in candidates) {
      final score = _meetingMatchScore(remote, candidate);
      if (score != null) scored.add((candidate: candidate, score: score));
    }
    scored.sort((left, right) => right.score.compareTo(left.score));
    if (scored.isEmpty ||
        (scored.length > 1 && scored[0].score == scored[1].score)) {
      return null;
    }
    return scored.first.candidate;
  }

  static int? _meetingMatchScore(
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

  static bool _sameMeetingText(String? left, String? right) =>
      (left ?? '').trim() == (right ?? '').trim();

  static Object? _meetingProperty(Object meeting, String property) {
    return switch (meeting) {
      MeetingRule value => switch (property) {
          'weekday' => value.weekday,
          'startSection' => value.startSection,
          'endSection' => value.endSection,
          'weekMask' => value.weekMask.value,
          'teacher' => value.teacher,
          'campus' => value.campus,
          'room' => value.room,
          _ => null,
        },
      ImportedMeeting value => switch (property) {
          'weekday' => value.weekday,
          'startSection' => value.startSection,
          'endSection' => value.endSection,
          'weekMask' => value.weekMask.value,
          'teacher' => value.teacher,
          'campus' => value.campus,
          'room' => value.room,
          _ => null,
        },
      _ => null,
    };
  }

  static List<Object?> _meetingTopology(Iterable<Object> meetings) {
    final result = [
      for (final meeting in meetings)
        [
          _meetingProperty(meeting, 'weekday'),
          _meetingProperty(meeting, 'startSection'),
          _meetingProperty(meeting, 'endSection'),
          _meetingProperty(meeting, 'weekMask'),
        ],
    ];
    result.sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
    return result;
  }

  ImportFieldChange _mergeField({
    required String field,
    required Object? previousValue,
    required Object? localValue,
    required Object? remoteValue,
  }) {
    final result = mergeField<String>(
      previousImport: _canonical(previousValue),
      local: _canonical(localValue),
      incomingImport: _canonical(remoteValue),
    );
    return ImportFieldChange(
      field: field,
      decision: result.decision,
      localValue: localValue,
      remoteValue: remoteValue,
    );
  }

  static bool _same(Object? left, Object? right) =>
      _sameImportValue(left, right);

  static String _canonical(Object? value) => jsonEncode(value);
}

bool _sameImportValue(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);
