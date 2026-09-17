import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';

void main() {
  test('parses continuous, discrete, odd, and even teaching weeks', () {
    expect(WeekMask.parse('1-16周').weeks, List<int>.generate(16, (i) => i + 1));
    expect(WeekMask.parse('1,3,5,7周').weeks, [1, 3, 5, 7]);
    expect(WeekMask.parse('单周', maxWeek: 8).weeks, [1, 3, 5, 7]);
    expect(WeekMask.parse('双周', maxWeek: 8).weeks, [2, 4, 6, 8]);
    expect(WeekMask.parse('1-8,10,12-16周').weeks, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      10,
      12,
      13,
      14,
      15,
      16,
    ]);
  });

  test('stores week 64 without losing the bit', () {
    final mask = WeekMask.fromWeeks([1, 32, 64]);
    expect(mask.contains(1), isTrue);
    expect(mask.contains(32), isTrue);
    expect(mask.contains(64), isTrue);
    expect(mask.contains(63), isFalse);
  });

  test('manual weeks reject stray text and out-of-semester weeks', () {
    expect(WeekMask.parseManual('1-7周单周', maxWeek: 20).weeks, [1, 3, 5, 7]);
    expect(WeekMask.parseManual('1，3，5周', maxWeek: 20).weeks, [1, 3, 5]);
    expect(() => WeekMask.parseManual('abc1周', maxWeek: 20),
        throwsFormatException);
    expect(() => WeekMask.parseManual('1-21周', maxWeek: 20), throwsRangeError);
    expect(
        () => WeekMask.parseManual('第1周', maxWeek: 20), throwsFormatException);
  });

  test('formats week masks without inventing missing weeks', () {
    expect(formatWeekMask(WeekMask.fromWeeks([1, 2, 3, 4])), '1-4周');
    expect(formatWeekMask(WeekMask.fromWeeks([1, 3, 5, 7])), '1-7周单周');
    expect(formatWeekMask(WeekMask.fromWeeks([2, 4, 6, 8])), '2-8周双周');
    expect(formatWeekMask(WeekMask.fromWeeks([1, 3, 6, 8])), '1,3,6,8周');
  });
}
