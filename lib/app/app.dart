import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap.dart';
import '../domain/settings/appearance_preferences.dart';
import 'router.dart';
import 'theme/schedule_theme.dart';

class NwuScheduleApp extends ConsumerStatefulWidget {
  const NwuScheduleApp({super.key});

  @override
  ConsumerState<NwuScheduleApp> createState() => _NwuScheduleAppState();
}

class _NwuScheduleAppState extends ConsumerState<NwuScheduleApp>
    with WidgetsBindingObserver {
  static const _navigationChannel = MethodChannel('nwu_schedule/navigation');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method == 'openRoute' && call.arguments is String) {
        appRouter.go(call.arguments as String);
      }
      return null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPlatformStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(themeIdProvider).asData?.value;
    final theme = officialThemes.firstWhere(
      (item) => item.id == selectedId,
      orElse: () => officialThemes.first,
    );
    final selectedThemeMode =
        ref.watch(themeModeProvider).asData?.value ?? AppThemeMode.system;
    return MaterialApp.router(
      title: '西北大学课程表',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: theme.light(),
      darkTheme: theme.dark(),
      themeMode: switch (selectedThemeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: appRouter,
    );
  }
}

class NwuScheduleRoot extends ConsumerWidget {
  const NwuScheduleRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationCoordinatorProvider);
    ref.watch(widgetCoordinatorProvider);
    return const NwuScheduleApp();
  }
}

class NwuScheduleAppRoot extends StatelessWidget {
  const NwuScheduleAppRoot({super.key});

  @override
  Widget build(BuildContext context) => const ProviderScope(
        child: NwuScheduleRoot(),
      );
}
