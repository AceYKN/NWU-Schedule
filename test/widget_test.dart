import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nwu_schedule/app/app.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/router.dart';
import 'package:nwu_schedule/data/database/app_database.dart';
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart' as domain;

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
    final scheduleDisplayTile = find.widgetWithText(ListTile, '课表显示');
    expect(scheduleDisplayTile, findsOneWidget);
    await tester.tap(scheduleDisplayTile);
    await tester.pumpAndSettle();
    expect(find.text('预览'), findsOneWidget);
    expect(find.textContaining('A101 · 张老师'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('回本周'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, '显示教师'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A101 · 张老师'), findsNothing);
    expect(find.textContaining('A101'), findsOneWidget);
    final backToWeekSwitch = find.widgetWithText(SwitchListTile, '显示“返回本周”按钮');
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(backToWeekSwitch);
    await tester.pumpAndSettle();
    expect(find.text('回本周'), findsNothing);
    appRouter.go('/settings');
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
    final addFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton).last,
    );
    expect(addFab.onPressed, isNotNull);
    addFab.onPressed!();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '课程名 *'), '软件测试');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('添加上课安排'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final addMeetingButton = find.widgetWithText(
      OutlinedButton,
      '添加上课安排',
    );
    expect(addMeetingButton, findsOneWidget);
    expect(
        tester.widget<OutlinedButton>(addMeetingButton).onPressed, isNotNull);
    await tester.ensureVisible(addMeetingButton);
    await tester.tap(addMeetingButton);
    await tester.pumpAndSettle();
    expect(find.text('上课安排 1', skipOffstage: false), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '上课安排 2',
        description: 'second meeting heading',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
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
    expect(snapshot.meetingRules, hasLength(2));
    expect(
        snapshot.meetingRules.every((rule) => rule.weekMask.weeks.length == 20),
        isTrue);

    appRouter.go('/course/${snapshot.courses.single.id}/edit');
    await tester.pumpAndSettle();
    expect(find.text('编辑整门课程'), findsOneWidget);
    expect(find.text('上课安排 1', skipOffstage: false), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '课程名 *'),
      '软件测试 II',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final reopenedSecondHeading = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == '上课安排 2',
      description: 'second meeting heading',
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      reopenedSecondHeading,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(reopenedSecondHeading, findsOneWidget);
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

    await DriftScheduleDataRepository(database).saveException(
      domain.CourseException(
        id: 'standalone-add-1',
        semesterId: 'nwu-2026-2027-1',
        type: domain.CourseExceptionType.add,
        targetDate: DateTime(2026, 9, 21),
        targetStartSection: 3,
        targetEndSection: 4,
        addedCourseName: '临时项目讨论',
        teacherOverride: '苏老师',
        campusOverride: '长安校区',
        roomOverride: '3406',
      ),
    );
    appRouter.go('/course/standalone-add-1');
    await tester.pumpAndSettle();
    expect(find.text('临时项目讨论'), findsOneWidget);
    expect(find.textContaining('临时加课'), findsOneWidget);
    expect(find.textContaining('单次课程'), findsOneWidget);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpAndSettle();
    final clearDataTile = find.text('清除所有数据', skipOffstage: false);
    expect(clearDataTile, findsOneWidget);
    await tester.ensureVisible(clearDataTile);
    await tester.pumpAndSettle();
    await tester.tap(clearDataTile);
    await tester.pumpAndSettle();
    expect(find.text('清除所有数据？'), findsOneWidget);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channelName in const [
      'nwu_schedule/notifications',
      'nwu_schedule/widget',
      'nwu_schedule/webview_session',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channelName),
        (_) async => null,
      );
    }
    addTearDown(() {
      for (final channelName in const [
        'nwu_schedule/notifications',
        'nwu_schedule/widget',
        'nwu_schedule/webview_session',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
      }
    });
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/');
    expect(find.text('欢迎'), findsOneWidget);
    expect(find.text('导入我的课表'), findsOneWidget);
    expect(
      await DriftScheduleDataRepository(database).loadSemesters(),
      isEmpty,
    );

    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
