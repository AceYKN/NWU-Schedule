import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Semesters extends Table {
  TextColumn get id => text()();
  TextColumn get academicYear => text()();
  IntColumn get term => integer()();
  TextColumn get label => text()();
  TextColumn get remoteTermKey => text().nullable()();
  TextColumn get calendarId => text().nullable()();
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

  factory AppDatabase.open() => AppDatabase(
        driftDatabase(name: 'nwu_schedule'),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await customStatement(
            'CREATE INDEX courses_semester_idx ON courses (semester_id)',
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
          throw StateError('Database migration $from → $to is missing');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
