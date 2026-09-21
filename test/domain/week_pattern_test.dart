import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/meeting_draft.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/course/week_pattern.dart';

void main() {
  test('builds all, odd, and even teaching week masks', () {
    expect(
      buildPatternWeekMask(
        startWeek: 1,
        endWeek: 6,
        pattern: WeekPattern.all,
        totalWeeks: 18,
      ).weeks,
      [1, 2, 3, 4, 5, 6],
    );
    expect(
      buildPatternWeekMask(
        startWeek: 1,
        endWeek: 6,
        pattern: WeekPattern.odd,
        totalWeeks: 18,
      ).weeks,
      [1, 3, 5],
    );
    expect(
      buildPatternWeekMask(
        startWeek: 1,
        endWeek: 6,
        pattern: WeekPattern.even,
        totalWeeks: 18,
      ).weeks,
      [2, 4, 6],
    );
  });

  test('infers regular patterns and preserves irregular masks', () {
    final regular = inferWeekPattern(
      WeekMask.fromWeeks([2, 4, 6, 8]),
      totalWeeks: 18,
    );
    expect(regular.pattern, WeekPattern.even);
    expect(regular.startWeek, 2);
    expect(regular.endWeek, 8);
    expect(regular.isIrregular, isFalse);

    final irregularMask = WeekMask.fromWeeks([1, 2, 4, 7]);
    final irregular = inferWeekPattern(irregularMask, totalWeeks: 18);
    expect(irregular.isIrregular, isTrue);
    expect(irregular.mode, WeekSelectionMode.custom);
    expect(
      MeetingDraft.fromRule(
        MeetingRuleFixture.rule(irregularMask),
        totalWeeks: 18,
      ).weekMask(18).value,
      irregularMask.value,
    );
  });

  test('rejects invalid pattern ranges', () {
    expect(
      () => buildPatternWeekMask(
        startWeek: 6,
        endWeek: 2,
        pattern: WeekPattern.all,
        totalWeeks: 18,
      ),
      throwsRangeError,
    );
    expect(
      () => buildPatternWeekMask(
        startWeek: 1,
        endWeek: 65,
        pattern: WeekPattern.all,
        totalWeeks: 65,
      ),
      throwsRangeError,
    );
  });
}

class MeetingRuleFixture {
  static MeetingRule rule(WeekMask mask) {
    return MeetingRule(
      id: 'rule',
      courseId: 'course',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weekMask: mask,
    );
  }
}
