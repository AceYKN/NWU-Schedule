import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/course_identity.dart';
import '../../../domain/course/meeting_draft.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../../domain/course/week_pattern.dart';
import '../../../domain/schedule/schedule_conflict_detector.dart';
import '../../shared/presentation/app_page_header.dart';
import '../../shared/presentation/schedule_conflict_dialog.dart';
import 'course_form_fields.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

class ManualCoursePage extends ConsumerStatefulWidget {
  const ManualCoursePage({this.courseId, super.key});

  final String? courseId;

  @override
  ConsumerState<ManualCoursePage> createState() => _ManualCoursePageState();
}

class _ManualCoursePageState extends ConsumerState<ManualCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _saveAttemptActive = false;
  bool _saving = false;
  bool _initialized = false;
  bool _snackbarDismissed = false;
  Course? _existingCourse;
  List<MeetingRule> _existingRules = const [];
  List<MeetingDraft> _drafts = const [];

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_snackbarDismissed) return;
    _snackbarDismissed = true;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _initialize(ScheduleReady ready, int totalWeeks) {
    if (_initialized) return;
    if (widget.courseId != null) {
      for (final course in ready.engine.courses) {
        if (course.id == widget.courseId) {
          _existingCourse = course;
          break;
        }
      }
      if (_existingCourse == null) return;
      _existingRules = ready.engine.meetingRules
          .where((rule) => rule.courseId == widget.courseId)
          .toList(growable: false);
      _drafts = [
        for (final rule in _existingRules)
          MeetingDraft.fromRule(rule, totalWeeks: totalWeeks),
      ];
      if (_drafts.isEmpty) {
        _drafts = [MeetingDraft.initial(totalWeeks: totalWeeks)];
      }
      _name.text = _existingCourse!.name;
      _note.text = _existingCourse!.note ?? '';
    } else {
      _drafts = [MeetingDraft.initial(totalWeeks: totalWeeks)];
    }
    _initialized = true;
  }

  void _updateDraft(MeetingDraft draft) {
    final index = _drafts.indexWhere((item) => item.id == draft.id);
    if (index < 0) return;
    setState(() {
      final next = [..._drafts];
      next[index] = draft;
      _drafts = next;
    });
  }

  void _addDraft(int index, int totalWeeks) {
    final draft = MeetingDraft.initial(
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      totalWeeks: totalWeeks,
    );
    setState(() {
      final next = [..._drafts];
      next.insert(index + 1, draft);
      _drafts = next;
    });
  }

  void _copyDraft(int index) {
    final source = _drafts[index];
    final copy = source.copyWith(
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      sourceMeetingKey: null,
    );
    setState(() {
      final next = [..._drafts];
      next.insert(index + 1, copy);
      _drafts = next;
    });
  }

  void _deleteDraft(int index) {
    if (_drafts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(campusText(context, '课程至少需要一个上课安排'))));
      return;
    }
    setState(() {
      final next = [..._drafts]..removeAt(index);
      _drafts = next;
    });
  }

  Future<bool> _confirmDeletedExceptions(
    ScheduleReady ready,
    Set<String> deletedRuleIds,
  ) async {
    if (deletedRuleIds.isEmpty) return true;
    final affected = ready.engine.exceptions
        .where(
          (exception) =>
              exception.courseId == widget.courseId &&
              exception.sourceMeetingId != null &&
              deletedRuleIds.contains(exception.sourceMeetingId),
        )
        .toList(growable: false);
    if (affected.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(campusText(dialogContext, '删除存在临时变更的上课安排？')),
        content: Text(
          campusText(dialogContext, '该上课安排存在 {0} 条临时变更。\n删除后相关临时变更也将删除。',
              values: {'0': affected.length}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(campusText(dialogContext, '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(campusText(dialogContext, '确认删除')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _save(ScheduleReady ready) async {
    if (_saveAttemptActive || !_formKey.currentState!.validate()) return;
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(campusText(context, '课程至少需要一个上课安排'))));
      return;
    }
    final desiredName = _name.text.trim();
    Course? sameNameCourse;
    for (final candidate in ready.engine.courses) {
      if (candidate.id != _existingCourse?.id &&
          CourseIdentity.sameName(candidate.name, desiredName)) {
        sameNameCourse = candidate;
        break;
      }
    }
    if (sameNameCourse != null) {
      final isEditing = _existingCourse != null;
      final restoresCourse = sameNameCourse.deleted;
      final restorationNotice =
          restoresCourse ? campusText(context, '这门同名课程已删除，本次操作会恢复它。\n') : '';
      final mergeDescription = isEditing
          ? campusText(context, '“{0}”已存在。本次修改会把当前课程及其上课安排合并到该课程。',
              values: {'0': sameNameCourse.name})
          : campusText(context, '“{0}”已存在，将把本次内容作为新的上课安排添加到该课程。课程备注和颜色保持现有设置。',
              values: {'0': sameNameCourse.name});
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(restoresCourse
              ? (isEditing
                  ? campusText(context, '恢复并合并同名课程？')
                  : campusText(context, '恢复同名课程？'))
              : (isEditing
                  ? campusText(context, '合并同名课程？')
                  : campusText(context, '已存在同名课程'))),
          content: Text('$restorationNotice$mergeDescription'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(campusText(dialogContext, '取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(restoresCourse
                  ? (isEditing
                      ? campusText(context, '恢复并合并')
                      : campusText(context, '恢复并添加安排'))
                  : (isEditing
                      ? campusText(context, '合并课程')
                      : campusText(context, '添加安排'))),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _saveAttemptActive = true;
    try {
      final totalWeeks = ready.engine.totalWeeks;
      final masks = [for (final draft in _drafts) draft.weekMask(totalWeeks)];
      final savedAt = DateTime.now().microsecondsSinceEpoch;
      final newCourseId = 'manual-${DateTime.now().microsecondsSinceEpoch}';
      final id = _existingCourse?.id ?? sameNameCourse?.id ?? newCourseId;
      final editedCourse = _existingCourse?.copyWith(
            name: desiredName,
            note: _optional(_note),
          ) ??
          Course(
            id: id,
            semesterId: ready.semester.id,
            sourceType: CourseSourceType.manual,
            name: desiredName,
            note: _optional(_note),
          );
      final existingIds = _existingRules.map((rule) => rule.id).toSet();
      final draftIds = _drafts.map((draft) => draft.id).toSet();
      final deletedRuleIds = existingIds.difference(draftIds);
      if (!await _confirmDeletedExceptions(ready, deletedRuleIds)) return;

      final repository = ref.read(scheduleDataRepositoryProvider);
      final deletedExceptionIds = ready.engine.exceptions
          .where(
            (exception) =>
                exception.courseId == (_existingCourse?.id ?? id) &&
                exception.sourceMeetingId != null &&
                deletedRuleIds.contains(exception.sourceMeetingId),
          )
          .map((exception) => exception.id)
          .toList(growable: false);
      final rules = <MeetingRule>[];
      for (var index = 0; index < _drafts.length; index++) {
        final draft = _drafts[index];
        final ruleId = existingIds.contains(draft.id)
            ? draft.id
            : 'manual-$id-$savedAt-$index';
        rules.add(
          MeetingRule(
            id: ruleId,
            courseId: id,
            sourceMeetingKey: draft.sourceMeetingKey,
            weekday: draft.weekday,
            startSection: draft.startSection,
            endSection: draft.endSection,
            teacher: _optionalText(draft.teacher),
            campus: _optionalText(draft.campus),
            room: _optionalText(draft.room),
            weekMask: masks[index],
          ),
        );
      }
      final targetRules = sameNameCourse == null
          ? const <MeetingRule>[]
          : ready.engine.meetingRules
              .where((rule) => rule.courseId == sameNameCourse!.id)
              .toList(growable: false);
      final conflicts = ScheduleConflictDetector.forCourseSave(
        current: ready.engine,
        changedCourses: [
          if (sameNameCourse != null && _existingCourse != null) ...[
            editedCourse,
            sameNameCourse,
          ] else if (sameNameCourse != null)
            sameNameCourse.copyWith(deleted: false)
          else
            editedCourse,
        ],
        changedRules: [...targetRules, ...rules],
        removeExceptionIds: deletedExceptionIds,
      );
      if (!mounted) return;
      if (!await confirmScheduleConflicts(context, conflicts) || !mounted) {
        return;
      }
      setState(() => _saving = true);
      if (sameNameCourse != null && _existingCourse != null) {
        await repository.mergeCourseInto(
          editedCourse: editedCourse,
          targetCourseId: sameNameCourse.id,
          editedRules: rules,
          removeExceptionIds: deletedExceptionIds,
        );
      } else if (sameNameCourse != null) {
        await repository.saveCourse(sameNameCourse.copyWith(deleted: false), [
          ...targetRules,
          ...rules,
        ]);
      } else {
        await repository.saveCourse(
          editedCourse,
          rules,
          removeExceptionIds: deletedExceptionIds,
        );
      }
      // The edit route can be reopened immediately after this save. Do not
      // let it reuse the previous ScheduleEngine snapshot while Drift's
      // change stream is still scheduling its next emission.
      ref.invalidate(scheduleLoadProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/schedule');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sameNameCourse == null
                ? campusText(context, '课程已保存到本地')
                : _existingCourse == null
                    ? sameNameCourse.deleted
                        ? campusText(context, '课程已恢复并添加上课安排')
                        : campusText(context, '已添加为现有课程的新上课安排')
                    : campusText(context, '同名课程及上课安排已合并'),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(campusUserMessage(context, error,
                  action: campusText(context, '保存失败')))),
        );
      }
    } finally {
      _saveAttemptActive = false;
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optional(TextEditingController controller) =>
      _optionalText(controller.text);

  static String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.courseId == null
        ? ref.watch(scheduleLoadProvider)
        : ref.watch(courseEditLoadProvider(widget.courseId!));
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Text(campusUserMessage(context, error,
              action: campusText(context, '读取学期失败')))),
      data: (state) {
        if (state is ScheduleCalendarMissing) {
          return Center(
              child: Text(campusText(context, '学期已保存，但缺少校历，请更新应用后重试')));
        }
        if (state is! ScheduleReady) {
          return Center(child: Text(campusText(context, '请先在设置中创建学期')));
        }
        final totalWeeks = state.engine.totalWeeks;
        _initialize(state, totalWeeks);
        if (widget.courseId != null && _existingCourse == null) {
          return Center(child: Text(campusText(context, '找不到这门课程')));
        }
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
            children: [
              AppPageHeader(
                title: widget.courseId == null
                    ? campusText(context, '手动添加课程')
                    : campusText(context, '编辑整门课程'),
                subtitle: state.semester.label,
              ),
              const SizedBox(height: 24),
              _SectionHeading(title: campusText(context, '课程信息')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration:
                    InputDecoration(labelText: campusText(context, '课程名 *')),
                maxLength: 80,
                validator: (value) => value == null || value.trim().isEmpty
                    ? campusText(context, '请输入课程名称')
                    : null,
              ),
              const SizedBox(height: 12),
              CompactNotesField(controller: _note),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child:
                          _SectionHeading(title: campusText(context, '上课安排'))),
                  Text(campusText(context, '{0} 条',
                      values: {'0': _drafts.length})),
                ],
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _drafts.length; index++) ...[
                _MeetingDraftCard(
                  key: ValueKey(_drafts[index].id),
                  index: index,
                  draft: _drafts[index],
                  totalWeeks: totalWeeks,
                  canDelete: _drafts.length > 1,
                  onChanged: _updateDraft,
                  onCopy: () => _copyDraft(index),
                  onDelete: () => _deleteDraft(index),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => _addDraft(_drafts.length - 1, totalWeeks),
                icon: const Icon(Icons.add),
                label: Text(campusText(context, '添加上课安排')),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _save(state),
                child: Text(_saving
                    ? campusText(context, '保存中…')
                    : campusText(context, '保存课程')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = scheduleThemeTokensOf(context);
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: tokens.sectionTitleSize,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _MeetingDraftCard extends StatefulWidget {
  const _MeetingDraftCard({
    required this.index,
    required this.draft,
    required this.totalWeeks,
    required this.canDelete,
    required this.onChanged,
    required this.onCopy,
    required this.onDelete,
    super.key,
  });

  final int index;
  final MeetingDraft draft;
  final int totalWeeks;
  final bool canDelete;
  final ValueChanged<MeetingDraft> onChanged;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  State<_MeetingDraftCard> createState() => _MeetingDraftCardState();
}

class _MeetingDraftCardState extends State<_MeetingDraftCard> {
  late final TextEditingController _teacher;
  late final TextEditingController _campus;
  late final TextEditingController _room;

  @override
  void initState() {
    super.initState();
    _teacher = TextEditingController(text: widget.draft.teacher);
    _campus = TextEditingController(text: widget.draft.campus);
    _room = TextEditingController(text: widget.draft.room);
  }

  @override
  void dispose() {
    _teacher.dispose();
    _campus.dispose();
    _room.dispose();
    super.dispose();
  }

  void _update(MeetingDraft next) => widget.onChanged(next);

  void _updateText() {
    _update(
      widget.draft.copyWith(
        teacher: _teacher.text,
        campus: _campus.text,
        room: _room.text,
      ),
    );
  }

  void _updateWeekSelection(TeachingWeekSelection selection) {
    final pattern = switch (selection.mode) {
      WeekSelectionMode.all => WeekPattern.all,
      WeekSelectionMode.odd => WeekPattern.odd,
      WeekSelectionMode.even => WeekPattern.even,
      WeekSelectionMode.custom => WeekPattern.all,
    };
    final isCustom = selection.mode == WeekSelectionMode.custom;
    _update(
      widget.draft.copyWith(
        startWeek: selection.startWeek,
        endWeek: selection.endWeek,
        pattern: pattern,
        selectionMode: selection.mode,
        originalWeekMask: isCustom ? weekMaskFromSelection(selection) : null,
        isIrregular: isCustom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campusText(context, '上课安排 {0}',
                        values: {'0': widget.index + 1}),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: campusText(context, '复制安排'),
                  onPressed: widget.onCopy,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: campusText(context, '删除安排'),
                  onPressed: widget.canDelete ? widget.onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: draft.weekday,
              decoration: InputDecoration(labelText: campusText(context, '星期')),
              items: List.generate(
                7,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(campusWeekdayName(context, index + 1)),
                ),
              ),
              onChanged: (value) =>
                  _update(draft.copyWith(weekday: value ?? 1)),
            ),
            const SizedBox(height: 12),
            SectionRangeSelector(
              startSection: draft.startSection,
              endSection: draft.endSection,
              onChanged: (selection) => _update(
                draft.copyWith(
                  startSection: selection.start,
                  endSection: selection.end,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacher,
              decoration: InputDecoration(
                  labelText: campusText(context, CourseFieldLabels.teacher)),
              onChanged: (_) => _updateText(),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final campusField = TextFormField(
                  controller: _campus,
                  decoration: InputDecoration(
                      labelText: campusText(context, CourseFieldLabels.campus)),
                  onChanged: (_) => _updateText(),
                );
                final roomField = TextFormField(
                  controller: _room,
                  decoration: InputDecoration(
                      labelText: campusText(context, CourseFieldLabels.room)),
                  onChanged: (_) => _updateText(),
                );
                if (constraints.maxWidth >= 320) {
                  return Row(
                    children: [
                      Expanded(child: campusField),
                      const SizedBox(width: 12),
                      Expanded(child: roomField),
                    ],
                  );
                }
                return Column(
                  children: [
                    campusField,
                    const SizedBox(height: 12),
                    roomField,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            TeachingWeekSelector(
              totalWeeks: widget.totalWeeks,
              startWeek: draft.startWeek,
              endWeek: draft.endWeek,
              mode: draft.selectionMode,
              selectedWeeks: draft
                  .weekMask(widget.totalWeeks)
                  .weeks
                  .where((week) => week <= widget.totalWeeks)
                  .toSet(),
              onChanged: _updateWeekSelection,
            ),
          ],
        ),
      ),
    );
  }
}
