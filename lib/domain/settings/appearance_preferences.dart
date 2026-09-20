enum AppThemeMode { system, light, dark }

extension AppThemeModeLabels on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.system => '跟随系统',
        AppThemeMode.light => '浅色',
        AppThemeMode.dark => '深色',
      };
}
