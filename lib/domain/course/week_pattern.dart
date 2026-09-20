import '../../core/utils/week_mask.dart';

enum WeekPattern { all, odd, even }

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
    required this.isIrregular,
  });

  final int startWeek;
  final int endWeek;
  final WeekPattern pattern;
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
        isIrregular: false,
      );
    }
  }
  return WeekPatternSelection(
    startWeek: startWeek,
    endWeek: endWeek,
    pattern: WeekPattern.all,
    isIrregular: true,
  );
}
