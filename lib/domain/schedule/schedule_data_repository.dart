import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';
import '../backup/schedule_backup.dart';
import '../import/timetable_import.dart';
import '../import/import_diff.dart';
import '../semester/semester.dart';

class ScheduleDataSnapshot {
  const ScheduleDataSnapshot({
    required this.semester,
    required this.courses,
    required this.meetingRules,
    required this.exceptions,
  });

  final Semester semester;
  final List<Course> courses;
  final List<MeetingRule> meetingRules;
  final List<CourseException> exceptions;
}

abstract interface class ScheduleDataRepository {
  Stream<void> watchChanges();

  Future<List<Semester>> loadSemesters();

  Future<ScheduleDataSnapshot> loadSemester(String semesterId);

  Future<String?> getPreferredSemesterId();

  Future<DateTime?> getPreferredSemesterSelectedAt();

  Future<void> setPreferredSemesterId(String? semesterId);

  Future<String?> getSetting(String key);

  Future<void> setSetting(String key, String? value);

  Future<void> saveSemester(Semester semester);

  Future<void> deleteSemester(String semesterId);

  Future<void> saveCourse(Course course, List<MeetingRule> rules);

  Future<void> saveException(CourseException exception);

  Future<void> deleteException(String exceptionId);

  Future<void> setCourseHidden(String courseId, bool hidden);

  Future<void> deleteCourse(String courseId);

  Future<void> restoreImportedCourse(String courseId);

  Future<RemoteTimetable?> loadLatestImport(String semesterId);

  Future<ImportDiff> previewImportedTimetable(RemoteTimetable timetable);

  Future<void> commitImportedTimetable(
    RemoteTimetable timetable, {
    String adapterVersion = 'nwu-zhengfang-v1',
    ImportConflictResolution resolution = ImportConflictResolution.empty,
  });

  Future<ScheduleBackup> createBackup({
    Map<String, Object?> appearance = const {},
  });

  Future<void> restoreBackup(ScheduleBackup backup);

  Future<void> clearAllData();
}
