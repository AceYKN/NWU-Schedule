import 'package:flutter/material.dart';

class ScheduleThemeDefinition {
  const ScheduleThemeDefinition({
    required this.id,
    required this.name,
    required this.seedColor,
  });

  final String id;
  final String name;
  final Color seedColor;

  ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      scaffoldBackgroundColor: const Color(0xfff7f8fa),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}

const officialThemes = <ScheduleThemeDefinition>[
  ScheduleThemeDefinition(
    id: 'stone-blue',
    name: '石墨蓝',
    seedColor: Color(0xff526579),
  ),
  ScheduleThemeDefinition(
    id: 'cedar-green',
    name: '雪松绿',
    seedColor: Color(0xff52766c),
  ),
  ScheduleThemeDefinition(
    id: 'warm-sand',
    name: '暖沙',
    seedColor: Color(0xff9a7354),
  ),
];
