import '../../core/utils/date_utils.dart';

enum CalendarOverrideType { holiday, useScheduleOf }

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
      'useScheduleOf' || 'USE_SCHEDULE_OF' =>
        CalendarOverrideType.useScheduleOf,
      _ => throw FormatException('Unsupported calendar override: $rawType'),
    };
    final rawSourceDate = json['sourceDate'] as String?;
    return CalendarDateOverride(
      date: dateOnly(parseDateOnly(json['date'] as String)),
      type: type,
      sourceDate: rawSourceDate == null
          ? null
          : dateOnly(parseDateOnly(rawSourceDate)),
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'date': dateKey(date),
      'type': type == CalendarOverrideType.holiday
          ? 'holiday'
          : 'useScheduleOf',
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

  factory CalendarDefinition.fromJson(Map<String, dynamic> json) {
    final overrides = (json['dateOverrides'] ?? json['exceptions'] ?? [])
        as List<dynamic>;
    final definition = CalendarDefinition(
      id: json['id'] as String? ?? 'nwu-${json['academicYear']}-${json['term']}',
      school: json['school'] as String? ?? 'NWU',
      academicYear: json['academicYear'] as String,
      term: (json['term'] as num).toInt(),
      semesterStartDate: dateOnly(
        parseDateOnly(
          (json['semesterStartDate'] ?? json['startDate']) as String,
        ),
      ),
      week1StartDate: dateOnly(
        parseDateOnly(
          (json['week1StartDate'] ?? json['semesterStartDate'] ??
              json['startDate']) as String,
        ),
      ),
      semesterEndDate: dateOnly(
        parseDateOnly(
          (json['semesterEndDate'] ?? json['endDate']) as String,
        ),
      ),
      totalWeeks: (json['totalWeeks'] as num).toInt(),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      dateOverrides: List.unmodifiable(
        overrides.map(
          (item) => CalendarDateOverride.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
    definition.validate();
    return definition;
  }

  void validate() {
    if (school != 'NWU') {
      throw const FormatException('Calendar school must be NWU');
    }
    if (term < 1 || term > 3) {
      throw FormatException('Invalid semester term: $term');
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
    final seen = <String>{};
    for (final override in dateOverrides) {
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
    };
  }
}
