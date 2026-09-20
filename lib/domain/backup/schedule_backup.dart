import 'dart:convert';

import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/week_mask.dart';
import '../course/course.dart';
import '../course/course_exception.dart';
import '../course/meeting_rule.dart';
import '../semester/semester.dart';

String _backupRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw BackupValidationException('$key 必须是非空字符串');
}

String? _backupOptionalString(Object? value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int _backupRequiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw BackupValidationException('$key 必须是整数');
}

/// Maps the display fields in the backup appearance object to local settings.
///
/// This belongs to the backup contract rather than the Flutter UI so the data
/// repository can restore the complete appearance atomically with the dataset.
const backupScheduleDisplaySettingKeys = <String, String>{
  'showWeekend': 'schedule.weekView.showWeekend',
  'showTeacher': 'schedule.weekView.showTeacher',
  'showInactiveCourses': 'schedule.weekView.showInactiveCourses',
  'showPeriodTimes': 'schedule.weekView.showPeriodTimes',
  'highlightCurrentPeriod': 'schedule.weekView.highlightCurrentPeriod',
  'showBackToCurrentWeekFab': 'schedule.weekView.showBackToCurrentWeekFab',
};

DateTime _backupRequiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw BackupValidationException('$key 必须是 ISO 日期');
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => 'Invalid schedule backup: $message';
}

class BackupImportSnapshot {
  const BackupImportSnapshot({
    required this.id,
    required this.semesterId,
    required this.importedAt,
    required this.adapterVersion,
    required this.schemaVersion,
    required this.normalizedJson,
    required this.hash,
  });

  final String id;
  final String semesterId;
  final DateTime importedAt;
  final String adapterVersion;
  final int schemaVersion;
  final String normalizedJson;
  final String hash;

  Map<String, Object?> toJson() => {
        'id': id,
        'semesterId': semesterId,
        'importedAt': importedAt.toUtc().toIso8601String(),
        'adapterVersion': adapterVersion,
        'schemaVersion': schemaVersion,
        'normalizedJson': normalizedJson,
        'hash': hash,
      };

  static BackupImportSnapshot fromJson(Map<String, dynamic> json) {
    return BackupImportSnapshot(
      id: _backupRequiredString(json, 'id'),
      semesterId: _backupRequiredString(json, 'semesterId'),
      importedAt: _backupRequiredDate(json, 'importedAt'),
      adapterVersion: _backupRequiredString(json, 'adapterVersion'),
      schemaVersion: _backupRequiredInt(json, 'schemaVersion'),
      normalizedJson: _backupRequiredString(json, 'normalizedJson'),
      hash: _backupRequiredString(json, 'hash'),
    );
  }
}

class BackupDeletedSourceItem {
  const BackupDeletedSourceItem({
    required this.id,
    required this.semesterId,
    required this.sourceCourseKey,
    this.sourceMeetingKey,
    required this.deletedAt,
  });

  final String id;
  final String semesterId;
  final String sourceCourseKey;
  final String? sourceMeetingKey;
  final DateTime deletedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'semesterId': semesterId,
        'sourceCourseKey': sourceCourseKey,
        'sourceMeetingKey': sourceMeetingKey,
        'deletedAt': deletedAt.toUtc().toIso8601String(),
      };

  static BackupDeletedSourceItem fromJson(Map<String, dynamic> json) {
    return BackupDeletedSourceItem(
      id: _backupRequiredString(json, 'id'),
      semesterId: _backupRequiredString(json, 'semesterId'),
      sourceCourseKey: _backupRequiredString(json, 'sourceCourseKey'),
      sourceMeetingKey: _backupOptionalString(json['sourceMeetingKey']),
      deletedAt: _backupRequiredDate(json, 'deletedAt'),
    );
  }
}

class ScheduleBackup {
  const ScheduleBackup({
    required this.createdAt,
    required this.semesters,
    required this.courses,
    required this.meetingRules,
    required this.exceptions,
    required this.settings,
    required this.appearance,
    this.importSnapshots = const [],
    this.deletedSourceItems = const [],
  });

  static const format = 'nwu-schedule-backup';
  static const schemaVersion = 1;

  final DateTime createdAt;
  final List<Semester> semesters;
  final List<Course> courses;
  final List<MeetingRule> meetingRules;
  final List<CourseException> exceptions;
  final Map<String, String> settings;
  final Map<String, Object?> appearance;
  final List<BackupImportSnapshot> importSnapshots;
  final List<BackupDeletedSourceItem> deletedSourceItems;

  Map<String, Object?> toJson() => {
        'format': format,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'semesters': semesters.map(_semesterToJson).toList(),
        'courses': courses.map(_courseToJson).toList(),
        'meetingRules': meetingRules.map(_meetingRuleToJson).toList(),
        'exceptions': exceptions.map(_exceptionToJson).toList(),
        'settings': settings,
        'appearance': appearance,
        'importSnapshots':
            importSnapshots.map((item) => item.toJson()).toList(),
        'deletedSourceItems':
            deletedSourceItems.map((item) => item.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  static ScheduleBackup decode(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const BackupValidationException('根对象必须是 JSON 对象');
    }
    return fromJson(Map<String, dynamic>.from(decoded));
  }

  static ScheduleBackup fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw BackupValidationException('format 必须为 $format');
    }
    if (json['schemaVersion'] != schemaVersion) {
      throw BackupValidationException(
        '不支持的 schemaVersion：${json['schemaVersion']}',
      );
    }
    final backup = ScheduleBackup(
      createdAt: _requiredDate(json, 'createdAt'),
      semesters: _records(json, 'semesters', (item) => _semesterFromJson(item)),
      courses: _records(json, 'courses', (item) => _courseFromJson(item)),
      meetingRules:
          _records(json, 'meetingRules', (item) => _meetingRuleFromJson(item)),
      exceptions:
          _records(json, 'exceptions', (item) => _exceptionFromJson(item)),
      settings: _settings(json['settings']),
      appearance: _appearance(json['appearance']),
      importSnapshots: _records(
        json,
        'importSnapshots',
        (item) => BackupImportSnapshot.fromJson(item),
        required: false,
      ),
      deletedSourceItems: _records(
        json,
        'deletedSourceItems',
        (item) => BackupDeletedSourceItem.fromJson(item),
        required: false,
      ),
    );
    _validateReferences(backup);
    return backup;
  }

  static Map<String, Object?> _semesterToJson(Semester semester) => {
        'id': semester.id,
        'academicYear': semester.academicYear,
        'term': semester.term.name,
        'label': semester.label,
        'remoteTermKey': semester.remoteTermKey,
        'calendarId': semester.calendarId,
        'calendarRevision': semester.calendarRevision,
        'createdAt': semester.createdAt.toUtc().toIso8601String(),
      };

  static Map<String, Object?> _courseToJson(Course course) => {
        'id': course.id,
        'semesterId': course.semesterId,
        'sourceType': course.sourceType.name,
        'sourceCourseKey': course.sourceCourseKey,
        'name': course.name,
        'note': course.note,
        'colorOverride': course.colorOverride,
        'hidden': course.hidden,
        'deleted': course.deleted,
        'createdAt': course.createdAt.toUtc().toIso8601String(),
        'updatedAt': course.updatedAt.toUtc().toIso8601String(),
      };

  static Map<String, Object?> _meetingRuleToJson(MeetingRule rule) => {
        'id': rule.id,
        'courseId': rule.courseId,
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

  static Map<String, Object?> _exceptionToJson(CourseException exception) => {
        'id': exception.id,
        'semesterId': exception.semesterId,
        'courseId': exception.courseId,
        'sourceMeetingId': exception.sourceMeetingId,
        'sourceDate': exception.sourceDate == null
            ? null
            : dateKey(exception.sourceDate!),
        'type': exception.type.name,
        'targetDate': exception.targetDate == null
            ? null
            : dateKey(exception.targetDate!),
        'targetStartSection': exception.targetStartSection,
        'targetEndSection': exception.targetEndSection,
        'teacherOverride': exception.teacherOverride,
        'campusOverride': exception.campusOverride,
        'roomOverride': exception.roomOverride,
        'addedCourseName': exception.addedCourseName,
        'note': exception.note,
      };

  static Semester _semesterFromJson(Map<String, dynamic> json) {
    return Semester(
      id: _requiredString(json, 'id'),
      academicYear: _requiredString(json, 'academicYear'),
      term: _enumValue<SemesterTerm>(
        json['term'],
        SemesterTerm.values,
        'term',
      ),
      label: _requiredString(json, 'label'),
      remoteTermKey: _optionalString(json['remoteTermKey']),
      calendarId: _optionalString(json['calendarId']),
      calendarRevision: _optionalInt(json['calendarRevision']),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  static Course _courseFromJson(Map<String, dynamic> json) {
    return Course(
      id: _requiredString(json, 'id'),
      semesterId: _requiredString(json, 'semesterId'),
      sourceType: _enumValue<CourseSourceType>(
        json['sourceType'],
        CourseSourceType.values,
        'sourceType',
      ),
      sourceCourseKey: _optionalString(json['sourceCourseKey']),
      name: _requiredString(json, 'name'),
      note: _optionalString(json['note']),
      colorOverride: _optionalInt(json['colorOverride']),
      hidden: _bool(json, 'hidden'),
      deleted: _bool(json, 'deleted'),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
    );
  }

  static MeetingRule _meetingRuleFromJson(Map<String, dynamic> json) {
    return MeetingRule(
      id: _requiredString(json, 'id'),
      courseId: _requiredString(json, 'courseId'),
      sourceMeetingKey: _optionalString(json['sourceMeetingKey']),
      weekday: _requiredInt(json, 'weekday'),
      startSection: _requiredInt(json, 'startSection'),
      endSection: _requiredInt(json, 'endSection'),
      teacher: _optionalString(json['teacher']),
      campus: _optionalString(json['campus']),
      room: _optionalString(json['room']),
      weekMask: WeekMask(
        _requiredInt(json, 'weekMask'),
        rawText: _optionalString(json['rawWeekText']) ?? '',
      ),
    );
  }

  static CourseException _exceptionFromJson(Map<String, dynamic> json) {
    return CourseException(
      id: _requiredString(json, 'id'),
      semesterId: _requiredString(json, 'semesterId'),
      courseId: _optionalString(json['courseId']),
      sourceMeetingId: _optionalString(json['sourceMeetingId']),
      sourceDate: _optionalDomainDate(json['sourceDate']),
      type: _enumValue<CourseExceptionType>(
        json['type'],
        CourseExceptionType.values,
        'type',
      ),
      targetDate: _optionalDomainDate(json['targetDate']),
      targetStartSection: _optionalInt(json['targetStartSection']),
      targetEndSection: _optionalInt(json['targetEndSection']),
      teacherOverride: _optionalString(json['teacherOverride']),
      campusOverride: _optionalString(json['campusOverride']),
      roomOverride: _optionalString(json['roomOverride']),
      addedCourseName: _optionalString(json['addedCourseName']),
      note: _optionalString(json['note']),
    );
  }

  static List<T> _records<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse, {
    bool required = true,
  }) {
    final value = json[key];
    if (value == null && !required) return const [];
    if (value is! List) {
      throw BackupValidationException('$key 必须是数组');
    }
    return [
      for (var index = 0; index < value.length; index++)
        _parseRecord(value[index], '$key[$index]', parse),
    ];
  }

  static T _parseRecord<T>(
    Object? value,
    String path,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (value is! Map) {
      throw BackupValidationException('$path 必须是对象');
    }
    try {
      return parse(Map<String, dynamic>.from(value));
    } on BackupValidationException {
      rethrow;
    } on Object catch (error) {
      throw BackupValidationException('$path 无效：$error');
    }
  }

  static Map<String, String> _settings(Object? value) {
    final map = _objectMap(value, 'settings');
    final result = <String, String>{};
    for (final entry in map.entries) {
      final key = entry.key;
      if (_sensitiveKey.hasMatch(key)) {
        throw BackupValidationException('settings 包含禁止字段：$key');
      }
      if (entry.value is! String) {
        throw BackupValidationException('settings.$key 必须是字符串');
      }
      result[key] = entry.value as String;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Object?> _appearance(Object? value) {
    final map = _objectMap(value, 'appearance');
    _assertNoSensitiveKeys(map, 'appearance');
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      switch (entry.key) {
        case 'themeId':
          final themeId = entry.value;
          if (themeId is! String || themeId.trim().isEmpty) {
            throw const BackupValidationException(
              'appearance.themeId 必须是非空字符串',
            );
          }
          result[entry.key] = themeId;
        case 'themeMode':
          final themeMode = entry.value;
          if (themeMode is! String ||
              !const {'system', 'light', 'dark'}.contains(themeMode)) {
            throw const BackupValidationException(
              'appearance.themeMode 必须是 system、light 或 dark',
            );
          }
          result[entry.key] = themeMode;
        case 'scheduleDisplay':
          final rawDisplay = entry.value;
          if (rawDisplay is! Map) {
            throw const BackupValidationException(
              'appearance.scheduleDisplay 必须是对象',
            );
          }
          final display = <String, Object?>{};
          for (final displayEntry in rawDisplay.entries) {
            final key = displayEntry.key;
            if (key is! String ||
                !backupScheduleDisplaySettingKeys.containsKey(key)) {
              throw BackupValidationException(
                'appearance.scheduleDisplay.$key 不是支持的字段',
              );
            }
            if (displayEntry.value is! bool) {
              throw BackupValidationException(
                'appearance.scheduleDisplay.$key 必须是布尔值',
              );
            }
            display[key] = displayEntry.value;
          }
          result[entry.key] = Map.unmodifiable(display);
        default:
          throw BackupValidationException(
            'appearance.${entry.key} 不是支持的字段',
          );
      }
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Object?> _objectMap(Object? value, String path) {
    if (value == null) return const {};
    if (value is! Map) {
      throw BackupValidationException('$path 必须是对象');
    }
    return Map.unmodifiable(Map<String, Object?>.from(value));
  }

  static void _validateReferences(ScheduleBackup backup) {
    _unique(backup.semesters.map((item) => item.id), 'semester.id');
    _unique(backup.courses.map((item) => item.id), 'course.id');
    _unique(backup.meetingRules.map((item) => item.id), 'meetingRule.id');
    _unique(backup.exceptions.map((item) => item.id), 'exception.id');
    _unique(
      backup.importSnapshots.map((item) => item.id),
      'importSnapshot.id',
    );
    _unique(
      backup.deletedSourceItems.map((item) => item.id),
      'deletedSourceItem.id',
    );
    final semesterIds = backup.semesters.map((item) => item.id).toSet();
    final courseIds = backup.courses.map((item) => item.id).toSet();
    final coursesById = {
      for (final course in backup.courses) course.id: course,
    };
    final rulesById = {
      for (final rule in backup.meetingRules) rule.id: rule,
    };
    final preferredSemesterId = backup.settings['preferredSemesterId'];
    if (preferredSemesterId != null &&
        !semesterIds.contains(preferredSemesterId)) {
      throw BackupValidationException(
        'preferredSemesterId 引用了不存在的学期 $preferredSemesterId',
      );
    }
    for (final course in backup.courses) {
      if (!semesterIds.contains(course.semesterId)) {
        throw BackupValidationException(
          '课程 ${course.id} 引用了不存在的学期 ${course.semesterId}',
        );
      }
    }
    for (final rule in backup.meetingRules) {
      if (!courseIds.contains(rule.courseId)) {
        throw BackupValidationException(
          '上课安排 ${rule.id} 引用了不存在的课程 ${rule.courseId}',
        );
      }
    }
    for (final exception in backup.exceptions) {
      if (!semesterIds.contains(exception.semesterId)) {
        throw BackupValidationException(
          '调课记录 ${exception.id} 引用了不存在的学期 ${exception.semesterId}',
        );
      }
      if (exception.courseId != null &&
          !courseIds.contains(exception.courseId)) {
        throw BackupValidationException(
          '调课记录 ${exception.id} 引用了不存在的课程 ${exception.courseId}',
        );
      }
      final course =
          exception.courseId == null ? null : coursesById[exception.courseId];
      if (course != null && course.semesterId != exception.semesterId) {
        throw BackupValidationException(
          '调课记录 ${exception.id} 的课程与学期不一致',
        );
      }
      if (exception.type != CourseExceptionType.add) {
        final sourceMeetingId = exception.sourceMeetingId;
        final rule =
            sourceMeetingId == null ? null : rulesById[sourceMeetingId];
        if (rule == null) {
          throw BackupValidationException(
            '调课记录 ${exception.id} 引用了不存在的上课安排 $sourceMeetingId',
          );
        }
        if (rule.courseId != exception.courseId) {
          throw BackupValidationException(
            '调课记录 ${exception.id} 的上课安排与课程不一致',
          );
        }
      }
    }
    for (final snapshot in backup.importSnapshots) {
      if (!semesterIds.contains(snapshot.semesterId)) {
        throw BackupValidationException(
          '导入快照 ${snapshot.id} 引用了不存在的学期 ${snapshot.semesterId}',
        );
      }
      try {
        final normalized = jsonDecode(snapshot.normalizedJson);
        if (normalized is! Map) {
          throw const FormatException('normalizedJson 不是对象');
        }
        _assertNoSensitiveKeys(
          normalized,
          '导入快照 ${snapshot.id}.normalizedJson',
        );
      } on Object catch (error) {
        throw BackupValidationException(
          '导入快照 ${snapshot.id} 的 normalizedJson 无效：$error',
        );
      }
    }
    for (final item in backup.deletedSourceItems) {
      if (!semesterIds.contains(item.semesterId)) {
        throw BackupValidationException(
          '删除标记 ${item.id} 引用了不存在的学期 ${item.semesterId}',
        );
      }
    }
  }

  static void _unique(Iterable<String> values, String field) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw BackupValidationException('$field 重复：$value');
      }
    }
  }

  static final _sensitiveKey = RegExp(
    r'(cookie|password|passwd|username|account|session|token|sso|webview|storage)',
    caseSensitive: false,
  );

  static void _assertNoSensitiveKeys(Object? value, String path) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_sensitiveKey.hasMatch(key)) {
          throw BackupValidationException('$path 包含禁止字段：$key');
        }
        _assertNoSensitiveKeys(entry.value, '$path.$key');
      }
      return;
    }
    if (value is List) {
      for (var index = 0; index < value.length; index++) {
        _assertNoSensitiveKeys(value[index], '$path[$index]');
      }
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw BackupValidationException('$key 必须是非空字符串');
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.toInt()) {
      return value.toInt();
    }
    throw BackupValidationException('$key 必须是整数');
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.toInt()) {
      return value.toInt();
    }
    throw BackupValidationException('字段必须是整数');
  }

  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw BackupValidationException('$key 必须是布尔值');
  }

  static DateTime _requiredDate(Map<String, dynamic> json, String key) {
    final value = json[key];
    final date = _optionalDate(value);
    if (date != null) return date;
    throw BackupValidationException('$key 必须是 ISO 日期');
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw BackupValidationException('日期必须是字符串');
    }
    return DateTime.tryParse(value);
  }

  static DateTime? _optionalDomainDate(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const BackupValidationException('日期必须是字符串');
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      try {
        return parseDateOnly(value);
      } on FormatException {
        throw BackupValidationException('日期无效：$value');
      }
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw BackupValidationException('日期无效：$value');
    }
    return dateOnly(CampusClock.toCampusWallTime(parsed));
  }

  static T _enumValue<T>(Object? value, List<T> values, String key) {
    for (final item in values) {
      if (item.toString().split('.').last == value) return item;
    }
    throw BackupValidationException('$key 的值无效：$value');
  }
}
