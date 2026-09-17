import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'router.dart';
import 'theme/schedule_theme.dart';

class NwuScheduleApp extends StatefulWidget {
  const NwuScheduleApp({super.key});

  @override
  State<NwuScheduleApp> createState() => _NwuScheduleAppState();
}

class _NwuScheduleAppState extends State<NwuScheduleApp> {
  static const _navigationChannel = MethodChannel('nwu_schedule/navigation');

  @override
  void initState() {
    super.initState();
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method == 'openRoute' && call.arguments is String) {
        appRouter.go(call.arguments as String);
      }
      return null;
    });
  }

  @override
  void dispose() {
    _navigationChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = officialThemes.first;
    return MaterialApp.router(
      title: '西北大学课程表',
      debugShowCheckedModeBanner: false,
      theme: theme.light(),
      darkTheme: theme.dark(),
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
