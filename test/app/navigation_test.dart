import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/navigation.dart';
import 'package:nwu_schedule/data/database/app_database.dart' show AppDatabase;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/schedule/presentation/course_detail_page.dart';

void main() {
  testWidgets('cancel returns to the page that pushed the import flow',
      (tester) async {
    final router = _router('/settings');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/import');
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel on a directly opened flow goes to the fallback',
      (tester) async {
    final router = _router('/import');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final pushed in [false, true]) {
    testWidgets('course detail returns safely (pushed=$pushed)',
        (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftScheduleDataRepository(database);
      await repository.saveSemester(Semester(
        id: 'term',
        academicYear: '2026-2027',
        term: SemesterTerm.first,
        label: '学期',
        createdAt: DateTime(2026, 9, 7),
      ));
      await repository.saveCourse(
          Course(
            id: 'course',
            semesterId: 'term',
            sourceType: CourseSourceType.manual,
            name: '软件测试',
          ),
          const []);
      final router = _router(pushed ? '/settings' : '/course/course');
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      if (pushed) {
        router.push('/course/course');
        await tester.pumpAndSettle();
      }
      expect(find.text('软件测试'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text(pushed ? 'settings' : 'schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }
}

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('home')),
            GoRoute(
                path: '/settings', builder: (_, __) => const Text('settings')),
            GoRoute(
                path: '/schedule', builder: (_, __) => const Text('schedule')),
            GoRoute(
                path: '/import',
                builder: (context, _) => TextButton(
                      onPressed: () => popOrGo(context, '/'),
                      child: const Text('取消'),
                    )),
            GoRoute(
                path: '/course/:id',
                builder: (_, state) => CourseDetailPage(
                      courseId: state.pathParameters['id']!,
                    )),
          ],
        )
      ],
    );
