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
      expect(lightTokens.radiusSmall, 6);
      expect(lightTokens.radiusMedium, 10);
      expect(lightTokens.radiusLarge, 16);
      expect(lightTokens.radiusModal, 24);
      expect(lightTokens.pageTitleSize, 22);
      expect(lightTokens.sectionTitleSize, 18);
      expect(lightTokens.cardTitleSize, 16);
      expect(lightTokens.bodySize, 14);
      expect(lightTokens.secondarySize, 12);
      expect(lightTokens.denseTitleSize, 12);
      expect(lightTokens.denseDetailSize, 10);
    }
  });

  test('new visual tokens copy and interpolate with the theme extension', () {
    const tokens = ScheduleThemeTokens(
      pagePadding: 20,
      cardPadding: 16,
      sectionGap: 20,
      gridGap: 8,
      courseAccentWidth: 5,
      compactCoursePadding: 12,
      gridCellHeight: 70,
      gridColumnWidth: 118,
      gridBorderWidth: .6,
      todayCardRadius: 16,
      todayCardPadding: 20,
      monthCellHeight: 78,
      monthCellPadding: 7,
    );
    final customized = tokens.copyWith(radiusSmall: 8, pageTitleSize: 26);

    expect(customized.radiusSmall, 8);
    expect(customized.pageTitleSize, 26);
    expect(tokens.lerp(customized, .5).radiusSmall, 7);
    expect(tokens.lerp(customized, .5).pageTitleSize, 24);
  });
}
