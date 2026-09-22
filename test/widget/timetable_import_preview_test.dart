import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';
import 'package:nwu_schedule/features/import/presentation/timetable_import_page.dart';

void main() {
  late RemoteTimetable timetable;

  setUpAll(() {
    final fixture = jsonDecode(
      File('test/fixtures/zhengfang/timetable_response.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    timetable = const TimetableImportParser().parse(fixture);
  });

  testWidgets('renders a real new-semester import preview and confirms',
      (tester) async {
    final diff = const ImportDiffEngine().build(
      incoming: timetable,
      local: null,
      previousImport: null,
    );
    var confirmed = false;

    await _pumpCard(
      tester,
      timetable: timetable,
      diff: diff,
      onConfirm: () => confirmed = true,
    );

    expect(find.text('读取完成 · 2026-2027学年第一学期'), findsOneWidget);
    expect(find.text('2 门课程 · 2 个上课安排'), findsOneWidget);
    expect(
      find.textContaining('星期一 · 第 3-4 节 · 1-16周 · 长安校区 · 3508 · 苏峙之'),
      findsOneWidget,
    );
    expect(
      find.textContaining('星期二 · 第 5-6 节 · 2-8周双周 · 太白校区 · 1310 · 李老师'),
      findsOneWidget,
    );
    expect(find.textContaining('新增 2'), findsOneWidget);
    expect(find.text('建立新课表'), findsOneWidget);

    await tester.tap(find.text('建立新课表'));
    expect(confirmed, isTrue);
  });

  testWidgets('renders the conflict diff and disables confirmation',
      (tester) async {
    final remote = timetable.courses.first;
    final diff = ImportDiff([
      ImportChange(
        kind: ImportChangeKind.conflict,
        sourceCourseKey: remote.sourceCourseKey,
        remoteCourse: remote,
        fields: [
          ImportFieldChange(
            field: 'name',
            decision: MergeDecision.conflict,
            localValue: '本地课程名',
            remoteValue: remote.name,
          ),
        ],
      ),
    ]);

    await _pumpCard(
      tester,
      timetable: timetable,
      diff: diff,
    );

    expect(find.textContaining('冲突 1'), findsOneWidget);
    expect(find.text('解决冲突'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认导入'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('reports ignored self-study courses separately from errors',
      (tester) async {
    final selfStudy = const TimetableImportParser().parse({
      ...timetable.toJson(),
      'ignoredSelfStudyCourseCount': 1,
      'issues': [
        {
          'path': 'courses.selfStudy',
          'message': '已忽略 1 门标记为自修的课程',
          'severity': 'warning',
        },
      ],
    });
    final diff = const ImportDiffEngine().build(
      incoming: selfStudy,
      local: null,
      previousImport: null,
    );

    await _pumpCard(
      tester,
      timetable: selfStudy,
      diff: diff,
    );

    expect(find.text('已忽略 1 门标记为自修的课程'), findsOneWidget);
    expect(find.textContaining('发现 '), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required RemoteTimetable timetable,
  required ImportDiff diff,
  VoidCallback? onConfirm,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: officialThemes.first.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TimetableImportPreviewCard(
            timetable: timetable,
            diff: diff,
            hasConflictItems: diff.hasConflicts || diff.hasLocallyDeleted,
            saving: false,
            onConfirm: onConfirm ?? () {},
            onRetry: () {},
            onCancel: () {},
            onResolveConflicts: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
