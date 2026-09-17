import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../core/utils/week_mask.dart';
import '../../domain/backup/schedule_backup.dart';
import '../../domain/course/course.dart' as domain;
import '../../domain/course/course_exception.dart' as domain;
import '../../domain/course/meeting_rule.dart' as domain;
import '../../domain/import/import_diff.dart';
import '../../domain/import/timetable_import.dart';
import '../../domain/import/three_way_merge.dart';
import '../../domain/schedule/schedule_data_repository.dart';
import '../../domain/semester/semester.dart' as domain;
import '../database/app_database.dart' as db;

class DriftScheduleDataRepository implements ScheduleDataRepository {
  const DriftScheduleDataRepository(this.database);

  final db.AppDatabase database;

  @override
  Stream<void> watchChanges() => database
      .customSelect(
        'SELECT 1',
        readsFrom: {
          database.semesters,
          database.courses,
          database.meetingRules,
          database.courseExceptions,
          database.appSettings,
        },
      )
      .watchSingle()
      .map((_) {});

  @override
  Future<List<domain.Semester>> loadSemesters() async {
    final rows = await database.select(database.semesters).get();
    return rows
        .map(
          (row) => domain.Semester(
            id: row.id,
            academicYear: row.academicYear,
            term: domain.SemesterTerm.values[row.term - 1],
            label: row.label,
            remoteTermKey: row.remoteTermKey,
            calendarId: row.calendarId,
            createdAt: row.createdAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ScheduleDataSnapshot> loadSemester(String semesterId) async {
    final semesters = await loadSemesters();
    final semester = semesters.singleWhere((item) => item.id == semesterId);
    final courseRows = await (database.select(database.courses)
          ..where((table) => table.semesterId.equals(semesterId)))
        .get();
    final courseIds = courseRows.map((row) => row.id).toList();
    final ruleRows = courseIds.isEmpty
        ? <db.MeetingRule>[]
        : await (database.select(database.meetingRules)
              ..where((table) => table.courseId.isIn(courseIds)))
            .get();
    final exceptionRows = await (database.select(database.courseExceptions)
          ..where((table) => table.semesterId.equals(semesterId)))
        .get();
    return ScheduleDataSnapshot(
      semester: semester,
      courses: courseRows
          .map(
            (row) => domain.Course(
              id: row.id,
              semesterId: row.semesterId,
              sourceType: domain.CourseSourceType.values.byName(row.sourceType),
              sourceCourseKey: row.sourceCourseKey,
              name: row.name,
              code: row.code,
              teachingClass: row.teachingClass,
              credits: row.credits,
              assessment: row.assessment,
              note: row.note,
              colorOverride: row.colorOverride,
              hidden: row.hidden,
              deleted: row.deleted,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList(growable: false),
      meetingRules: ruleRows
          .map(
            (row) => domain.MeetingRule(
              id: row.id,
              courseId: row.courseId,
              sourceMeetingKey: row.sourceMeetingKey,
              weekday: row.weekday,
              startSection: row.startSection,
              endSection: row.endSection,
              teacher: row.teacher,
              campus: row.campus,
              room: row.room,
              weekMask: WeekMask(row.weekMask, rawText: row.rawWeekText),
            ),
          )
          .toList(growable: false),
      exceptions: exceptionRows
          .map(
            (row) => domain.CourseException(
              id: row.id,
              semesterId: row.semesterId,
              courseId: row.courseId,
              sourceMeetingId: row.sourceMeetingId,
              sourceDate: row.sourceDate,
              type: domain.CourseExceptionType.values.byName(row.type),
              targetDate: row.targetDate,
              targetStartSection: row.targetStartSection,
              targetEndSection: row.targetEndSection,
              teacherOverride: row.teacherOverride,
              campusOverride: row.campusOverride,
              roomOverride: row.roomOverride,
              addedCourseName: row.addedCourseName,
              note: row.note,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<String?> getPreferredSemesterId() async {
    final row = await (database.select(database.appSettings)
          ..where((table) => table.key.equals('preferredSemesterId')))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<DateTime?> getPreferredSemesterSelectedAt() async {
    final row = await (database.select(database.appSettings)
          ..where((table) => table.key.equals('preferredSemesterSelectedAt')))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value);
  }

  @override
  Future<String?> getSetting(String key) async {
    final row = await (database.select(database.appSettings)
          ..where((table) => table.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setSetting(String key, String? value) async {
    if (key.trim().isEmpty) throw ArgumentError.value(key, 'key');
    if (value == null) {
      await (database.delete(database.appSettings)
            ..where((table) => table.key.equals(key)))
          .go();
      return;
    }
    await database.into(database.appSettings).insertOnConflictUpdate(
          db.AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> setPreferredSemesterId(String? semesterId) async {
    await database.transaction(() async {
      if (semesterId == null) {
        await (database.delete(database.appSettings)
              ..where((table) => table.key.isIn([
                    'preferredSemesterId',
                    'preferredSemesterSelectedAt',
                  ])))
            .go();
        return;
      }
      await database.into(database.appSettings).insertOnConflictUpdate(
            db.AppSettingsCompanion.insert(
              key: 'preferredSemesterId',
              value: semesterId,
            ),
          );
      await database.into(database.appSettings).insertOnConflictUpdate(
            db.AppSettingsCompanion.insert(
              key: 'preferredSemesterSelectedAt',
              value: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
  }

  @override
  Future<void> saveSemester(domain.Semester semester) async {
    await database.into(database.semesters).insertOnConflictUpdate(
          db.SemestersCompanion.insert(
            id: semester.id,
            academicYear: semester.academicYear,
            term: semester.term.index + 1,
            label: semester.label,
            remoteTermKey: Value(semester.remoteTermKey),
            calendarId: Value(semester.calendarId),
            createdAt: semester.createdAt,
          ),
        );
  }

  @override
  Future<void> deleteSemester(String semesterId) async {
    if (semesterId.trim().isEmpty) {
      throw ArgumentError.value(semesterId, 'semesterId');
    }
    await database.transaction(() async {
      final semester = await (database.select(database.semesters)
            ..where((table) => table.id.equals(semesterId)))
          .getSingleOrNull();
      if (semester == null) {
        throw StateError('Semester not found: $semesterId');
      }
      await (database.delete(database.semesters)
            ..where((table) => table.id.equals(semesterId)))
          .go();
      final preferred = await getPreferredSemesterId();
      if (preferred == semesterId) {
        await (database.delete(database.appSettings)
              ..where((table) => table.key.isIn([
                    'preferredSemesterId',
                    'preferredSemesterSelectedAt',
                  ])))
            .go();
      }
    });
  }

  @override
  Future<void> saveCourse(
    domain.Course course,
    List<domain.MeetingRule> rules,
  ) async {
    if (rules.any((rule) => rule.courseId != course.id)) {
      throw ArgumentError('MeetingRule courseId does not match Course id');
    }
    await database.transaction(() async {
      await database.into(database.courses).insertOnConflictUpdate(
            db.CoursesCompanion.insert(
              id: course.id,
              semesterId: course.semesterId,
              sourceType: course.sourceType.name,
              sourceCourseKey: Value(course.sourceCourseKey),
              name: course.name,
              code: Value(course.code),
              teachingClass: Value(course.teachingClass),
              credits: Value(course.credits),
              assessment: Value(course.assessment),
              note: Value(course.note),
              colorOverride: Value(course.colorOverride),
              hidden: Value(course.hidden),
              deleted: Value(course.deleted),
              createdAt: course.createdAt,
              updatedAt: course.updatedAt,
            ),
          );
      await (database.delete(database.meetingRules)
            ..where((table) => table.courseId.equals(course.id)))
          .go();
      for (final rule in rules) {
        await database.into(database.meetingRules).insert(
              db.MeetingRulesCompanion.insert(
                id: rule.id,
                courseId: rule.courseId,
                sourceMeetingKey: Value(rule.sourceMeetingKey),
                weekday: rule.weekday,
                startSection: rule.startSection,
                endSection: rule.endSection,
                teacher: Value(rule.teacher),
                campus: Value(rule.campus),
                room: Value(rule.room),
                weekMask: rule.weekMask.value,
                rawWeekText: rule.weekMask.rawText,
              ),
            );
      }
    });
  }

  @override
  Future<void> saveException(domain.CourseException exception) async {
    await database.into(database.courseExceptions).insertOnConflictUpdate(
          db.CourseExceptionsCompanion.insert(
            id: exception.id,
            semesterId: exception.semesterId,
            courseId: Value(exception.courseId),
            sourceMeetingId: Value(exception.sourceMeetingId),
            sourceDate: Value(exception.sourceDate),
            type: exception.type.name,
            targetDate: Value(exception.targetDate),
            targetStartSection: Value(exception.targetStartSection),
            targetEndSection: Value(exception.targetEndSection),
            teacherOverride: Value(exception.teacherOverride),
            campusOverride: Value(exception.campusOverride),
            roomOverride: Value(exception.roomOverride),
            addedCourseName: Value(exception.addedCourseName),
            note: Value(exception.note),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> deleteException(String exceptionId) async {
    await (database.delete(database.courseExceptions)
          ..where((table) => table.id.equals(exceptionId)))
        .go();
  }

  @override
  Future<void> setCourseHidden(String courseId, bool hidden) async {
    await (database.update(database.courses)
          ..where((table) => table.id.equals(courseId)))
        .write(
      db.CoursesCompanion(
        hidden: Value(hidden),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    await database.transaction(() async {
      final course = await (database.select(database.courses)
            ..where((table) => table.id.equals(courseId)))
          .getSingleOrNull();
      if (course == null) throw StateError('Course not found: $courseId');
      if (course.sourceType == domain.CourseSourceType.imported.name) {
        final key = course.sourceCourseKey;
        if (key == null || key.isEmpty) {
          throw StateError('Imported course has no source key: $courseId');
        }
        await (database.update(database.courses)
              ..where((table) => table.id.equals(courseId)))
            .write(db.CoursesCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
        await database.into(database.deletedSourceItems).insertOnConflictUpdate(
              db.DeletedSourceItemsCompanion.insert(
                id: 'course:${course.semesterId}:$key',
                semesterId: course.semesterId,
                sourceCourseKey: key,
                deletedAt: DateTime.now(),
              ),
            );
      } else {
        await (database.delete(database.courseExceptions)
              ..where((table) => table.courseId.equals(courseId)))
            .go();
        await (database.delete(database.courses)
              ..where((table) => table.id.equals(courseId)))
            .go();
      }
    });
  }

  @override
  Future<void> restoreImportedCourse(String courseId) async {
    await database.transaction(() async {
      final course = await (database.select(database.courses)
            ..where((table) => table.id.equals(courseId)))
          .getSingleOrNull();
      if (course == null ||
          course.sourceType != domain.CourseSourceType.imported.name ||
          course.sourceCourseKey == null) {
        throw StateError('Not an imported course: $courseId');
      }
      await (database.delete(database.deletedSourceItems)
            ..where((table) => table.id.equals(
                'course:${course.semesterId}:${course.sourceCourseKey}')))
          .go();
      await (database.update(database.courses)
            ..where((table) => table.id.equals(courseId)))
          .write(db.CoursesCompanion(
        deleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  @override
  Future<ScheduleBackup> createBackup({
    Map<String, Object?> appearance = const {},
  }) async {
    final semesters = await loadSemesters();
    final snapshots = <ScheduleDataSnapshot>[];
    for (final semester in semesters) {
      snapshots.add(await loadSemester(semester.id));
    }
    final settings = await database.select(database.appSettings).get();
    final importSnapshots =
        await database.select(database.importSnapshots).get();
    final deletedSourceItems =
        await database.select(database.deletedSourceItems).get();
    return ScheduleBackup(
      createdAt: DateTime.now().toUtc(),
      semesters: semesters,
      courses: [
        for (final snapshot in snapshots) ...snapshot.courses,
      ],
      meetingRules: [
        for (final snapshot in snapshots) ...snapshot.meetingRules,
      ],
      exceptions: [
        for (final snapshot in snapshots) ...snapshot.exceptions,
      ],
      settings: {
        for (final setting in settings) setting.key: setting.value,
      },
      appearance: appearance,
      importSnapshots: [
        for (final snapshot in importSnapshots)
          BackupImportSnapshot(
            id: snapshot.id,
            semesterId: snapshot.semesterId,
            importedAt: snapshot.importedAt,
            adapterVersion: snapshot.adapterVersion,
            schemaVersion: snapshot.schemaVersion,
            normalizedJson: snapshot.normalizedJson,
            hash: snapshot.hash,
          ),
      ],
      deletedSourceItems: [
        for (final item in deletedSourceItems)
          BackupDeletedSourceItem(
            id: item.id,
            semesterId: item.semesterId,
            sourceCourseKey: item.sourceCourseKey,
            sourceMeetingKey: item.sourceMeetingKey,
            deletedAt: item.deletedAt,
          ),
      ],
    );
  }

  @override
  Future<void> restoreBackup(ScheduleBackup backup) async {
    final validated = ScheduleBackup.fromJson(backup.toJson());
    await database.transaction(() async {
      await _clearAllTables();
      for (final semester in validated.semesters) {
        await database.into(database.semesters).insert(
              db.SemestersCompanion.insert(
                id: semester.id,
                academicYear: semester.academicYear,
                term: semester.term.index + 1,
                label: semester.label,
                remoteTermKey: Value(semester.remoteTermKey),
                calendarId: Value(semester.calendarId),
                createdAt: semester.createdAt,
              ),
            );
      }
      for (final course in validated.courses) {
        await database.into(database.courses).insert(
              db.CoursesCompanion.insert(
                id: course.id,
                semesterId: course.semesterId,
                sourceType: course.sourceType.name,
                sourceCourseKey: Value(course.sourceCourseKey),
                name: course.name,
                code: Value(course.code),
                teachingClass: Value(course.teachingClass),
                credits: Value(course.credits),
                assessment: Value(course.assessment),
                note: Value(course.note),
                colorOverride: Value(course.colorOverride),
                hidden: Value(course.hidden),
                deleted: Value(course.deleted),
                createdAt: course.createdAt,
                updatedAt: course.updatedAt,
              ),
            );
      }
      for (final rule in validated.meetingRules) {
        await database.into(database.meetingRules).insert(
              db.MeetingRulesCompanion.insert(
                id: rule.id,
                courseId: rule.courseId,
                sourceMeetingKey: Value(rule.sourceMeetingKey),
                weekday: rule.weekday,
                startSection: rule.startSection,
                endSection: rule.endSection,
                teacher: Value(rule.teacher),
                campus: Value(rule.campus),
                room: Value(rule.room),
                weekMask: rule.weekMask.value,
                rawWeekText: rule.weekMask.rawText,
              ),
            );
      }
      for (final exception in validated.exceptions) {
        await database.into(database.courseExceptions).insert(
              db.CourseExceptionsCompanion.insert(
                id: exception.id,
                semesterId: exception.semesterId,
                courseId: Value(exception.courseId),
                sourceMeetingId: Value(exception.sourceMeetingId),
                sourceDate: Value(exception.sourceDate),
                type: exception.type.name,
                targetDate: Value(exception.targetDate),
                targetStartSection: Value(exception.targetStartSection),
                targetEndSection: Value(exception.targetEndSection),
                teacherOverride: Value(exception.teacherOverride),
                campusOverride: Value(exception.campusOverride),
                roomOverride: Value(exception.roomOverride),
                addedCourseName: Value(exception.addedCourseName),
                note: Value(exception.note),
                createdAt: validated.createdAt,
              ),
            );
      }
      for (final snapshot in validated.importSnapshots) {
        await database.into(database.importSnapshots).insert(
              db.ImportSnapshotsCompanion.insert(
                id: snapshot.id,
                semesterId: snapshot.semesterId,
                importedAt: snapshot.importedAt,
                adapterVersion: snapshot.adapterVersion,
                schemaVersion: snapshot.schemaVersion,
                normalizedJson: snapshot.normalizedJson,
                hash: snapshot.hash,
              ),
            );
      }
      for (final item in validated.deletedSourceItems) {
        await database.into(database.deletedSourceItems).insert(
              db.DeletedSourceItemsCompanion.insert(
                id: item.id,
                semesterId: item.semesterId,
                sourceCourseKey: item.sourceCourseKey,
                sourceMeetingKey: Value(item.sourceMeetingKey),
                deletedAt: item.deletedAt,
              ),
            );
      }
      for (final entry in validated.settings.entries) {
        await database.into(database.appSettings).insert(
              db.AppSettingsCompanion.insert(
                key: entry.key,
                value: entry.value,
              ),
            );
      }
    });
  }

  @override
  Future<void> clearAllData() async {
    await database.transaction(_clearAllTables);
  }

  Future<void> _clearAllTables() async {
    await database.delete(database.meetingRules).go();
    await database.delete(database.courseExceptions).go();
    await database.delete(database.importSnapshots).go();
    await database.delete(database.deletedSourceItems).go();
    await database.delete(database.courses).go();
    await database.delete(database.semesters).go();
    await database.delete(database.appSettings).go();
  }

  @override
  Future<RemoteTimetable?> loadLatestImport(String semesterId) async {
    final row = await (database.select(database.importSnapshots)
          ..where((table) => table.semesterId.equals(semesterId))
          ..orderBy([
            (table) => OrderingTerm.desc(table.importedAt),
            (table) => OrderingTerm.desc(table.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return const TimetableImportParser().parse(
      jsonDecode(row.normalizedJson) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> commitImportedTimetable(
    RemoteTimetable timetable, {
    String adapterVersion = 'nwu-zhengfang-v1',
    ImportConflictResolution resolution = ImportConflictResolution.empty,
  }) async {
    final report = validateTimetable(timetable);
    if (!report.isValid) {
      throw TimetableImportValidationException(report);
    }
    final semesterId = timetable.semester.id;
    final semesters = await loadSemesters();
    domain.Semester? existingSemester;
    for (final semester in semesters) {
      if (semester.id == semesterId) {
        existingSemester = semester;
        break;
      }
    }
    final local =
        existingSemester == null ? null : await loadSemester(semesterId);
    final previous = await loadLatestImport(semesterId);
    final tombstones = await (database.select(database.deletedSourceItems)
          ..where((table) => table.semesterId.equals(semesterId)))
        .get();
    final rawDiff = const ImportDiffEngine().build(
      incoming: timetable,
      local: local,
      previousImport: previous,
      deletedSourceCourseKeys:
          tombstones.map((row) => row.sourceCourseKey).toSet(),
    );
    final diff = rawDiff.resolve(resolution);
    if (diff.hasConflicts) {
      throw TimetableImportConflictException(diff);
    }

    final now = DateTime.now();
    final semester = existingSemester ??
        domain.Semester(
          id: semesterId,
          academicYear: timetable.semester.academicYear,
          term: domain.SemesterTerm.values[timetable.semester.term - 1],
          label: timetable.semester.label,
          remoteTermKey: timetable.semester.remoteTermKey,
          calendarId: timetable.semester.calendarId ?? semesterId,
          createdAt: now,
        );
    final localCourses = {
      for (final course in local?.courses ?? const <domain.Course>[])
        if (course.sourceCourseKey != null) course.sourceCourseKey!: course,
    };
    final localRules = <String, List<domain.MeetingRule>>{};
    for (final rule in local?.meetingRules ?? const <domain.MeetingRule>[]) {
      localRules.putIfAbsent(rule.courseId, () => []).add(rule);
    }
    await database.transaction(() async {
      await _upsertSemester(semester);
      for (final change in diff.changes) {
        final remote = change.remoteCourse;
        if (remote == null) {
          if (change.kind == ImportChangeKind.removed &&
              change.localCourse != null) {
            await _markImportedDeleted(change.localCourse!);
          }
          continue;
        }
        if (change.kind == ImportChangeKind.locallyDeleted) continue;
        if (change.kind == ImportChangeKind.unchanged) continue;
        final existing = localCourses[remote.sourceCourseKey];
        final course = _courseFromRemote(
          semester: semester,
          remote: remote,
          existing: existing,
          fields: change.fields,
          now: now,
        );
        final existingRules = existing == null
            ? const <domain.MeetingRule>[]
            : localRules[existing.id] ?? const <domain.MeetingRule>[];
        final rules = _rulesFromRemote(
          remote: remote,
          courseId: course.id,
          existing: existingRules,
          fields: change.fields,
        );
        await _upsertCourse(course, rules);
      }
      final normalizedJson = jsonEncode(timetable.toJson());
      final hash = sha256.convert(utf8.encode(normalizedJson)).toString();
      await database.into(database.importSnapshots).insert(
            db.ImportSnapshotsCompanion.insert(
              id: '$semesterId:${now.microsecondsSinceEpoch}',
              semesterId: semesterId,
              importedAt: now,
              adapterVersion: adapterVersion,
              schemaVersion: 1,
              normalizedJson: normalizedJson,
              hash: hash,
            ),
          );
    });
  }

  Future<void> _upsertSemester(domain.Semester semester) async {
    await database.into(database.semesters).insertOnConflictUpdate(
          db.SemestersCompanion.insert(
            id: semester.id,
            academicYear: semester.academicYear,
            term: semester.term.index + 1,
            label: semester.label,
            remoteTermKey: Value(semester.remoteTermKey),
            calendarId: Value(semester.calendarId),
            createdAt: semester.createdAt,
          ),
        );
  }

  Future<void> _upsertCourse(
    domain.Course course,
    List<domain.MeetingRule> rules,
  ) async {
    await database.into(database.courses).insertOnConflictUpdate(
          db.CoursesCompanion.insert(
            id: course.id,
            semesterId: course.semesterId,
            sourceType: course.sourceType.name,
            sourceCourseKey: Value(course.sourceCourseKey),
            name: course.name,
            code: Value(course.code),
            teachingClass: Value(course.teachingClass),
            credits: Value(course.credits),
            assessment: Value(course.assessment),
            note: Value(course.note),
            colorOverride: Value(course.colorOverride),
            hidden: Value(course.hidden),
            deleted: Value(course.deleted),
            createdAt: course.createdAt,
            updatedAt: course.updatedAt,
          ),
        );
    await (database.delete(database.meetingRules)
          ..where((table) => table.courseId.equals(course.id)))
        .go();
    for (final rule in rules) {
      await database.into(database.meetingRules).insert(
            db.MeetingRulesCompanion.insert(
              id: rule.id,
              courseId: course.id,
              sourceMeetingKey: Value(rule.sourceMeetingKey),
              weekday: rule.weekday,
              startSection: rule.startSection,
              endSection: rule.endSection,
              teacher: Value(rule.teacher),
              campus: Value(rule.campus),
              room: Value(rule.room),
              weekMask: rule.weekMask.value,
              rawWeekText: rule.weekMask.rawText,
            ),
          );
    }
  }

  Future<void> _markImportedDeleted(domain.Course course) async {
    final key = course.sourceCourseKey;
    if (key == null) return;
    await (database.update(database.courses)
          ..where((table) => table.id.equals(course.id)))
        .write(db.CoursesCompanion(
      deleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
    await database.into(database.deletedSourceItems).insertOnConflictUpdate(
          db.DeletedSourceItemsCompanion.insert(
            id: 'course:${course.semesterId}:$key',
            semesterId: course.semesterId,
            sourceCourseKey: key,
            deletedAt: DateTime.now(),
          ),
        );
  }

  domain.Course _courseFromRemote({
    required domain.Semester semester,
    required ImportedCourse remote,
    required domain.Course? existing,
    required List<ImportFieldChange> fields,
    required DateTime now,
  }) {
    Object? value(String field, Object? remoteValue, Object? localValue) {
      ImportFieldChange? change;
      for (final item in fields) {
        if (item.field == field) {
          change = item;
          break;
        }
      }
      if (change == null) return remoteValue;
      return change.decision == MergeDecision.local ? localValue : remoteValue;
    }

    final id =
        existing?.id ?? _importedCourseId(semester.id, remote.sourceCourseKey);
    return domain.Course(
      id: id,
      semesterId: semester.id,
      sourceType: domain.CourseSourceType.imported,
      sourceCourseKey: remote.sourceCourseKey,
      name: value('name', remote.name, existing?.name) as String,
      code: value('code', remote.code, existing?.code) as String?,
      teachingClass:
          value('teachingClass', remote.teachingClass, existing?.teachingClass)
              as String?,
      credits: value('credits', remote.credits, existing?.credits) as double?,
      assessment: value('assessment', remote.assessment, existing?.assessment)
          as String?,
      note: existing?.note,
      colorOverride: existing?.colorOverride,
      hidden: existing?.hidden ?? false,
      deleted: existing?.deleted ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  List<domain.MeetingRule> _rulesFromRemote({
    required ImportedCourse remote,
    required String courseId,
    required List<domain.MeetingRule> existing,
    required List<ImportFieldChange> fields,
  }) {
    ImportFieldChange? meetingsField;
    for (final field in fields) {
      if (field.field == 'meetings') {
        meetingsField = field;
        break;
      }
    }
    if (meetingsField?.decision == MergeDecision.local) return existing;
    return [
      for (final meeting in remote.meetings)
        domain.MeetingRule(
          id: '$courseId:${meeting.sourceMeetingKey}',
          courseId: courseId,
          sourceMeetingKey: meeting.sourceMeetingKey,
          weekday: meeting.weekday,
          startSection: meeting.startSection,
          endSection: meeting.endSection,
          teacher: meeting.teacher,
          campus: meeting.campus,
          room: meeting.room,
          weekMask: meeting.weekMask,
        ),
    ];
  }

  static String _importedCourseId(String semesterId, String sourceKey) {
    final digest =
        sha256.convert(utf8.encode('$semesterId:$sourceKey')).toString();
    return 'imported-${digest.substring(0, 24)}';
  }
}
