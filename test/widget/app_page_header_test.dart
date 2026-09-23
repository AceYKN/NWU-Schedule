import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/features/shared/presentation/app_page_header.dart';

void main() {
  testWidgets('uses the shared title style and 48 pixel back target', (
    tester,
  ) async {
    var didGoBack = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageHeader(
            title: '课程详情',
            subtitle: '2026 秋季学期',
            showBack: true,
            onBack: () => didGoBack = true,
            actions: [
              IconButton(
                tooltip: '编辑课程',
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('课程详情'), findsOneWidget);
    expect(find.text('2026 秋季学期'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('返回')), const Size(48, 48));
    expect(tester.widget<Text>(find.text('课程详情')).style?.fontSize, 22);

    await tester.tap(find.byTooltip('返回'));
    expect(didGoBack, isTrue);
  });
}
