import '../../core/utils/week_mask.dart';

enum WeekPattern { all, odd, even }

/// The presentation model used by course forms when selecting teaching weeks.
///
/// [WeekPattern] remains the compact domain representation for regular masks;
/// [custom] keeps an explicit mask so irregular imported schedules are not
/// silently widened to a continuous range.
enum WeekSelectionMode { all, odd, even, custom }

extension WeekSelectionModeLabels on WeekSelectionMode {
  String get label => switch (this) {
        WeekSelectionMode.all => '全部周',
        WeekSelectionMode.odd => '单周',
        WeekSelectionMode.even => '双周',
        WeekSelectionMode.custom => '自定义',
      };
}

extension WeekPatternLabels on WeekPattern {
  String get label => switch (this) {
        WeekPattern.all => '全部周',
        WeekPattern.odd => '单周',
        WeekPattern.even => '双周',
      };
}

WeekMask buildPatternWeekMask({
  required int startWeek,
  required int endWeek,
  required WeekPattern pattern,
  required int totalWeeks,
}) {
  if (totalWeeks < 1 || totalWeeks > 64) {
    throw RangeError.range(totalWeeks, 1, 64, 'totalWeeks');
  }
  if (startWeek < 1 || endWeek > totalWeeks || startWeek > endWeek) {
    throw RangeError('教学周范围无效：$startWeek-$endWeek');
  }
  return WeekMask.fromWeeks(
    [
      for (var week = startWeek; week <= endWeek; week++)
        if (switch (pattern) {
          WeekPattern.all => true,
          WeekPattern.odd => week.isOdd,
          WeekPattern.even => week.isEven,
        })
          week,
    ],
  );
}

class WeekPatternSelection {
  const WeekPatternSelection({
    required this.startWeek,
    required this.endWeek,
    required this.pattern,
    required this.mode,
    required this.isIrregular,
  });

  final int startWeek;
  final int endWeek;
  final WeekPattern pattern;
  final WeekSelectionMode mode;
  final bool isIrregular;
}

WeekPatternSelection inferWeekPattern(WeekMask mask,
    {required int totalWeeks}) {
  final weeks = mask.weeks.where((week) => week <= totalWeeks).toList();
  if (weeks.isEmpty) {
    return WeekPatternSelection(
      startWeek: 1,
      endWeek: totalWeeks,
      pattern: WeekPattern.all,
      mode: WeekSelectionMode.custom,
      isIrregular: true,
    );
  }
  final startWeek = weeks.first;
  final endWeek = weeks.last;
  for (final pattern in WeekPattern.values) {
    final expected = buildPatternWeekMask(
      startWeek: startWeek,
      endWeek: endWeek,
      pattern: pattern,
      totalWeeks: totalWeeks,
    );
    if (expected.value == mask.value) {
      return WeekPatternSelection(
        startWeek: startWeek,
        endWeek: endWeek,
        pattern: pattern,
        mode: switch (pattern) {
          WeekPattern.all => WeekSelectionMode.all,
          WeekPattern.odd => WeekSelectionMode.odd,
          WeekPattern.even => WeekSelectionMode.even,
        },
        isIrregular: false,
      );
    }
  }
  return WeekPatternSelection(
    startWeek: startWeek,
    endWeek: endWeek,
    pattern: WeekPattern.all,
    mode: WeekSelectionMode.custom,
    isIrregular: true,
  );
}
