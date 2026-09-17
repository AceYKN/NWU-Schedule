import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/schedule_theme.dart';

class NwuScheduleApp extends StatelessWidget {
  const NwuScheduleApp({super.key});

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

class NwuScheduleRoot extends StatelessWidget {
  const NwuScheduleRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: NwuScheduleApp());
  }
}
