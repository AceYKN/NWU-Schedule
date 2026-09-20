import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/data/database/app_database.dart' as db;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/notification/notification_planner.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/widget/widget_snapshot.dart';
import 'package:nwu_schedule/infrastructure/import/nwu_zhengfang_v9_importer.dart';

void main() {
  test(
      'runs the sanitized fixture through import, DB, engine, notification, and widget',
      () async {
    final importer = NwuZhengfangV9Importer(
      readPayload: () async =>
          _readJson('test/fixtures/zhengfang/timetable_response.json'),
    );
    final semester = (await importer.getSemesters()).single;
    final imported = await importer.importSemester(semester);
    await importer.dispose();

    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);

    await repository.commitImportedTimetable(imported);
    var loaded = await repository.loadSemester(imported.semester.id);
    expect(loaded.courses, hasLength(2));
    expect(loaded.meetingRules, hasLength(2));
    expect(await repository.loadLatestImport(imported.semester.id), isNotNull);

    final changedJson =
        jsonDecode(jsonEncode(imported.toJson())) as Map<String, dynamic>;
    final changedCourses = changedJson['courses'] as List<dynamic>;
    final firstCourse = changedCourses.first as Map<String, dynamic>;
    final firstMeeting = (firstCourse['meetings'] as List<dynamic>).single
        as Map<String, dynamic>;
    firstMeeting['room'] = '3601';
    final changed = const TimetableImportParser().parse(changedJson);
    final diff = await repository.previewImportedTimetable(changed);
    expect(diff.changes, isNotEmpty);
    await repository.commitImportedTimetable(changed);

    loaded = await repository.loadSemester(imported.semester.id);
    expect(
      loaded.meetingRules.where((rule) => rule.room == '3601'),
      hasLength(1),
    );

    await repository.saveException(
      CourseException(
        id: 'fixture-add',
        semesterId: imported.semester.id,
        type: CourseExceptionType.add,
        targetDate: DateTime(2026, 9, 9),
        targetStartSection: 5,
        targetEndSection: 6,
        addedCourseName: '临时实验课',
        roomOverride: '实验室 321',
      ),
    );
    loaded = await repository.loadSemester(imported.semester.id);

    final engine = ScheduleEngine(
      semesterId: loaded.semester.id,
      calendarEngine: CalendarEngine(
        CalendarDefinition.fromJson(
          _readJson('assets/calendars/nwu/source/2026-2027-1.json'),
        ),
      ),
      courses: loaded.courses,
      meetingRules: loaded.meetingRules,
      exceptions: loaded.exceptions,
    );

    expect(
      engine
          .getCoursesForDate(DateTime(2026, 9, 7))
          .map((item) => item.courseName),
      contains('软件测试'),
    );
    expect(
      engine
          .getCoursesForDate(DateTime(2026, 9, 8))
          .map((item) => item.courseName),
      contains('计算机网络'),
    );
    expect(
      engine
          .getCoursesForDate(DateTime(2026, 9, 9))
          .map((item) => item.courseName),
      contains('临时实验课'),
    );

    final notifications = const NotificationPlanner().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
      leadMinutes: 15,
      until: DateTime.utc(2026, 9, 10),
    );
    expect(notifications.map((item) => item.title),
        containsAll(<String>['软件测试', '计算机网络', '临时实验课']));

    final snapshot = const WidgetSnapshotBuilder().build(
      engine: engine,
      now: DateTime.utc(2026, 9, 6),
    );
    expect(snapshot.instances.map((item) => item.courseName),
        containsAll(<String>['软件测试', '计算机网络', '临时实验课']));
    expect(
        snapshot.instances.where((item) => item.date == DateTime(2026, 9, 9)),
        hasLength(1));
  });
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}
