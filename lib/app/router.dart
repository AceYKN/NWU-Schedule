import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap.dart';
import 'theme/campus_design.dart';
import '../features/shared/presentation/campus_navigation.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/import/presentation/timetable_import_page.dart';
import '../features/schedule/presentation/schedule_page.dart';
import '../features/schedule/presentation/manual_course_page.dart';
import '../features/schedule/presentation/course_detail_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/schedule_display_settings_page.dart';
import '../features/settings/presentation/course_management_page.dart';
import '../features/shared/presentation/schedule_motion.dart';

final appRouter = createAppRouter();

/// Production uses the device clock; previews can supply a fixed instant.
GoRouter createAppRouter({DateTime? now, String initialLocation = '/'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(child: child);
          },
          routes: [
            GoRoute(path: '/', builder: (context, state) => HomePage(now: now)),
            GoRoute(
              path: '/schedule',
              builder: (context, state) => SchedulePage(now: now),
            ),
            GoRoute(
              path: '/course/new',
              builder: (context, state) => const ManualCoursePage(),
            ),
            GoRoute(
              path: '/course/:id',
              builder: (context, state) => CourseDetailPage(
                courseId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/course/:id/edit',
              builder: (context, state) =>
                  ManualCoursePage(courseId: state.pathParameters['id']),
            ),
            GoRoute(
              path: '/calendar',
              builder: (context, state) => CalendarPage(now: now),
            ),
            GoRoute(
              path: '/import',
              builder: (context, state) => const TimetableImportPage(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
            GoRoute(
              path: '/settings/schedule-display',
              builder: (context, state) => const ScheduleDisplaySettingsPage(),
            ),
            GoRoute(
              path: '/courses/manage',
              builder: (context, state) => const CourseManagementPage(),
            ),
          ],
        ),
      ],
    );

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(scheduleLoadProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/schedule') || location.startsWith('/course/')) {
      return 1;
    }
    if (location.startsWith('/calendar')) {
      return 2;
    }
    if (location.startsWith('/settings') || location.startsWith('/courses/')) {
      return 3;
    }
    return 0;
  }

  void _goToIndex(BuildContext context, int index) {
    const locations = ['/', '/schedule', '/calendar', '/settings'];
    context.go(locations[index]);
  }

  @override
  Widget build(BuildContext context) {
    final design = CampusDesign.maybeOf(context);
    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar: design != null
          ? CampusNavigation(
              design: design,
              selectedIndex: _selectedIndex(context),
              onSelected: (index) => _goToIndex(context, index),
            )
          : NavigationBar(
              animationDuration: ScheduleMotion.durationOf(context),
              selectedIndex: _selectedIndex(context),
              onDestinationSelected: (index) {
                if (index != _selectedIndex(context)) {
                  _goToIndex(context, index);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.view_week_outlined),
                  selectedIcon: Icon(Icons.view_week),
                  label: '课表',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: '日历',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
    );
  }
}
