import 'dart:convert';

import '../course/course.dart';
import '../course/course_identity.dart';
import '../course/meeting_rule.dart';
import '../schedule/schedule_data_repository.dart';
import 'import_identity.dart';
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

  bool get hasChanges =>
      changes.any((change) => change.kind != ImportChangeKind.unchanged);

  bool get hasConflicts => changes.any((change) => change.hasConflict);

  bool get hasLocallyDeleted =>
      changes.any((change) => change.kind == ImportChangeKind.locallyDeleted);

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

  static const _identityMatcher = ImportIdentityMatcher();

  ImportDiff build({
    required RemoteTimetable incoming,
    required ScheduleDataSnapshot? local,
    required RemoteTimetable? previousImport,
    Set<String> deletedSourceCourseKeys = const {},
  }) {
    final localImported = <String, Course>{};
    final localRules = <String, List<MeetingRule>>{};
    for (final course in local?.courses ?? const <Course>[]) {
      if (course.sourceType == CourseSourceType.imported &&
          course.sourceCourseKey != null) {
        localImported[course.sourceCourseKey!] = course;
      }
      localRules[course.id] = [
        for (final rule in local?.meetingRules ?? const <MeetingRule>[])
          if (rule.courseId == course.id) rule,
      ];
    }
    final previousByKey = {
      for (final course in previousImport?.courses ?? const <ImportedCourse>[])
        course.sourceCourseKey: course,
    };
    final matchedLocalCourseIds = <String>{};
    final matchedPreviousKeys = <String>{};
    final changes = <ImportChange>[];

    for (final remote in incoming.courses) {
      var localCourse = localImported[remote.sourceCourseKey];
      if (localCourse != null &&
          matchedLocalCourseIds.contains(localCourse.id)) {
        localCourse = null;
      }
      localCourse ??= _identityMatcher.matchLocalCourse(
        remote,
        (local?.courses ?? const <Course>[]).where(
          (course) => !matchedLocalCourseIds.contains(course.id),
        ),
        localRules,
      );
      if (localCourse == null) {
        changes.add(
          ImportChange(
            kind: deletedSourceCourseKeys.contains(remote.sourceCourseKey)
                ? ImportChangeKind.locallyDeleted
                : ImportChangeKind.added,
            sourceCourseKey: remote.sourceCourseKey,
            remoteCourse: remote,
          ),
        );
        continue;
      }
      matchedLocalCourseIds.add(localCourse.id);
      // A tombstone without a matching local course is handled above. Once a
      // live course has been matched, its deleted flag is authoritative; a
      // stale tombstone must not silently delete the live row again.
      if (localCourse.deleted) {
        changes.add(
          ImportChange(
            kind: ImportChangeKind.locallyDeleted,
            sourceCourseKey: remote.sourceCourseKey,
            localCourse: localCourse,
            remoteCourse: remote,
          ),
        );
        continue;
      }
      var previous = previousByKey[remote.sourceCourseKey];
      if (previous != null &&
          matchedPreviousKeys.contains(previous.sourceCourseKey)) {
        previous = null;
      }
      previous ??= _identityMatcher.matchPreviousCourse(
        remote,
        (previousImport?.courses ?? const <ImportedCourse>[]).where(
          (course) => !matchedPreviousKeys.contains(course.sourceCourseKey),
        ),
      );
      if (previous != null) matchedPreviousKeys.add(previous.sourceCourseKey);
      final fields = _fields(
        localCourse: localCourse,
        localRules: (localRules[localCourse.id] ?? const [])
            .where((rule) => rule.sourceMeetingKey != null)
            .toList(growable: false),
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
      changes.add(
        ImportChange(
          kind: conflict
              ? ImportChangeKind.conflict
              : changed
                  ? ImportChangeKind.modified
                  : ImportChangeKind.unchanged,
          sourceCourseKey: remote.sourceCourseKey,
          localCourse: localCourse,
          remoteCourse: remote,
          fields: fields,
        ),
      );
    }

    for (final localCourse in localImported.values) {
      final key = localCourse.sourceCourseKey!;
      if (matchedLocalCourseIds.contains(localCourse.id) ||
          localCourse.deleted) {
        continue;
      }
      changes.add(
        ImportChange(
          kind: ImportChangeKind.removed,
          sourceCourseKey: key,
          localCourse: localCourse,
        ),
      );
    }

    for (final change in changes) {
      // Keep the preview deterministic and easy to inspect.
      if (change.remoteCourse == null && change.localCourse == null) {
        throw StateError('Import diff item has no local or remote course');
      }
    }
    return ImportDiff(List.unmodifiable(changes), isNewSemester: local == null);
  }

  List<ImportFieldChange> _fields({
    required Course localCourse,
    required List<MeetingRule> localRules,
    required ImportedCourse? previous,
    required ImportedCourse remote,
  }) {
    final fields = <ImportFieldChange>[];
    if (!CourseIdentity.sameName(localCourse.name, remote.name)) {
      fields.add(
        _mergeField(
          field: 'name',
          previousValue: previous?.name,
          localValue: localCourse.name,
          remoteValue: remote.name,
        ),
      );
    }

    final unmatchedLocal = [...localRules];
    final unmatchedPrevious = [...?previous?.meetings];

    for (final remoteMeeting in remote.meetings) {
      final localMeeting = _takeLocalMeeting(remoteMeeting, unmatchedLocal);
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
    if (previous != null && !_same(localTopology, remoteTopology)) {
      fields.add(
        _mergeField(
          field: 'meetings',
          previousValue: _meetingTopology(previous.meetings),
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
        .where(
          (candidate) => candidate.sourceMeetingKey == remote.sourceMeetingKey,
        )
        .toList();
    final matched = switch (exact.length) {
      0 => _identityMatcher.matchMeeting<MeetingRule>(remote, candidates),
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
        .where(
          (candidate) => candidate.sourceMeetingKey == remote.sourceMeetingKey,
        )
        .toList();
    final matched = switch (exact.length) {
      0 => _identityMatcher.matchMeeting<ImportedMeeting>(remote, candidates),
      1 => exact.single,
      _ => null,
    };
    if (matched == null) return null;
    candidates.remove(matched);
    return matched;
  }

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
