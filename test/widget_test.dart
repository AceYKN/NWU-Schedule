import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nwu_schedule/app/app.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/router.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';

void main() {
  testWidgets('starts the NWU Schedule app', (WidgetTester tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const NwuScheduleApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('课表'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('欢迎'), findsOneWidget);
    expect(find.text('导入我的课表'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建本地学期'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2026-2027学年第一学期'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('2026-2027学年第一学期'));
    await tester.pumpAndSettle();
    expect(find.text('2026-2027 第一学期'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('应用版本'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('应用版本'), findsOneWidget);
    expect(find.text('隐私说明'), findsOneWidget);
    expect(find.text('开源许可证'), findsOneWidget);

    await tester.tap(find.text('课表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '课程名 *'), '软件测试');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存课程'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    final snapshot = await DriftScheduleDataRepository(database)
        .loadSemester('nwu-2026-2027-1');
    expect(snapshot.courses.single.name, '软件测试');
    expect(snapshot.meetingRules.single.weekMask.weeks.length, 20);

    appRouter.go('/course/${snapshot.courses.single.id}/edit');
    await tester.pumpAndSettle();
    expect(find.text('编辑整门课程'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '课程名 *'),
      '软件测试 II',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存课程'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    final edited = await DriftScheduleDataRepository(database)
        .loadSemester('nwu-2026-2027-1');
    expect(edited.courses.single.name, '软件测试 II');

    appRouter.go('/courses/manage');
    await tester.pumpAndSettle();
    expect(find.text('课程管理'), findsOneWidget);
    expect(find.text('软件测试 II'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已隐藏'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消隐藏'));
    await tester.pumpAndSettle();
    expect(
        (await DriftScheduleDataRepository(database)
                .loadSemester('nwu-2026-2027-1'))
            .courses
            .single
            .hidden,
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
