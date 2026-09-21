import '../../core/utils/week_mask.dart';
import 'meeting_rule.dart';
import 'week_pattern.dart';

class MeetingDraft {
  MeetingDraft({
    required this.id,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.startWeek,
    required this.endWeek,
    required this.pattern,
    required this.teacher,
    required this.campus,
    required this.room,
    this.selectionMode = WeekSelectionMode.all,
    this.sourceMeetingKey,
    this.originalWeekMask,
    this.isIrregular = false,
  });

  factory MeetingDraft.initial({String? id, required int totalWeeks}) {
    return MeetingDraft(
      id: id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      startWeek: 1,
      endWeek: totalWeeks,
      pattern: WeekPattern.all,
      teacher: '',
      campus: '',
      room: '',
      selectionMode: WeekSelectionMode.all,
    );
  }

  factory MeetingDraft.fromRule(MeetingRule rule, {required int totalWeeks}) {
    final selection = inferWeekPattern(rule.weekMask, totalWeeks: totalWeeks);
    return MeetingDraft(
      id: rule.id,
      sourceMeetingKey: rule.sourceMeetingKey,
      weekday: rule.weekday,
      startSection: rule.startSection,
      endSection: rule.endSection,
      startWeek: selection.startWeek,
      endWeek: selection.endWeek,
      pattern: selection.pattern,
      selectionMode: selection.mode,
      teacher: rule.teacher ?? '',
      campus: rule.campus ?? '',
      room: rule.room ?? '',
      originalWeekMask: selection.isIrregular ? rule.weekMask : null,
      isIrregular: selection.isIrregular,
    );
  }

  static const Object _unset = Object();

  final String id;
  final String? sourceMeetingKey;
  final int weekday;
  final int startSection;
  final int endSection;
  final int startWeek;
  final int endWeek;
  final WeekPattern pattern;
  final WeekSelectionMode selectionMode;
  final String teacher;
  final String campus;
  final String room;
  final WeekMask? originalWeekMask;
  final bool isIrregular;

  MeetingDraft copyWith({
    String? id,
    Object? sourceMeetingKey = _unset,
    int? weekday,
    int? startSection,
    int? endSection,
    int? startWeek,
    int? endWeek,
    WeekPattern? pattern,
    WeekSelectionMode? selectionMode,
    String? teacher,
    String? campus,
    String? room,
    Object? originalWeekMask = _unset,
    bool? isIrregular,
  }) {
    return MeetingDraft(
      id: id ?? this.id,
      sourceMeetingKey: identical(sourceMeetingKey, _unset)
          ? this.sourceMeetingKey
          : sourceMeetingKey as String?,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      pattern: pattern ?? this.pattern,
      selectionMode: selectionMode ?? this.selectionMode,
      teacher: teacher ?? this.teacher,
      campus: campus ?? this.campus,
      room: room ?? this.room,
      originalWeekMask: identical(originalWeekMask, _unset)
          ? this.originalWeekMask
          : originalWeekMask as WeekMask?,
      isIrregular: isIrregular ?? this.isIrregular,
    );
  }

  WeekMask weekMask(int totalWeeks) {
    if (selectionMode == WeekSelectionMode.custom && originalWeekMask != null) {
      return originalWeekMask!;
    }
    return buildPatternWeekMask(
      startWeek: startWeek,
      endWeek: endWeek,
      pattern: pattern,
      totalWeeks: totalWeeks,
    );
  }
}
