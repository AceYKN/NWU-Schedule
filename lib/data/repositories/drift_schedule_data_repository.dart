import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

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
            calendarRevision: row.calendarRevision,
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
            calendarRevision: Value(semester.calendarRevision),
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
    List<domain.MeetingRule> rules, {
    Iterable<String> removeExceptionIds = const [],
  }) async {
    if (rules.any((rule) => rule.courseId != course.id)) {
      throw ArgumentError('MeetingRule courseId does not match Course id');
    }
    final exceptionIds = removeExceptionIds.toSet();
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
      if (exceptionIds.isNotEmpty) {
        await (database.delete(database.courseExceptions)
              ..where((table) => table.id.isIn(exceptionIds)))
            .go();
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
                calendarRevision: Value(semester.calendarRevision),
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
  Future<ImportDiff> previewImportedTimetable(RemoteTimetable timetable) async {
    final report = validateTimetable(timetable);
    if (!report.isValid) {
      throw TimetableImportValidationException(report);
    }
    final context = await _loadImportDiffContext(timetable);
    return context.diff;
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
    final context = await _loadImportDiffContext(timetable);
    final semesterId = timetable.semester.id;
    final existingSemester = context.existingSemester;
    final local = context.local;
    final rawDiff = context.diff;
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
        // A remote adapter may rotate an opaque course key while retaining
        // the same course identity. Remove tombstones for both keys when a
        // restored or otherwise active course is reconciled, otherwise a
        // stale old key could delete the course again if it rotates back.
        final existing =
            localCourses[remote.sourceCourseKey] ?? change.localCourse;
        final restoreDeleted = resolution.shouldRestore(
          remote.sourceCourseKey,
        );
        if (restoreDeleted || (existing != null && !existing.deleted)) {
          await _removeCourseTombstones(
            semesterId: semester.id,
            sourceCourseKeys: {
              remote.sourceCourseKey,
              existing?.sourceCourseKey,
            },
          );
        }
        // A Zhengfang adapter may rotate an opaque source key while retaining
        // the unique course code + teaching-class identity. ImportDiffEngine
        // has already matched that course conservatively; keep its database
        // id and local fields while adopting the new remote key.
        final course = _courseFromRemote(
          semester: semester,
          remote: remote,
          existing: existing,
          fields: change.fields,
          now: now,
          restoreDeleted: restoreDeleted,
        );
        final existingRules = existing == null
            ? const <domain.MeetingRule>[]
            : localRules[existing.id] ?? const <domain.MeetingRule>[];
        final reconciledRules = _rulesFromRemote(
          remote: remote,
          courseId: course.id,
          existing: existingRules,
          fields: change.fields,
        );
        await _upsertCourse(course, reconciledRules.rules);
        await _removeExceptionsForRemovedMeetingRules(
          courseId: course.id,
          existing: existingRules,
          retained: reconciledRules.rules,
          idRemap: reconciledRules.idRemap,
        );
        await _remapExceptionMeetingIds(
          courseId: course.id,
          idRemap: reconciledRules.idRemap,
        );
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

  Future<_ImportDiffContext> _loadImportDiffContext(
    RemoteTimetable timetable,
  ) async {
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
    final deletedSourceCourseKeys = {
      for (final tombstone in tombstones) tombstone.sourceCourseKey,
    };
    final diff = const ImportDiffEngine().build(
      incoming: timetable,
      local: local,
      previousImport: previous,
      deletedSourceCourseKeys: deletedSourceCourseKeys,
    );
    return _ImportDiffContext(
      existingSemester: existingSemester,
      local: local,
      diff: diff,
    );
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
            calendarRevision: Value(semester.calendarRevision),
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

  Future<void> _removeCourseTombstones({
    required String semesterId,
    required Set<String?> sourceCourseKeys,
  }) async {
    final keys = sourceCourseKeys
        .whereType<String>()
        .where((key) => key.trim().isNotEmpty)
        .toSet();
    if (keys.isEmpty) return;
    await (database.delete(database.deletedSourceItems)
          ..where((table) => Expression.and([
                table.semesterId.equals(semesterId),
                table.sourceCourseKey.isIn(keys),
              ])))
        .go();
  }

  domain.Course _courseFromRemote({
    required domain.Semester semester,
    required ImportedCourse remote,
    required domain.Course? existing,
    required List<ImportFieldChange> fields,
    required DateTime now,
    bool restoreDeleted = false,
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
      deleted: restoreDeleted ? false : existing?.deleted ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  _ReconciledRules _rulesFromRemote({
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
    if (meetingsField?.decision == MergeDecision.local) {
      return _ReconciledRules(
        rules: existing,
        idRemap: const {},
      );
    }

    final unmatched = [...existing];
    final usedIds = <String>{};
    final idRemap = <String, String>{};
    final rules = <domain.MeetingRule>[];
    for (final meeting in remote.meetings) {
      domain.MeetingRule? matched;
      for (final candidate in unmatched) {
        if (candidate.sourceMeetingKey == meeting.sourceMeetingKey) {
          matched = candidate;
          break;
        }
      }
      matched ??= _bestMeetingMatch(meeting, unmatched);
      if (matched != null) unmatched.remove(matched);

      var id = matched?.id ?? '$courseId:${meeting.sourceMeetingKey}';
      if (!usedIds.add(id)) {
        var suffix = 2;
        final base = id;
        do {
          id = '$base-$suffix';
          suffix++;
        } while (!usedIds.add(id));
        if (matched != null) idRemap[matched.id] = id;
      }
      rules.add(
        domain.MeetingRule(
          id: id,
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
      );
    }
    return _ReconciledRules(
      rules: List.unmodifiable(rules),
      idRemap: Map.unmodifiable(idRemap),
    );
  }

  Future<void> _remapExceptionMeetingIds({
    required String courseId,
    required Map<String, String> idRemap,
  }) async {
    for (final entry in idRemap.entries) {
      await (database.update(database.courseExceptions)
            ..where((table) => Expression.and([
                  table.courseId.equals(courseId),
                  table.sourceMeetingId.equals(entry.key),
                ])))
          .write(
        db.CourseExceptionsCompanion(
          sourceMeetingId: Value(entry.value),
        ),
      );
    }
  }

  Future<void> _removeExceptionsForRemovedMeetingRules({
    required String courseId,
    required List<domain.MeetingRule> existing,
    required List<domain.MeetingRule> retained,
    required Map<String, String> idRemap,
  }) async {
    final retainedIds = {for (final rule in retained) rule.id};
    final removedIds = [
      for (final rule in existing)
        if (!retainedIds.contains(rule.id) && !idRemap.containsKey(rule.id))
          rule.id,
    ];
    if (removedIds.isEmpty) return;
    await (database.delete(database.courseExceptions)
          ..where((table) => Expression.and([
                table.courseId.equals(courseId),
                table.sourceMeetingId.isIn(removedIds),
              ])))
        .go();
  }

  domain.MeetingRule? _bestMeetingMatch(
    ImportedMeeting meeting,
    List<domain.MeetingRule> candidates,
  ) {
    final scored = <({domain.MeetingRule rule, int score, int anchors})>[];
    for (final candidate in candidates) {
      final sameWeekday = candidate.weekday == meeting.weekday;
      final sameSections = candidate.startSection == meeting.startSection &&
          candidate.endSection == meeting.endSection;
      final sameWeeks = candidate.weekMask.value == meeting.weekMask.value;
      final sameTeacher = _sameMeetingText(candidate.teacher, meeting.teacher);
      final sameCampus = _sameMeetingText(candidate.campus, meeting.campus);
      final sameRoom = _sameMeetingText(candidate.room, meeting.room);
      final structuralAnchors = [
        sameWeekday,
        sameSections,
        sameWeeks,
      ].where((value) => value).length;
      // Teacher, campus, and room are mutable display properties. They may
      // help rank a candidate, but must never be the only evidence that two
      // rows represent the same recurring meeting. If the time/week shape
      // has no overlap, prefer add/remove over silently moving an exception
      // to an unrelated rule.
      if (structuralAnchors == 0) continue;
      final anchors = [
        sameWeekday,
        sameSections,
        sameWeeks,
        sameTeacher,
        sameCampus,
        sameRoom,
      ].where((value) => value).length;
      if (anchors < 2) continue;

      var score = 0;
      if (sameWeekday) score += 8;
      if (sameSections) {
        score += 6;
      } else if (candidate.startSection == meeting.startSection ||
          candidate.endSection == meeting.endSection) {
        score += 2;
      }
      if (sameWeeks) {
        score += 5;
      } else if (_weekMasksOverlap(candidate.weekMask, meeting.weekMask)) {
        score += 1;
      }
      if (sameTeacher) score += 3;
      if (sameCampus) score += 2;
      if (sameRoom) score += 3;
      scored.add((rule: candidate, score: score, anchors: anchors));
    }
    scored.sort((left, right) => right.score.compareTo(left.score));
    if (scored.isEmpty) return null;
    if (scored.length > 1 && scored[0].score == scored[1].score) {
      return null;
    }
    return scored.first.rule;
  }

  static bool _sameMeetingText(String? left, String? right) =>
      (left ?? '').trim() == (right ?? '').trim();

  static bool _weekMasksOverlap(
    WeekMask left,
    WeekMask right,
  ) =>
      (left.value & right.value) != 0;

  static String _importedCourseId(String semesterId, String sourceKey) {
    final digest =
        sha256.convert(utf8.encode('$semesterId:$sourceKey')).toString();
    return 'imported-${digest.substring(0, 24)}';
  }
}

class _ImportDiffContext {
  const _ImportDiffContext({
    required this.existingSemester,
    required this.local,
    required this.diff,
  });

  final domain.Semester? existingSemester;
  final ScheduleDataSnapshot? local;
  final ImportDiff diff;
}

class _ReconciledRules {
  const _ReconciledRules({
    required this.rules,
    required this.idRemap,
  });

  final List<domain.MeetingRule> rules;
  final Map<String, String> idRemap;
}
