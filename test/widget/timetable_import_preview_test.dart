import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
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

  testWidgets(
      'full diff exposes normal changes beyond the first three courses before confirmation',
      (tester) async {
    final courses = [
      for (var i = 0; i < 5; i++)
        ImportedCourse(sourceCourseKey: 'c$i', name: '合成课程${i + 1}', meetings: [
          ImportedMeeting(
              sourceMeetingKey: 'm$i',
              weekday: 1,
              startSection: 3,
              endSection: 4,
              teacher: null,
              campus: null,
              room: '新教室',
              weekMask: WeekMask.all(16))
        ])
    ];
    final incoming = RemoteTimetable(
        semester: timetable.semester, totalWeeks: 20, courses: courses);
    final diff = ImportDiff([
      for (final course in courses.take(4))
        ImportChange(
            kind: ImportChangeKind.unchanged,
            sourceCourseKey: course.sourceCourseKey,
            remoteCourse: course),
      ImportChange(
          kind: ImportChangeKind.modified,
          sourceCourseKey: 'c4',
          remoteCourse: courses.last,
          fields: [
            const ImportFieldChange(
                field: 'meeting:m4:room',
                decision: MergeDecision.remote,
                localValue: '原教室',
                remoteValue: '新教室')
          ]),
      ImportChange(
          kind: ImportChangeKind.removed,
          sourceCourseKey: 'removed',
          localCourse: Course(
              id: 'removed',
              semesterId: incoming.semester.id,
              sourceType: CourseSourceType.imported,
              name: '远端删除课程')),
    ]);
    var confirmed = false;
    await _pumpCard(tester,
        timetable: incoming, diff: diff, onConfirm: () => confirmed = true);
    await tester.tap(find.text('查看完整变化清单'));
    await tester.pumpAndSettle();
    expect(find.text('修改 · 合成课程5'), findsOneWidget);
    expect(find.text('原教室 → 新教室'), findsOneWidget);
    expect(find.text('星期一 · 第3-4节 · 教室'), findsOneWidget);
    expect(find.text('删除 · 远端删除课程'), findsOneWidget);
    expect(confirmed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'preview keeps confirmation visible with large text and a constrained height',
      (tester) async {
    final diff = const ImportDiffEngine()
        .build(incoming: timetable, local: null, previousImport: null);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 360,
                        height: 380,
                        child: TimetableImportPreviewCard(
                            timetable: timetable,
                            diff: diff,
                            saving: false,
                            hasConflictItems: false,
                            onConfirm: () {},
                            onRetry: () {},
                            onCancel: () {},
                            onResolveConflicts: () {})))))));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, '建立新课表');
    expect(confirm.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('conflict sheet requires explicit choices for every field',
      (tester) async {
    final remote = timetable.courses.first;
    final diff = ImportDiff([
      ImportChange(
        kind: ImportChangeKind.conflict,
        sourceCourseKey: remote.sourceCourseKey,
        remoteCourse: remote,
        fields: const [
          ImportFieldChange(
            field: 'meeting:m1:teacher',
            decision: MergeDecision.conflict,
            localValue: '本地教师',
            remoteValue: '远端教师',
          ),
          ImportFieldChange(
            field: 'meeting:m1:room',
            decision: MergeDecision.conflict,
            localValue: '本地教室',
            remoteValue: '远端教室',
          ),
        ],
      ),
    ]);
    ImportConflictResolution? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<ImportConflictResolution>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TimetableImportConflictResolutionSheet(
                  diff: diff,
                  initial: ImportConflictResolution.empty,
                ),
              );
            },
            child: const Text('打开冲突选择'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('打开冲突选择'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('保留本地'), findsNWidgets(2));
    expect(find.text('采用教务'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '请完成全部选择'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('保留本地').first);
    await tester.pumpAndSettle();
    expect(find.text('请完成全部选择'), findsOneWidget);
    await tester.tap(find.text('采用教务').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用选择'));
    await tester.pumpAndSettle();
    expect(result?.choiceFor(remote.sourceCourseKey, 'meeting:m1:teacher'),
        MergeDecision.local);
    expect(result?.choiceFor(remote.sourceCourseKey, 'meeting:m1:room'),
        MergeDecision.remote);
    expect(diff.resolve(result!).hasConflicts, isFalse);
    expect(tester.takeException(), isNull);
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
