import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/meeting_draft.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../../domain/course/week_pattern.dart';
import '../../../domain/errors/app_error.dart';
import '../../shared/presentation/app_page_header.dart';
import 'course_form_fields.dart';

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
        const SnackBar(content: Text('课程至少需要一个上课安排')),
      );
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
        title: const Text('删除存在临时变更的上课安排？'),
        content: Text(
          '该上课安排存在 ${affected.length} 条临时变更。\n'
          '删除后相关临时变更也将删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _save(ScheduleReady ready) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('课程至少需要一个上课安排')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final totalWeeks = ready.engine.totalWeeks;
      final masks = [
        for (final draft in _drafts) draft.weekMask(totalWeeks),
      ];
      final id = _existingCourse?.id ??
          'manual-${DateTime.now().microsecondsSinceEpoch}';
      final course = _existingCourse?.copyWith(
            name: _name.text.trim(),
            note: _optional(_note),
          ) ??
          Course(
            id: id,
            semesterId: ready.semester.id,
            sourceType: CourseSourceType.manual,
            name: _name.text.trim(),
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
                exception.courseId == course.id &&
                exception.sourceMeetingId != null &&
                deletedRuleIds.contains(exception.sourceMeetingId),
          )
          .map((exception) => exception.id)
          .toList(growable: false);
      final savedAt = DateTime.now().microsecondsSinceEpoch;
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
      await repository.saveCourse(
        course,
        rules,
        removeExceptionIds: deletedExceptionIds,
      );
      // The edit route can be reopened immediately after this save. Do not
      // let it reuse the previous ScheduleEngine snapshot while Drift's
      // change stream is still scheduling its next emission.
      ref.invalidate(scheduleLoadProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/schedule');
      messenger.showSnackBar(const SnackBar(content: Text('课程已保存到本地')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nwuUserMessage(error, action: '保存失败'))),
        );
      }
    } finally {
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
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(nwuUserMessage(error, action: '读取学期失败')),
      ),
      data: (state) {
        if (state is! ScheduleReady) {
          return const Center(child: Text('请先在设置中创建学期'));
        }
        final totalWeeks = state.engine.totalWeeks;
        _initialize(state, totalWeeks);
        if (widget.courseId != null && _existingCourse == null) {
          return const Center(child: Text('找不到这门课程'));
        }
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
            children: [
              AppPageHeader(
                title: widget.courseId == null ? '手动添加课程' : '编辑整门课程',
                subtitle: state.semester.label,
              ),
              const SizedBox(height: 24),
              const _SectionHeading(title: '课程信息'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '课程名 *'),
                maxLength: 80,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入课程名称' : null,
              ),
              const SizedBox(height: 12),
              CompactNotesField(controller: _note),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: _SectionHeading(title: '上课安排')),
                  Text('${_drafts.length} 条'),
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
                label: const Text('添加上课安排'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _save(state),
                child: Text(_saving ? '保存中…' : '保存课程'),
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
                    '上课安排 ${widget.index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: '复制安排',
                  onPressed: widget.onCopy,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: '删除安排',
                  onPressed: widget.canDelete ? widget.onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: draft.weekday,
              decoration: const InputDecoration(labelText: '星期'),
              items: List.generate(
                7,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('星期${'一二三四五六日'[index]}'),
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
              decoration: const InputDecoration(
                labelText: CourseFieldLabels.teacher,
              ),
              onChanged: (_) => _updateText(),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final campusField = TextFormField(
                  controller: _campus,
                  decoration: const InputDecoration(
                    labelText: CourseFieldLabels.campus,
                  ),
                  onChanged: (_) => _updateText(),
                );
                final roomField = TextFormField(
                  controller: _room,
                  decoration: const InputDecoration(
                    labelText: CourseFieldLabels.room,
                  ),
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
