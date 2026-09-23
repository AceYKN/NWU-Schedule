import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/utils/week_mask.dart';
import '../../domain/course/course.dart' as domain;
import '../../domain/course/course_canonicalizer.dart';
import '../../domain/course/course_exception.dart' as domain;
import '../../domain/course/course_identity.dart';
import '../../domain/course/meeting_rule.dart' as domain;

part 'app_database.g.dart';

class Semesters extends Table {
  TextColumn get id => text()();
  TextColumn get academicYear => text()();
  IntColumn get term => integer()();
  TextColumn get label => text()();
  TextColumn get remoteTermKey => text().nullable()();
  TextColumn get calendarId => text().nullable()();
  IntColumn get calendarRevision => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get semesterId =>
      text().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceType => text()();
  TextColumn get sourceCourseKey => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameKey => text().withDefault(const Constant(''))();
  TextColumn get code => text().nullable()();
  TextColumn get teachingClass => text().nullable()();
  RealColumn get credits => real().nullable()();
  TextColumn get assessment => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get colorOverride => integer().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredMeetingRule')
class MeetingRules extends Table {
  TextColumn get id => text()();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceMeetingKey => text().nullable()();
  IntColumn get weekday => integer()();
  IntColumn get startSection => integer()();
  IntColumn get endSection => integer()();
  TextColumn get teacher => text().nullable()();
  TextColumn get campus => text().nullable()();
  TextColumn get room => text().nullable()();
  IntColumn get weekMask => integer()();
  TextColumn get rawWeekText => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CourseExceptions extends Table {
  TextColumn get id => text()();
  TextColumn get semesterId =>
      text().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get courseId => text().nullable()();
  TextColumn get sourceMeetingId => text().nullable()();
  DateTimeColumn get sourceDate => dateTime().nullable()();
  TextColumn get type => text()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get targetStartSection => integer().nullable()();
  IntColumn get targetEndSection => integer().nullable()();
  TextColumn get teacherOverride => text().nullable()();
  TextColumn get campusOverride => text().nullable()();
  TextColumn get roomOverride => text().nullable()();
  TextColumn get addedCourseName => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ImportSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get semesterId =>
      text().references(Semesters, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get importedAt => dateTime()();
  TextColumn get adapterVersion => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get normalizedJson => text()();
  TextColumn get hash => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class DeletedSourceItems extends Table {
  TextColumn get id => text()();
  TextColumn get semesterId =>
      text().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceCourseKey => text()();
  TextColumn get sourceMeetingKey => text().nullable()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Semesters,
    Courses,
    MeetingRules,
    CourseExceptions,
    ImportSnapshots,
    DeletedSourceItems,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() =>
      AppDatabase(driftDatabase(name: 'nwu_schedule'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await customStatement(
            'CREATE INDEX courses_semester_idx ON courses (semester_id)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX courses_semester_name_key_uq '
            'ON courses (semester_id, name_key)',
          );
          await customStatement(
            'CREATE INDEX meeting_rules_course_idx ON meeting_rules (course_id)',
          );
          await customStatement(
            'CREATE INDEX exceptions_semester_idx ON course_exceptions (semester_id)',
          );
          await customStatement(
            'CREATE INDEX snapshots_semester_idx ON import_snapshots (semester_id)',
          );
          await customStatement(
            'CREATE INDEX tombstones_semester_idx ON deleted_source_items (semester_id)',
          );
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(semesters, semesters.calendarRevision);
          }
          if (from < 3) {
            await transaction(() async {
              await migrator.addColumn(courses, courses.nameKey);
              await _canonicalizeExistingCourses();
              await customStatement(
                'CREATE UNIQUE INDEX courses_semester_name_key_uq '
                'ON courses (semester_id, name_key)',
              );
            });
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _canonicalizeExistingCourses() async {
    final courseRows = await select(courses).get();
    final ruleRows = await select(meetingRules).get();
    final exceptionRows = await select(courseExceptions).get();
    final converted = CourseCanonicalizer.canonicalize(
      courses: [
        for (final row in courseRows)
          domain.Course(
            id: row.id,
            semesterId: row.semesterId,
            sourceType: domain.CourseSourceType.values.byName(row.sourceType),
            sourceCourseKey: row.sourceCourseKey,
            name: row.name,
            note: row.note,
            colorOverride: row.colorOverride,
            hidden: row.hidden,
            deleted: row.deleted,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
      ],
      meetingRules: [
        for (final row in ruleRows)
          domain.MeetingRule(
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
      ],
      exceptions: [
        for (final row in exceptionRows)
          domain.CourseException(
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
      ],
    );

    final canonicalCourseIds =
        converted.courses.map((course) => course.id).toSet();
    for (final course in converted.courses) {
      await (update(
        courses,
      )..where((table) => table.id.equals(course.id)))
          .write(
        CoursesCompanion(
          sourceType: Value(course.sourceType.name),
          sourceCourseKey: Value(course.sourceCourseKey),
          name: Value(course.name),
          nameKey: Value(CourseIdentity.nameKey(course.name)),
          note: Value(course.note),
          colorOverride: Value(course.colorOverride),
          hidden: Value(course.hidden),
          deleted: Value(course.deleted),
          createdAt: Value(course.createdAt),
          updatedAt: Value(course.updatedAt),
        ),
      );
    }

    final canonicalRuleIds =
        converted.meetingRules.map((rule) => rule.id).toSet();
    for (final rule in converted.meetingRules) {
      await (update(
        meetingRules,
      )..where((table) => table.id.equals(rule.id)))
          .write(
        MeetingRulesCompanion(
          courseId: Value(rule.courseId),
          sourceMeetingKey: Value(rule.sourceMeetingKey),
          teacher: Value(rule.teacher),
          campus: Value(rule.campus),
          room: Value(rule.room),
        ),
      );
    }
    for (final row in ruleRows) {
      if (canonicalRuleIds.contains(row.id)) continue;
      await (delete(
        meetingRules,
      )..where((table) => table.id.equals(row.id)))
          .go();
    }

    for (final exception in converted.exceptions) {
      await (update(
        courseExceptions,
      )..where((table) => table.id.equals(exception.id)))
          .write(
        CourseExceptionsCompanion(
          courseId: Value(exception.courseId),
          sourceMeetingId: Value(exception.sourceMeetingId),
        ),
      );
    }

    for (final row in courseRows) {
      if (canonicalCourseIds.contains(row.id)) continue;
      await (delete(courses)..where((table) => table.id.equals(row.id))).go();
    }
  }
}
