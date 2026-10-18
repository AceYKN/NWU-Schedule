import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/features/import/presentation/timetable_import_instructions.dart';

void main() {
  testWidgets(
      'initial instructions require an action and cancellation declines import',
      (tester) async {
    bool? result;
    await _pumpInstructions(tester,
        initial: true, onResult: (value) => result = value);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'instructions remain scrollable with reachable actions on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await _pumpInstructions(tester,
        initial: true, textScale: 2, onResult: (value) => result = value);

    await tester.ensureVisible(find.text('隐私说明'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('开始导入'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopened instructions close back to the current page',
      (tester) async {
    bool? result;
    await _pumpInstructions(tester,
        initial: false, onResult: (value) => result = value);
    expect(find.text('取消'), findsNothing);
    expect(find.text('开始导入'), findsNothing);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('操作说明'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

Future<void> _pumpInstructions(
  WidgetTester tester, {
  required bool initial,
  required ValueChanged<bool?> onResult,
  double textScale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async =>
                onResult(await showTimetableImportInstructions(
              context,
              initial: initial,
            )),
            child: const Text('操作说明'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('操作说明'));
  await tester.pumpAndSettle();
}
