import '../../core/utils/date_utils.dart';

int _requiredIntegral(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

int? _optionalIntegral(Object? value, String key) {
  if (value == null) return null;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

enum CalendarOverrideType { holiday, useScheduleOf }

enum SchoolBreakKind { winter, summer }

class SchoolBreak {
  const SchoolBreak({
    required this.kind,
    required this.label,
    required this.startDate,
    required this.endDate,
    this.reportedWeeks,
    this.reportedDays,
  });

  final SchoolBreakKind kind;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final int? reportedWeeks;
  final int? reportedDays;

  int get actualDays => endDate.difference(startDate).inDays + 1;

  factory SchoolBreak.fromJson(Map<String, dynamic> json) {
    final kind = SchoolBreakKind.values.byName(json['kind'] as String);
    return SchoolBreak(
      kind: kind,
      label: json['label'] as String,
      startDate: parseDateOnly(json['startDate'] as String),
      endDate: parseDateOnly(json['endDate'] as String),
      reportedWeeks: _optionalIntegral(json['reportedWeeks'], 'reportedWeeks'),
      reportedDays: _optionalIntegral(json['reportedDays'], 'reportedDays'),
    );
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'label': label,
        'startDate': dateKey(startDate),
        'endDate': dateKey(endDate),
        if (reportedWeeks != null) 'reportedWeeks': reportedWeeks,
        if (reportedDays != null) 'reportedDays': reportedDays,
      };
}

class CalendarDateOverride {
  const CalendarDateOverride({
    required this.date,
    required this.type,
    this.sourceDate,
    required this.label,
  });

  final DateTime date;
  final CalendarOverrideType type;
  final DateTime? sourceDate;
  final String label;

  factory CalendarDateOverride.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final type = switch (rawType) {
      'holiday' || 'NO_CLASS' => CalendarOverrideType.holiday,
      'useScheduleOf' ||
      'USE_SCHEDULE_OF' =>
        CalendarOverrideType.useScheduleOf,
      _ => throw FormatException('Unsupported calendar override: $rawType'),
    };
    final rawSourceDate = json['sourceDate'] as String?;
    return CalendarDateOverride(
      date: dateOnly(parseDateOnly(json['date'] as String)),
      type: type,
      sourceDate:
          rawSourceDate == null ? null : dateOnly(parseDateOnly(rawSourceDate)),
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'date': dateKey(date),
      'type':
          type == CalendarOverrideType.holiday ? 'holiday' : 'useScheduleOf',
      if (sourceDate != null) 'sourceDate': dateKey(sourceDate!),
      'label': label,
    };
  }
}

class CalendarDefinition {
  const CalendarDefinition({
    required this.id,
    required this.school,
    required this.academicYear,
    required this.term,
    required this.semesterStartDate,
    required this.week1StartDate,
    required this.semesterEndDate,
    required this.totalWeeks,
    required this.revision,
    required this.dateOverrides,
    this.followingBreak,
  });

  final String id;
  final String school;
  final String academicYear;
  final int term;
  final DateTime semesterStartDate;
  final DateTime week1StartDate;
  final DateTime semesterEndDate;
  final int totalWeeks;
  final int revision;
  final List<CalendarDateOverride> dateOverrides;
  final SchoolBreak? followingBreak;

  factory CalendarDefinition.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != null && json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported calendar schemaVersion');
    }
    final explicit =
        (json['dateOverrides'] ?? json['exceptions'] ?? []) as List<dynamic>;
    final overrides = <CalendarDateOverride>[
      ...explicit.map((item) => CalendarDateOverride.fromJson(
            Map<String, dynamic>.from(item as Map),
          )),
      ..._expandHolidayPeriods(json),
      ..._parseMakeupDays(json),
    ];
    final definition = CalendarDefinition(
      id: json['id'] as String,
      school: json['school'] as String,
      academicYear: json['academicYear'] as String,
      term: _requiredIntegral(json, 'term'),
      semesterStartDate: dateOnly(
        parseDateOnly(
          (json['semesterStartDate'] ?? json['startDate']) as String,
        ),
      ),
      week1StartDate: dateOnly(
        parseDateOnly(
          (json['week1StartDate'] ??
              json['semesterStartDate'] ??
              json['startDate']) as String,
        ),
      ),
      semesterEndDate: dateOnly(
        parseDateOnly(
          (json['semesterEndDate'] ?? json['endDate']) as String,
        ),
      ),
      totalWeeks: _requiredIntegral(json, 'totalWeeks'),
      revision: _requiredIntegral(json, 'revision'),
      dateOverrides: List.unmodifiable(overrides),
      followingBreak: json['followingBreak'] == null
          ? null
          : SchoolBreak.fromJson(
              Map<String, dynamic>.from(json['followingBreak'] as Map),
            ),
    );
    definition.validate();
    return definition;
  }

  void validate() {
    if (id.trim().isEmpty) {
      throw const FormatException('Calendar id is empty');
    }
    if (school != 'NWU') {
      throw const FormatException('Calendar school must be NWU');
    }
    final yearMatch = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(academicYear);
    if (yearMatch == null ||
        int.parse(yearMatch.group(2)!) != int.parse(yearMatch.group(1)!) + 1) {
      throw FormatException('Invalid academicYear: $academicYear');
    }
    if (term < 1 || term > 3) {
      throw FormatException('Invalid semester term: $term');
    }
    if (revision < 1) {
      throw FormatException('Invalid revision: $revision');
    }
    if (totalWeeks < 1 || totalWeeks > 64) {
      throw FormatException('Invalid totalWeeks: $totalWeeks');
    }
    if (semesterStartDate.isAfter(semesterEndDate)) {
      throw const FormatException('Semester start is after semester end');
    }
    if (week1StartDate.isBefore(semesterStartDate) ||
        week1StartDate.isAfter(semesterEndDate)) {
      throw const FormatException('week1StartDate is outside semester');
    }
    if (week1StartDate.weekday != DateTime.monday) {
      throw const FormatException('week1StartDate must be Monday');
    }
    if (weekStart(totalWeeks).isAfter(semesterEndDate)) {
      throw const FormatException('totalWeeks extends past semester end');
    }
    final schoolBreak = followingBreak;
    if (schoolBreak != null &&
        (schoolBreak.startDate.isAfter(schoolBreak.endDate) ||
            !schoolBreak.startDate.isAfter(semesterEndDate) ||
            schoolBreak.label.trim().isEmpty ||
            (schoolBreak.reportedDays != null &&
                schoolBreak.reportedDays != schoolBreak.actualDays) ||
            (schoolBreak.reportedWeeks != null &&
                schoolBreak.reportedWeeks! < 1))) {
      throw const FormatException('Invalid followingBreak');
    }
    final seen = <String>{};
    for (final override in dateOverrides) {
      if (override.date.isBefore(semesterStartDate) ||
          override.date.isAfter(semesterEndDate)) {
        throw FormatException(
          'Calendar override date is outside semester: ${dateKey(override.date)}',
        );
      }
      if (!seen.add(dateKey(override.date))) {
        throw FormatException(
          'Duplicate calendar override: ${dateKey(override.date)}',
        );
      }
      if (override.type == CalendarOverrideType.useScheduleOf &&
          override.sourceDate == null) {
        throw const FormatException('useScheduleOf requires sourceDate');
      }
      if (override.sourceDate != null &&
          (override.sourceDate!.isBefore(semesterStartDate) ||
              override.sourceDate!.isAfter(semesterEndDate))) {
        throw FormatException(
          'Calendar sourceDate is outside semester: ${dateKey(override.sourceDate!)}',
        );
      }
    }
  }

  CalendarDateOverride? overrideFor(DateTime date) {
    final key = dateKey(dateOnly(date));
    for (final override in dateOverrides) {
      if (dateKey(override.date) == key) {
        return override;
      }
    }
    return null;
  }

  DateTime weekStart(int teachingWeek) {
    if (teachingWeek < 1 || teachingWeek > totalWeeks) {
      throw RangeError('Teaching week out of range: $teachingWeek');
    }
    return week1StartDate.add(Duration(days: (teachingWeek - 1) * 7));
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'school': school,
      'academicYear': academicYear,
      'term': term,
      'semesterStartDate': dateKey(semesterStartDate),
      'week1StartDate': dateKey(week1StartDate),
      'semesterEndDate': dateKey(semesterEndDate),
      'totalWeeks': totalWeeks,
      'revision': revision,
      'dateOverrides': dateOverrides.map((item) => item.toJson()).toList(),
      if (followingBreak != null) 'followingBreak': followingBreak!.toJson(),
    };
  }
}

List<CalendarDateOverride> _expandHolidayPeriods(Map<String, dynamic> json) {
  final raw = (json['holidayPeriods'] as List<dynamic>?) ?? const [];
  final result = <CalendarDateOverride>[];
  for (final entry in raw) {
    final item = Map<String, dynamic>.from(entry as Map);
    final name = item['name'] as String;
    final start = parseDateOnly(item['startDate'] as String);
    final end = parseDateOnly(item['endDate'] as String);
    final days = end.difference(start).inDays + 1;
    if (name.trim().isEmpty || days < 1 || days > 366) {
      throw FormatException('Invalid holiday period: $name');
    }
    for (var offset = 0; offset < days; offset++) {
      result.add(CalendarDateOverride(
        date: start.add(Duration(days: offset)),
        type: CalendarOverrideType.holiday,
        label: '$name放假',
      ));
    }
  }
  return result;
}

List<CalendarDateOverride> _parseMakeupDays(Map<String, dynamic> json) {
  final raw = (json['makeupDays'] as List<dynamic>?) ?? const [];
  return raw.map((entry) {
    final item = Map<String, dynamic>.from(entry as Map);
    return CalendarDateOverride(
      date: parseDateOnly(item['date'] as String),
      type: CalendarOverrideType.useScheduleOf,
      sourceDate: parseDateOnly(item['useScheduleOf'] as String),
      label: item['label'] as String? ?? '调休',
    );
  }).toList();
}
