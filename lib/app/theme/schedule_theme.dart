import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ScheduleThemeColors {
  const ScheduleThemeColors({
    this.lightBackground = const Color(0xfff7f8fa),
    this.darkBackground = const Color(0xff121416),
    this.lightInputBackground = Colors.white,
    this.darkInputBackground = const Color(0xff1b1e21),
  });

  final Color lightBackground;
  final Color darkBackground;
  final Color lightInputBackground;
  final Color darkInputBackground;
}

class ScheduleThemeTypography {
  const ScheduleThemeTypography({
    this.titleWeight = FontWeight.w700,
    this.bodyWeight = FontWeight.w400,
    this.labelLetterSpacing = 0.1,
  });

  final FontWeight titleWeight;
  final FontWeight bodyWeight;
  final double labelLetterSpacing;
}

class ScheduleThemeSpacing {
  const ScheduleThemeSpacing({
    this.page = 20,
    this.card = 16,
    this.section = 20,
    this.gridGap = 8,
  });

  final double page;
  final double card;
  final double section;
  final double gridGap;
}

class ScheduleCourseCardStyle {
  const ScheduleCourseCardStyle({
    this.radius = 12,
    this.elevation = 1,
    this.accentWidth = 5,
    this.compactPadding = 12,
  });

  final double radius;
  final double elevation;
  final double accentWidth;
  final double compactPadding;
}

class ScheduleWeekGridStyle {
  const ScheduleWeekGridStyle({
    this.cellHeight = 70,
    this.columnWidth = 118,
    this.borderWidth = 0.6,
  });

  final double cellHeight;
  final double columnWidth;
  final double borderWidth;
}

class ScheduleTodayCardStyle {
  const ScheduleTodayCardStyle({
    this.radius = 16,
    this.padding = 20,
  });

  final double radius;
  final double padding;
}

class ScheduleMonthStyle {
  const ScheduleMonthStyle({
    this.cellHeight = 78,
    this.cellPadding = 7,
  });

  final double cellHeight;
  final double cellPadding;
}

class ScheduleThemeTokens extends ThemeExtension<ScheduleThemeTokens> {
  const ScheduleThemeTokens({
    required this.pagePadding,
    required this.cardPadding,
    required this.sectionGap,
    required this.gridGap,
    required this.courseAccentWidth,
    required this.compactCoursePadding,
    required this.gridCellHeight,
    required this.gridColumnWidth,
    required this.gridBorderWidth,
    required this.todayCardRadius,
    required this.todayCardPadding,
    required this.monthCellHeight,
    required this.monthCellPadding,
  });

  final double pagePadding;
  final double cardPadding;
  final double sectionGap;
  final double gridGap;
  final double courseAccentWidth;
  final double compactCoursePadding;
  final double gridCellHeight;
  final double gridColumnWidth;
  final double gridBorderWidth;
  final double todayCardRadius;
  final double todayCardPadding;
  final double monthCellHeight;
  final double monthCellPadding;

  @override
  ScheduleThemeTokens copyWith({
    double? pagePadding,
    double? cardPadding,
    double? sectionGap,
    double? gridGap,
    double? courseAccentWidth,
    double? compactCoursePadding,
    double? gridCellHeight,
    double? gridColumnWidth,
    double? gridBorderWidth,
    double? todayCardRadius,
    double? todayCardPadding,
    double? monthCellHeight,
    double? monthCellPadding,
  }) {
    return ScheduleThemeTokens(
      pagePadding: pagePadding ?? this.pagePadding,
      cardPadding: cardPadding ?? this.cardPadding,
      sectionGap: sectionGap ?? this.sectionGap,
      gridGap: gridGap ?? this.gridGap,
      courseAccentWidth: courseAccentWidth ?? this.courseAccentWidth,
      compactCoursePadding: compactCoursePadding ?? this.compactCoursePadding,
      gridCellHeight: gridCellHeight ?? this.gridCellHeight,
      gridColumnWidth: gridColumnWidth ?? this.gridColumnWidth,
      gridBorderWidth: gridBorderWidth ?? this.gridBorderWidth,
      todayCardRadius: todayCardRadius ?? this.todayCardRadius,
      todayCardPadding: todayCardPadding ?? this.todayCardPadding,
      monthCellHeight: monthCellHeight ?? this.monthCellHeight,
      monthCellPadding: monthCellPadding ?? this.monthCellPadding,
    );
  }

  @override
  ScheduleThemeTokens lerp(
    covariant ScheduleThemeTokens? other,
    double t,
  ) {
    if (other == null) return this;
    return ScheduleThemeTokens(
      pagePadding: ui.lerpDouble(pagePadding, other.pagePadding, t)!,
      cardPadding: ui.lerpDouble(cardPadding, other.cardPadding, t)!,
      sectionGap: ui.lerpDouble(sectionGap, other.sectionGap, t)!,
      gridGap: ui.lerpDouble(gridGap, other.gridGap, t)!,
      courseAccentWidth:
          ui.lerpDouble(courseAccentWidth, other.courseAccentWidth, t)!,
      compactCoursePadding: ui.lerpDouble(
        compactCoursePadding,
        other.compactCoursePadding,
        t,
      )!,
      gridCellHeight: ui.lerpDouble(gridCellHeight, other.gridCellHeight, t)!,
      gridColumnWidth:
          ui.lerpDouble(gridColumnWidth, other.gridColumnWidth, t)!,
      gridBorderWidth:
          ui.lerpDouble(gridBorderWidth, other.gridBorderWidth, t)!,
      todayCardRadius:
          ui.lerpDouble(todayCardRadius, other.todayCardRadius, t)!,
      todayCardPadding:
          ui.lerpDouble(todayCardPadding, other.todayCardPadding, t)!,
      monthCellHeight:
          ui.lerpDouble(monthCellHeight, other.monthCellHeight, t)!,
      monthCellPadding:
          ui.lerpDouble(monthCellPadding, other.monthCellPadding, t)!,
    );
  }
}

class ScheduleThemeDefinition {
  const ScheduleThemeDefinition({
    required this.id,
    required this.name,
    required this.seedColor,
    this.colors = const ScheduleThemeColors(),
    this.typography = const ScheduleThemeTypography(),
    this.spacing = const ScheduleThemeSpacing(),
    this.courseCardStyle = const ScheduleCourseCardStyle(),
    this.weekGridStyle = const ScheduleWeekGridStyle(),
    this.todayCardStyle = const ScheduleTodayCardStyle(),
    this.monthStyle = const ScheduleMonthStyle(),
  });

  final String id;
  final String name;
  final Color seedColor;
  final ScheduleThemeColors colors;
  final ScheduleThemeTypography typography;
  final ScheduleThemeSpacing spacing;
  final ScheduleCourseCardStyle courseCardStyle;
  final ScheduleWeekGridStyle weekGridStyle;
  final ScheduleTodayCardStyle todayCardStyle;
  final ScheduleMonthStyle monthStyle;

  ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.lightBackground,
      cardTheme: CardThemeData(
        elevation: courseCardStyle.elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(courseCardStyle.radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.lightInputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(courseCardStyle.radius),
        ),
      ),
      textTheme: _textTheme(Brightness.light),
      extensions: [_tokens()],
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }

  ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.darkBackground,
      cardTheme: CardThemeData(
        elevation: courseCardStyle.elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(courseCardStyle.radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.darkInputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(courseCardStyle.radius),
        ),
      ),
      textTheme: _textTheme(Brightness.dark),
      extensions: [_tokens()],
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }

  TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final themed = base.apply(
      bodyColor: brightness == Brightness.dark ? Colors.white : Colors.black87,
      displayColor:
          brightness == Brightness.dark ? Colors.white : Colors.black87,
    );
    return themed.copyWith(
      bodyLarge: themed.bodyLarge?.copyWith(fontWeight: typography.bodyWeight),
      bodyMedium:
          themed.bodyMedium?.copyWith(fontWeight: typography.bodyWeight),
      bodySmall: themed.bodySmall?.copyWith(fontWeight: typography.bodyWeight),
      headlineSmall: themed.headlineSmall?.copyWith(
        fontWeight: typography.titleWeight,
      ),
      titleLarge: themed.titleLarge?.copyWith(
        fontWeight: typography.titleWeight,
      ),
      titleMedium: themed.titleMedium?.copyWith(
        fontWeight: typography.titleWeight,
      ),
      labelLarge: themed.labelLarge?.copyWith(
        letterSpacing: typography.labelLetterSpacing,
      ),
      labelMedium: themed.labelMedium?.copyWith(
        letterSpacing: typography.labelLetterSpacing,
      ),
      labelSmall: themed.labelSmall?.copyWith(
        letterSpacing: typography.labelLetterSpacing,
      ),
    );
  }

  ScheduleThemeTokens _tokens() {
    return ScheduleThemeTokens(
      pagePadding: spacing.page,
      cardPadding: spacing.card,
      sectionGap: spacing.section,
      gridGap: spacing.gridGap,
      courseAccentWidth: courseCardStyle.accentWidth,
      compactCoursePadding: courseCardStyle.compactPadding,
      gridCellHeight: weekGridStyle.cellHeight,
      gridColumnWidth: weekGridStyle.columnWidth,
      gridBorderWidth: weekGridStyle.borderWidth,
      todayCardRadius: todayCardStyle.radius,
      todayCardPadding: todayCardStyle.padding,
      monthCellHeight: monthStyle.cellHeight,
      monthCellPadding: monthStyle.cellPadding,
    );
  }
}

ScheduleThemeTokens scheduleThemeTokensOf(BuildContext context) {
  return Theme.of(context).extension<ScheduleThemeTokens>() ??
      const ScheduleThemeTokens(
        pagePadding: 20,
        cardPadding: 16,
        sectionGap: 20,
        gridGap: 8,
        courseAccentWidth: 5,
        compactCoursePadding: 12,
        gridCellHeight: 70,
        gridColumnWidth: 118,
        gridBorderWidth: 0.6,
        todayCardRadius: 16,
        todayCardPadding: 20,
        monthCellHeight: 78,
        monthCellPadding: 7,
      );
}

const officialThemes = <ScheduleThemeDefinition>[
  ScheduleThemeDefinition(
    id: 'stone-blue',
    name: '石墨蓝',
    seedColor: Color(0xff526579),
    courseCardStyle: ScheduleCourseCardStyle(radius: 12, elevation: 1),
  ),
  ScheduleThemeDefinition(
    id: 'cedar-green',
    name: '雪松绿',
    seedColor: Color(0xff52766c),
    colors: ScheduleThemeColors(
      lightBackground: Color(0xfff5f8f6),
      darkBackground: Color(0xff111815),
    ),
    courseCardStyle: ScheduleCourseCardStyle(radius: 14, elevation: 1),
    spacing: ScheduleThemeSpacing(page: 20, card: 17, section: 21, gridGap: 9),
  ),
  ScheduleThemeDefinition(
    id: 'warm-sand',
    name: '暖沙',
    seedColor: Color(0xff9a7354),
    colors: ScheduleThemeColors(
      lightBackground: Color(0xfffbf7f2),
      darkBackground: Color(0xff1a1511),
    ),
    typography: ScheduleThemeTypography(labelLetterSpacing: 0.2),
    courseCardStyle: ScheduleCourseCardStyle(radius: 10, elevation: 2),
    todayCardStyle: ScheduleTodayCardStyle(radius: 18, padding: 22),
  ),
];
