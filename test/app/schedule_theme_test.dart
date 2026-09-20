import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';

void main() {
  test('official themes share the complete immutable contract', () {
    expect(officialThemes, hasLength(3));
    expect(
      officialThemes.map((theme) => theme.id).toSet(),
      hasLength(officialThemes.length),
    );
    for (final theme in officialThemes) {
      expect(theme.name, isNotEmpty);
      expect(theme.colors, isA<ScheduleThemeColors>());
      expect(theme.typography, isA<ScheduleThemeTypography>());
      expect(theme.spacing, isA<ScheduleThemeSpacing>());
      expect(theme.courseCardStyle, isA<ScheduleCourseCardStyle>());
      expect(theme.weekGridStyle, isA<ScheduleWeekGridStyle>());
      expect(theme.todayCardStyle, isA<ScheduleTodayCardStyle>());
      expect(theme.monthStyle, isA<ScheduleMonthStyle>());
      expect(theme.courseCardStyle.radius, greaterThan(0));
      expect(theme.weekGridStyle.cellHeight, greaterThan(0));
      expect(theme.monthStyle.cellHeight, greaterThan(0));
      final light = theme.light();
      final dark = theme.dark();
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.extension<ScheduleThemeTokens>(), isNotNull);
      expect(dark.extension<ScheduleThemeTokens>(), isNotNull);
      final lightTokens = light.extension<ScheduleThemeTokens>()!;
      expect(lightTokens.pagePadding, theme.spacing.page);
      expect(lightTokens.cardPadding, theme.spacing.card);
      expect(lightTokens.sectionGap, theme.spacing.section);
      expect(lightTokens.gridGap, theme.spacing.gridGap);
    }
  });
}
