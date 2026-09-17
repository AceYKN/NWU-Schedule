import '../nwu/constants.dart';

/// Parsed teaching weeks stored as a bit mask.
///
/// The original Zhengfang string is retained separately for diagnostics, but
/// all schedule decisions use [value] through [contains].
class WeekMask {
  const WeekMask(this.value, {this.rawText = ''});

  final int value;
  final String rawText;

  bool contains(int week) {
    if (week < 1 || week > maxSupportedTeachingWeeks) {
      return false;
    }
    return value & (1 << (week - 1)) != 0;
  }

  List<int> get weeks {
    final result = <int>[];
    for (var week = 1; week <= maxSupportedTeachingWeeks; week++) {
      if (contains(week)) {
        result.add(week);
      }
    }
    return result;
  }

  static WeekMask fromWeeks(Iterable<int> weeks, {String rawText = ''}) {
    var value = 0;
    for (final week in weeks) {
      if (week < 1 || week > maxSupportedTeachingWeeks) {
        throw RangeError('Teaching week out of range: $week');
      }
      value |= 1 << (week - 1);
    }
    return WeekMask(value, rawText: rawText);
  }

  static WeekMask all(int totalWeeks, {String rawText = ''}) {
    return fromWeeks(
      List<int>.generate(totalWeeks, (index) => index + 1),
      rawText: rawText,
    );
  }

  /// Parses common Zhengfang forms such as `1-16周`, `单周`, `双周`, and
  /// `1,3,5,7周`. [maxWeek] is only used for parity-only strings.
  static WeekMask parse(String text, {int maxWeek = 20}) {
    final source = text.trim();
    if (source.isEmpty) {
      throw const FormatException('Teaching week text is empty');
    }

    final isOdd = source.contains('单');
    final isEven = source.contains('双');
    if (source.contains('全周') || source.contains('全部')) {
      return all(maxWeek, rawText: source);
    }

    final weeks = <int>{};
    final rangePattern = RegExp(r'(\d+)\s*(?:-|~|～|—|至)\s*(\d+)');
    final rangeMatches = rangePattern.allMatches(source).toList();
    for (final match in rangeMatches) {
      final start = int.parse(match.group(1)!);
      final end = int.parse(match.group(2)!);
      final lower = start <= end ? start : end;
      final upper = start <= end ? end : start;
      for (var week = lower; week <= upper; week++) {
        if (_matchesParity(week, isOdd: isOdd, isEven: isEven)) {
          weeks.add(week);
        }
      }
    }

    var remainder = source;
    for (final match in rangeMatches.reversed) {
      remainder = remainder.replaceRange(match.start, match.end, ' ');
    }
    for (final match in RegExp(r'\d+').allMatches(remainder)) {
      final week = int.parse(match.group(0)!);
      if (_matchesParity(week, isOdd: isOdd, isEven: isEven)) {
        weeks.add(week);
      }
    }

    if (weeks.isEmpty && (isOdd || isEven)) {
      for (var week = 1; week <= maxWeek; week++) {
        if (_matchesParity(week, isOdd: isOdd, isEven: isEven)) {
          weeks.add(week);
        }
      }
    }
    if (weeks.isEmpty) {
      throw FormatException('Could not parse teaching weeks: $text');
    }
    return fromWeeks(weeks, rawText: source);
  }

  static bool _matchesParity(
    int week, {
    required bool isOdd,
    required bool isEven,
  }) {
    if (isOdd && !isEven) {
      return week.isOdd;
    }
    if (isEven && !isOdd) {
      return week.isEven;
    }
    return true;
  }
}
