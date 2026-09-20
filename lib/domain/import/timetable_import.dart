import '../../core/nwu/periods.dart';
import '../../core/utils/week_mask.dart';

class RemoteSemester {
  const RemoteSemester({
    required this.remoteTermKey,
    required this.academicYear,
    required this.term,
    required this.label,
    this.calendarId,
    this.totalWeeks,
  });

  final String remoteTermKey;
  final String academicYear;
  final int term;
  final String label;
  final String? calendarId;
  final int? totalWeeks;

  String get id => 'nwu-$academicYear-$term';

  Map<String, Object?> toJson() => {
        'remoteTermKey': remoteTermKey,
        'academicYear': academicYear,
        'term': term,
        'label': label,
        if (calendarId != null) 'calendarId': calendarId,
        if (totalWeeks != null) 'totalWeeks': totalWeeks,
      };
}

class ImportedMeeting {
  const ImportedMeeting({
    required this.sourceMeetingKey,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.teacher,
    required this.campus,
    required this.room,
    required this.weekMask,
  });

  final String sourceMeetingKey;
  final int weekday;
  final int startSection;
  final int endSection;
  final String? teacher;
  final String? campus;
  final String? room;
  final WeekMask weekMask;

  Map<String, Object?> toJson() => {
        'sourceMeetingKey': sourceMeetingKey,
        'weekday': weekday,
        'startSection': startSection,
        'endSection': endSection,
        'teacher': teacher,
        'campus': campus,
        'room': room,
        'weekMask': weekMask.value,
        'rawWeekText': weekMask.rawText,
      };
}

class ImportedCourse {
  const ImportedCourse({
    required this.sourceCourseKey,
    required this.name,
    required this.code,
    required this.teachingClass,
    required this.credits,
    required this.assessment,
    required this.meetings,
  });

  final String sourceCourseKey;
  final String name;
  final String? code;
  final String? teachingClass;
  final double? credits;
  final String? assessment;
  final List<ImportedMeeting> meetings;

  Map<String, Object?> toJson() => {
        'sourceCourseKey': sourceCourseKey,
        'name': name,
        'code': code,
        'teachingClass': teachingClass,
        'credits': credits,
        'assessment': assessment,
        'meetings': meetings.map((item) => item.toJson()).toList(),
      };
}

class RemoteTimetable {
  const RemoteTimetable({
    required this.semester,
    required this.totalWeeks,
    required this.courses,
    this.issues = const [],
  });

  final RemoteSemester semester;
  final int totalWeeks;
  final List<ImportedCourse> courses;
  final List<ImportIssue> issues;

  Map<String, Object?> toJson() => {
        'semester': semester.toJson(),
        'totalWeeks': totalWeeks,
        'courses': courses.map((item) => item.toJson()).toList(),
        if (issues.isNotEmpty)
          'issues': issues.map((item) => item.toJson()).toList(),
      };
}

enum ImportIssueSeverity { warning, error }

class ImportIssue {
  const ImportIssue({
    required this.path,
    required this.message,
    required this.severity,
  });

  final String path;
  final String message;
  final ImportIssueSeverity severity;

  Map<String, Object?> toJson() => {
        'path': path,
        'message': message,
        'severity': severity.name,
      };

  static ImportIssue? fromJson(Object? value) {
    if (value is! Map) return null;
    final path = value['path'];
    final message = value['message'];
    final severity = value['severity'];
    if (path is! String ||
        path.trim().isEmpty ||
        message is! String ||
        message.trim().isEmpty) {
      return null;
    }
    final parsedSeverity = switch (severity) {
      'error' => ImportIssueSeverity.error,
      'warning' => ImportIssueSeverity.warning,
      _ => null,
    };
    if (parsedSeverity == null) return null;
    return ImportIssue(
      path: path,
      message: message,
      severity: parsedSeverity,
    );
  }

  @override
  String toString() => '$path: $message';
}

class ImportValidationReport {
  const ImportValidationReport(this.issues);

  final List<ImportIssue> issues;

  bool get isValid =>
      issues.every((issue) => issue.severity != ImportIssueSeverity.error);

  int get errorCount => issues
      .where((issue) => issue.severity == ImportIssueSeverity.error)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == ImportIssueSeverity.warning)
      .length;
}

class TimetableImportValidationException implements Exception {
  const TimetableImportValidationException(this.report);

  final ImportValidationReport report;

  @override
  String toString() => 'Timetable import validation failed: ${report.issues}';
}

class TimetableImportConflictException implements Exception {
  const TimetableImportConflictException(this.diff);

  final Object diff;

  @override
  String toString() => 'Timetable import contains unresolved conflicts';
}

class TimetableImportParser {
  const TimetableImportParser();

  RemoteTimetable parse(Map<String, dynamic> json) {
    final semester = parseSemester(json);
    final totalWeeks = semester.totalWeeks ?? 20;
    final rawCourses = json['courses'] ?? json['courseList'] ?? json['rows'];
    if (rawCourses is! List) {
      throw const FormatException('courses must be a list');
    }
    final courses = <ImportedCourse>[];
    for (var index = 0; index < rawCourses.length; index++) {
      courses.add(_parseCourse(
        _map(rawCourses[index]),
        index: index,
        totalWeeks: totalWeeks,
      ));
    }
    return RemoteTimetable(
      semester: semester,
      totalWeeks: totalWeeks,
      courses: List.unmodifiable(courses),
      issues: _parseIssues(json['issues']),
    );
  }

  List<ImportIssue> _parseIssues(Object? value) {
    if (value is! List) return const [];
    return List.unmodifiable([
      for (final item in value)
        if (ImportIssue.fromJson(item) case final issue?) issue,
    ]);
  }

  RemoteSemester parseSemester(Map<String, dynamic> json) {
    final rawSemester = _map(
      json['semester'] ?? json['remoteSemester'] ?? json,
    );
    final remoteTermKey = _string(
      rawSemester['remoteTermKey'] ??
          rawSemester['termKey'] ??
          rawSemester['id'] ??
          json['remoteTermKey'],
      'semester.remoteTermKey',
    );
    final academicYear = _string(
      rawSemester['academicYear'] ?? json['academicYear'],
      'semester.academicYear',
    );
    final term = _int(rawSemester['term'] ?? json['term'], 'semester.term');
    final label = _string(
      rawSemester['label'] ?? rawSemester['name'] ?? '$academicYear 第$term学期',
      'semester.label',
    );
    final totalWeeks = _int(
      rawSemester['totalWeeks'] ?? json['totalWeeks'] ?? 20,
      'totalWeeks',
    );
    return RemoteSemester(
      remoteTermKey: remoteTermKey,
      academicYear: academicYear,
      term: term,
      label: label,
      calendarId: rawSemester['calendarId'] as String?,
      totalWeeks: totalWeeks,
    );
  }

  ImportedCourse _parseCourse(
    Map<String, dynamic> json, {
    required int index,
    required int totalWeeks,
  }) {
    final key = _string(
      json['sourceCourseKey'] ??
          json['courseKey'] ??
          json['courseId'] ??
          json['id'] ??
          json['kch'],
      'courses[$index].sourceCourseKey',
    );
    final rawMeetings = json['meetings'] ?? json['rules'] ?? json['schedule'];
    if (rawMeetings is! List) {
      throw FormatException('courses[$index].meetings must be a list');
    }
    return ImportedCourse(
      sourceCourseKey: key,
      name: _string(
        json['name'] ?? json['courseName'] ?? json['kcmc'],
        'courses[$index].name',
      ),
      code: _optionalString(json['code'] ?? json['courseCode'] ?? json['kch']),
      teachingClass: _optionalString(
        json['teachingClass'] ?? json['className'] ?? json['jxbmc'],
      ),
      credits: _optionalDouble(json['credits'] ?? json['credit'] ?? json['xf']),
      assessment: _optionalString(
        json['assessment'] ?? json['assessmentType'] ?? json['ksxz'],
      ),
      meetings: List.unmodifiable([
        for (var meetingIndex = 0;
            meetingIndex < rawMeetings.length;
            meetingIndex++)
          _parseMeeting(
            _map(rawMeetings[meetingIndex]),
            courseIndex: index,
            meetingIndex: meetingIndex,
            totalWeeks: totalWeeks,
          ),
      ]),
    );
  }

  ImportedMeeting _parseMeeting(
    Map<String, dynamic> json, {
    required int courseIndex,
    required int meetingIndex,
    required int totalWeeks,
  }) {
    final path = 'courses[$courseIndex].meetings[$meetingIndex]';
    final sourceKey = _string(
      json['sourceMeetingKey'] ??
          json['meetingKey'] ??
          json['id'] ??
          '$courseIndex-$meetingIndex',
      '$path.sourceMeetingKey',
    );
    final weekday = _int(
      json['weekday'] ?? json['weekDay'] ?? json['xqj'],
      '$path.weekday',
    );
    final sectionRange = _sectionRange(json);
    final rawWeekMask = json['weekMask'];
    final rawWeekText = (json['weekText'] ??
            json['weeks'] ??
            json['weekRule'] ??
            json['zcd'] ??
            '1-$totalWeeks周')
        .toString();
    final weekMask = rawWeekMask is num
        ? WeekMask(
            rawWeekMask.toInt(),
            rawText: json['rawWeekText']?.toString() ?? rawWeekText,
          )
        : _parseWeekMask(
            rawWeekText,
            path: '$path.weekText',
            maxWeek: totalWeeks,
          );
    return ImportedMeeting(
      sourceMeetingKey: sourceKey,
      weekday: weekday,
      startSection: sectionRange.$1,
      endSection: sectionRange.$2,
      teacher:
          _optionalString(json['teacher'] ?? json['teacherName'] ?? json['js']),
      campus:
          _optionalString(json['campus'] ?? json['campusName'] ?? json['xq']),
      room: _optionalString(json['room'] ?? json['roomName'] ?? json['jxcd']),
      weekMask: weekMask,
    );
  }

  WeekMask _parseWeekMask(
    String rawText, {
    required String path,
    required int maxWeek,
  }) {
    try {
      return WeekMask.parse(rawText, maxWeek: maxWeek);
    } on Object catch (error) {
      throw FormatException(
        '$path 无法解析：raw="$rawText"；$error',
      );
    }
  }

  (int, int) _sectionRange(Map<String, dynamic> json) {
    final start = json['startSection'] ?? json['start'] ?? json['ksjc'];
    final end = json['endSection'] ?? json['end'] ?? json['jsjc'];
    if (start != null && end != null) {
      return (_int(start, 'startSection'), _int(end, 'endSection'));
    }
    final raw = json['sectionText'] ?? json['sections'] ?? json['jcs'];
    if (raw is List && raw.isNotEmpty) {
      final values = raw.map((item) => _int(item, 'sections')).toList()..sort();
      return (values.first, values.last);
    }
    if (raw is String) {
      final matches = RegExp(r'\d+')
          .allMatches(raw)
          .map((m) => int.parse(m.group(0)!))
          .toList();
      if (matches.length >= 2) {
        return (matches.first, matches.last);
      }
      if (matches.length == 1) {
        return (matches.single, matches.single);
      }
    }
    throw const FormatException('meeting section range is missing');
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Expected an object');
  }

  static String _string(Object? value, String path) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('$path must be a non-empty string');
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return value.toString().trim().isEmpty ? null : value.toString().trim();
  }

  static int _int(Object? value, String path) {
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('$path must be an integer');
  }

  static double? _optionalDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}

ImportValidationReport validateTimetable(RemoteTimetable timetable) {
  final issues = <ImportIssue>[...timetable.issues];
  final semester = timetable.semester;
  if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(semester.academicYear)) {
    issues.add(const ImportIssue(
      path: 'semester.academicYear',
      message: '学年度格式无效',
      severity: ImportIssueSeverity.error,
    ));
  }
  if (semester.term < 1 || semester.term > 3) {
    issues.add(const ImportIssue(
      path: 'semester.term',
      message: '学期必须为 1、2 或 3',
      severity: ImportIssueSeverity.error,
    ));
  }
  if (timetable.totalWeeks < 1 || timetable.totalWeeks > 64) {
    issues.add(const ImportIssue(
      path: 'totalWeeks',
      message: '教学周必须在 1 到 64 之间',
      severity: ImportIssueSeverity.error,
    ));
  }
  final courseKeys = <String>{};
  for (var courseIndex = 0;
      courseIndex < timetable.courses.length;
      courseIndex++) {
    final course = timetable.courses[courseIndex];
    final coursePath = 'courses[$courseIndex]';
    if (course.name.trim().isEmpty) {
      issues.add(ImportIssue(
        path: '$coursePath.name',
        message: '课程名不能为空',
        severity: ImportIssueSeverity.error,
      ));
    }
    if (!courseKeys.add(course.sourceCourseKey)) {
      issues.add(ImportIssue(
        path: '$coursePath.sourceCourseKey',
        message: '课程源 ID 重复',
        severity: ImportIssueSeverity.error,
      ));
    }
    final meetingKeys = <String>{};
    for (var meetingIndex = 0;
        meetingIndex < course.meetings.length;
        meetingIndex++) {
      final meeting = course.meetings[meetingIndex];
      final path = '$coursePath.meetings[$meetingIndex]';
      if (meeting.weekday < 1 || meeting.weekday > 7) {
        issues.add(ImportIssue(
          path: '$path.weekday',
          message: '星期必须在 1 到 7 之间',
          severity: ImportIssueSeverity.error,
        ));
      }
      if (meeting.startSection < 1 ||
          meeting.endSection > NwuPeriodRepository.all.length ||
          meeting.startSection > meeting.endSection) {
        issues.add(ImportIssue(
          path: path,
          message: '节次范围无效',
          severity: ImportIssueSeverity.error,
        ));
      }
      if (meeting.weekMask.weeks.any((week) => week > timetable.totalWeeks)) {
        issues.add(ImportIssue(
          path: '$path.weekText',
          message: '周次超过学期教学周',
          severity: ImportIssueSeverity.error,
        ));
      }
      if (!meetingKeys.add(meeting.sourceMeetingKey)) {
        issues.add(ImportIssue(
          path: '$path.sourceMeetingKey',
          message: '同一课程的上课安排源 ID 重复',
          severity: ImportIssueSeverity.error,
        ));
      }
    }
    if (course.meetings.isEmpty) {
      issues.add(ImportIssue(
        path: '$coursePath.meetings',
        message: '课程没有上课安排，将不会出现在课表中',
        severity: ImportIssueSeverity.warning,
      ));
    }
  }
  return ImportValidationReport(List.unmodifiable(issues));
}
