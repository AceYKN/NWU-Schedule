import 'package:drift/drift.dart' show Value;

import '../../core/utils/week_mask.dart';
import '../../domain/course/course.dart' as domain;
import '../../domain/course/course_exception.dart' as domain;
import '../../domain/course/meeting_rule.dart' as domain;
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
}
