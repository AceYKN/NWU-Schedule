import 'dart:convert';

import '../course/course.dart';
import '../course/meeting_rule.dart';
import '../schedule/schedule_data_repository.dart';
import 'timetable_import.dart';
import 'three_way_merge.dart';

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
  const ImportDiff(this.changes);

  final List<ImportChange> changes;

  bool get hasChanges => changes.any(
        (change) => change.kind != ImportChangeKind.unchanged,
      );

  bool get hasConflicts => changes.any((change) => change.hasConflict);

  int get addedCount =>
      changes.where((change) => change.kind == ImportChangeKind.added).length;

  int get removedCount =>
      changes.where((change) => change.kind == ImportChangeKind.removed).length;

  int get modifiedCount => changes
      .where((change) => change.kind == ImportChangeKind.modified)
      .length;
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
    final remoteByKey = {
      for (final course in incoming.courses) course.sourceCourseKey: course,
    };
    final previousByKey = {
      for (final course in previousImport?.courses ?? const <ImportedCourse>[])
        course.sourceCourseKey: course,
    };
    final changes = <ImportChange>[];

    for (final remote in incoming.courses) {
      final localCourse = localImported[remote.sourceCourseKey];
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
      if (deletedSourceCourseKeys.contains(remote.sourceCourseKey) ||
          localCourse.deleted) {
        changes.add(ImportChange(
          kind: ImportChangeKind.locallyDeleted,
          sourceCourseKey: remote.sourceCourseKey,
          localCourse: localCourse,
          remoteCourse: remote,
        ));
        continue;
      }
      final previous = previousByKey[remote.sourceCourseKey];
      final fields = _fields(
        localCourse: localCourse,
        localRules: localRules[localCourse.id] ?? const [],
        previous: previous,
        remote: remote,
      );
      final conflict = fields.any((field) => field.hasConflict);
      final changed = fields.any(
        (field) =>
            field.decision != MergeDecision.local ||
            !_same(field.localValue, field.remoteValue),
      );
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
      if (remoteByKey.containsKey(key) || localCourse.deleted) continue;
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
    return ImportDiff(List.unmodifiable(changes));
  }

  List<ImportFieldChange> _fields({
    required Course localCourse,
    required List<MeetingRule> localRules,
    required ImportedCourse? previous,
    required ImportedCourse remote,
  }) {
    final localValues = <String, Object?>{
      'name': localCourse.name,
      'code': localCourse.code,
      'teachingClass': localCourse.teachingClass,
      'credits': localCourse.credits,
      'assessment': localCourse.assessment,
      'meetings': localRules.map(_meetingToJson).toList(),
    };
    final remoteValues = <String, Object?>{
      'name': remote.name,
      'code': remote.code,
      'teachingClass': remote.teachingClass,
      'credits': remote.credits,
      'assessment': remote.assessment,
      'meetings': remote.meetings.map((item) => item.toJson()).toList(),
    };
    final previousValues = <String, Object?>{
      'name': previous?.name,
      'code': previous?.code,
      'teachingClass': previous?.teachingClass,
      'credits': previous?.credits,
      'assessment': previous?.assessment,
      'meetings': previous?.meetings.map((item) => item.toJson()).toList(),
    };
    return [
      for (final field in remoteValues.keys)
        _mergeField(
          field: field,
          previousValue: previousValues[field],
          localValue: localValues[field],
          remoteValue: remoteValues[field],
        ),
    ];
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

  static Map<String, Object?> _meetingToJson(MeetingRule rule) => {
        'sourceMeetingKey': rule.sourceMeetingKey,
        'weekday': rule.weekday,
        'startSection': rule.startSection,
        'endSection': rule.endSection,
        'teacher': rule.teacher,
        'campus': rule.campus,
        'room': rule.room,
        'weekMask': rule.weekMask.value,
        'rawWeekText': rule.weekMask.rawText,
      };

  static bool _same(Object? left, Object? right) =>
      _canonical(left) == _canonical(right);

  static String _canonical(Object? value) => jsonEncode(value);
}
