import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/course/course_exception.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import 'course_color_resolver.dart';
import '../../schedule/presentation/course_form_fields.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.instance,
    this.status,
    this.compact = false,
    super.key,
  });

  final EffectiveCourseInstance instance;
  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeTokens = scheduleThemeTokensOf(context);
    final colors = CourseColorResolver.resolve(instance.course, scheme);
    final label = [
      if (status != null) status!,
      instance.courseName,
      if (instance.location != null) instance.location!,
      '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
          '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
      if (instance.teacher != null) instance.teacher!,
    ].join('，');

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: () => showCourseDetails(context, instance),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showCourseDetails(context, instance),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: themeTokens.courseAccentWidth,
                  color: colors.container,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      compact
                          ? themeTokens.compactCoursePadding
                          : themeTokens.cardPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status != null)
                          Text(
                            status!,
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        Text(
                          instance.courseName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          instance.location ?? '地点待补充',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                          '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}'
                          '${instance.teacher == null ? '' : ' · ${instance.teacher}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showCourseDetails(
  BuildContext context,
  EffectiveCourseInstance instance,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final weekMask = instance.meetingRule?.weekMask;
      return Consumer(
          builder: (sheetContext, ref, child) => SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instance.courseName,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 18),
                        _DetailLine(
                            label: '教师', value: instance.teacher ?? '未提供'),
                        _DetailLine(
                          label: '校区',
                          value: instance.campus ?? '未提供',
                        ),
                        _DetailLine(
                          label: '教室',
                          value: instance.room ?? '未提供',
                        ),
                        _DetailLine(
                          label: '星期',
                          value: weekdayName(instance.date.weekday),
                        ),
                        _DetailLine(
                          label: '节次',
                          value:
                              '第 ${instance.startSection}-${instance.endSection} 节',
                        ),
                        _DetailLine(
                          label: '时间',
                          value:
                              '${formatMinutes(instance.startTime.hour * 60 + instance.startTime.minute)}–'
                              '${formatMinutes(instance.endTime.hour * 60 + instance.endTime.minute)}',
                        ),
                        _DetailLine(
                          label: '周次',
                          value: instance.isException || weekMask == null
                              ? '单次课程'
                              : formatWeekMask(weekMask),
                        ),
                        if (instance.course.note != null)
                          _DetailLine(
                              label: '备注', value: instance.course.note!),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (instance.isException &&
                                instance.exceptionId != null)
                              OutlinedButton.icon(
                                onPressed: () => _deleteException(
                                  context,
                                  sheetContext,
                                  ref,
                                  instance.exceptionId!,
                                ),
                                icon: const Icon(Icons.undo_outlined),
                                label: const Text('撤销临时变更'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _showCourseColorPicker(
                                context,
                                sheetContext,
                                ref,
                                instance,
                              ),
                              icon: const Icon(Icons.palette_outlined),
                              label: const Text('修改颜色'),
                            ),
                            if (!instance.isException)
                              OutlinedButton.icon(
                                onPressed: () => _showExceptionEditor(
                                  context,
                                  sheetContext,
                                  ref,
                                  instance,
                                ),
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: const Text('临时变更'),
                              ),
                            if (!instance.isException) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  context
                                      .go('/course/${instance.course.id}/edit');
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('编辑整门课程'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _hideCourse(context,
                                    sheetContext, ref, instance.course.id),
                                icon: const Icon(Icons.visibility_off_outlined),
                                label: const Text('隐藏课程'),
                              ),
                              TextButton.icon(
                                onPressed: () => _deleteCourse(context,
                                    sheetContext, ref, instance.course.id),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除课程'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ));
    },
  );
}

Future<void> showStandaloneAddException({
  required BuildContext pageContext,
  required WidgetRef ref,
  required String semesterId,
  required DateTime initialDate,
}) async {
  final exception = await showModalBottomSheet<CourseException>(
    context: pageContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _StandaloneAddExceptionSheet(
      semesterId: semesterId,
      initialDate: initialDate,
    ),
  );
  if (exception == null || !pageContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).saveException(exception);
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('临时加课已保存')),
      );
    }
  } catch (error) {
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text(nwuUserMessage(error, action: '保存临时加课失败'))),
      );
    }
  }
}

Future<void> _hideCourse(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String courseId,
) async {
  try {
    await ref
        .read(scheduleDataRepositoryProvider)
        .setCourseHidden(courseId, true);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('课程已隐藏')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(nwuUserMessage(error, action: '隐藏失败'))),
      );
    }
  }
}

Future<void> _deleteCourse(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String courseId,
) async {
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除这门课程？'),
      content: const Text('手动课程会从本机移除；教务导入课程会保留删除记录，避免再次导入时自动恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).deleteCourse(courseId);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('课程已删除')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(nwuUserMessage(error, action: '删除失败'))),
      );
    }
  }
}

Future<void> _deleteException(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  String exceptionId,
) async {
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('撤销临时变更？'),
      content: const Text('这条单次调课记录会被删除，原始课表将恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('撤销'),
        ),
      ],
    ),
  );
  if (confirmed != true || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).deleteException(exceptionId);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('临时变更已撤销')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(nwuUserMessage(error, action: '撤销临时变更失败')),
        ),
      );
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

Future<void> _showExceptionEditor(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  EffectiveCourseInstance instance,
) async {
  final exception = await showModalBottomSheet<CourseException>(
    context: sheetContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ExceptionEditorSheet(instance: instance),
  );
  if (exception == null || !sheetContext.mounted) return;
  try {
    await ref.read(scheduleDataRepositoryProvider).saveException(exception);
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('临时变更已保存')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(nwuUserMessage(error, action: '保存临时变更失败')),
        ),
      );
    }
  }
}

Future<void> _showCourseColorPicker(
  BuildContext pageContext,
  BuildContext sheetContext,
  WidgetRef ref,
  EffectiveCourseInstance instance,
) async {
  final selected = await showModalBottomSheet<int>(
    context: sheetContext,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('修改课程颜色'),
            subtitle: Text('颜色覆盖只保存在本机，重新导入不会清除'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _courseColors)
                  Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: instance.course.colorOverride == color
                        ? '课程颜色，已选择'
                        : '选择课程颜色',
                    onTap: () => Navigator.pop(context, color),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, color),
                        borderRadius: BorderRadius.circular(24),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(color),
                          child: instance.course.colorOverride == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, -1),
                  child: const Text('清除覆盖色'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !sheetContext.mounted) return;
  try {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final snapshot = await repository.loadSemester(instance.course.semesterId);
    final rules = snapshot.meetingRules
        .where((rule) => rule.courseId == instance.course.id)
        .toList(growable: false);
    await repository.saveCourse(
      instance.course.copyWith(colorOverride: selected == -1 ? null : selected),
      rules,
    );
    if (!sheetContext.mounted || !pageContext.mounted) return;
    final messenger = ScaffoldMessenger.of(pageContext);
    Navigator.of(sheetContext).pop();
    messenger.showSnackBar(const SnackBar(content: Text('课程颜色已更新')));
  } catch (error) {
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(nwuUserMessage(error, action: '更新课程颜色失败'))),
      );
    }
  }
}

const _courseColors = <int>[
  0xff52766c,
  0xff526579,
  0xff9a7354,
  0xff7b5ea7,
  0xffb25d5d,
  0xff3f7f8f,
  0xff8a6d3b,
  0xff4f7d57,
];

class _ExceptionEditorSheet extends StatefulWidget {
  const _ExceptionEditorSheet({required this.instance});

  final EffectiveCourseInstance instance;

  @override
  State<_ExceptionEditorSheet> createState() => _ExceptionEditorSheetState();
}

class _StandaloneAddExceptionSheet extends StatefulWidget {
  const _StandaloneAddExceptionSheet({
    required this.semesterId,
    required this.initialDate,
  });

  final String semesterId;
  final DateTime initialDate;

  @override
  State<_StandaloneAddExceptionSheet> createState() =>
      _StandaloneAddExceptionSheetState();
}

class _StandaloneAddExceptionSheetState
    extends State<_StandaloneAddExceptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _teacher = TextEditingController();
  final _campus = TextEditingController();
  final _room = TextEditingController();
  final _note = TextEditingController();
  late DateTime _targetDate;
  int _startSection = 1;
  int _endSection = 2;

  @override
  void initState() {
    super.initState();
    _targetDate = dateOnly(widget.initialDate);
  }

  @override
  void dispose() {
    for (final controller in [_name, _teacher, _campus, _room, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _targetDate = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CourseException(
        id: 'exception-${DateTime.now().microsecondsSinceEpoch}',
        semesterId: widget.semesterId,
        type: CourseExceptionType.add,
        targetDate: dateOnly(_targetDate),
        targetStartSection: _startSection,
        targetEndSection: _endSection,
        teacherOverride: _optional(_teacher),
        campusOverride: _optional(_campus),
        roomOverride: _optional(_room),
        addedCourseName: _name.text.trim(),
        note: _optional(_note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Text(
                '临时加课',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              const Text('只在指定日期显示，不会修改周期课表。'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: '课程名 *'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入课程名' : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('上课日期'),
                subtitle: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(_targetDate),
                ),
                onTap: _pickDate,
              ),
              SectionRangeSelector(
                startSection: _startSection,
                endSection: _endSection,
                onChanged: (selection) => setState(() {
                  _startSection = selection.start;
                  _endSection = selection.end;
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _teacher,
                decoration: const InputDecoration(labelText: '教师'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _campus,
                decoration: const InputDecoration(labelText: '校区'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(labelText: '教室'),
              ),
              const SizedBox(height: 12),
              CompactNotesField(controller: _note, label: '备注（可选）'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('保存临时加课'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExceptionEditorSheetState extends State<_ExceptionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _teacher;
  late final TextEditingController _campus;
  late final TextEditingController _room;
  late final TextEditingController _note;
  late DateTime _targetDate;
  late int _startSection;
  late int _endSection;
  CourseExceptionType _type = CourseExceptionType.move;

  EffectiveCourseInstance get _instance => widget.instance;

  @override
  void initState() {
    super.initState();
    _targetDate = dateOnly(_instance.date);
    _startSection = _instance.startSection;
    _endSection = _instance.endSection;
    _teacher = TextEditingController(text: _instance.teacher ?? '');
    _campus = TextEditingController(text: _instance.campus ?? '');
    _room = TextEditingController(text: _instance.room ?? '');
    _note = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in [_teacher, _campus, _room, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _targetDate = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final sourceRule = _instance.meetingRule;
    if ((_type == CourseExceptionType.move ||
            _type == CourseExceptionType.cancel) &&
        sourceRule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到原始上课安排，无法创建临时变更')),
      );
      return;
    }
    final exception = CourseException(
      id: 'exception-${DateTime.now().microsecondsSinceEpoch}',
      semesterId: _instance.course.semesterId,
      courseId: _instance.course.id,
      // ADD from an existing course still uses the clicked meeting as its
      // template. Keep its identity even though ADD has no source date, so a
      // course with multiple arrangements cannot fall back to the first one.
      sourceMeetingId: sourceRule?.id,
      sourceDate:
          _type == CourseExceptionType.add ? null : dateOnly(_instance.date),
      type: _type,
      targetDate: _type == CourseExceptionType.cancel ? null : _targetDate,
      targetStartSection:
          _type == CourseExceptionType.cancel ? null : _startSection,
      targetEndSection:
          _type == CourseExceptionType.cancel ? null : _endSection,
      teacherOverride: _type == CourseExceptionType.cancel
          ? null
          : exceptionOverrideIfChanged(_teacher.text, _instance.teacher),
      campusOverride: _type == CourseExceptionType.cancel
          ? null
          : exceptionOverrideIfChanged(_campus.text, _instance.campus),
      roomOverride: _type == CourseExceptionType.cancel
          ? null
          : exceptionOverrideIfChanged(_room.text, _instance.room),
      addedCourseName:
          _type == CourseExceptionType.add ? _instance.course.name : null,
      note: _optional(_note),
    );
    Navigator.of(context).pop(exception);
  }

  @override
  Widget build(BuildContext context) {
    final needsTarget = _type != CourseExceptionType.cancel;
    final maxHeight = MediaQuery.sizeOf(context).height * .82;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Text(
                '临时变更 · ${_instance.courseName}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                  '原安排：${_instance.date.year}-${_instance.date.month}-${_instance.date.day} · 第 ${_instance.startSection}-${_instance.endSection} 节'),
              const SizedBox(height: 16),
              DropdownButtonFormField<CourseExceptionType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '变更类型'),
                items: const [
                  DropdownMenuItem(
                    value: CourseExceptionType.move,
                    child: Text('MOVE · 移动本次课程'),
                  ),
                  DropdownMenuItem(
                    value: CourseExceptionType.cancel,
                    child: Text('CANCEL · 停止本次课程'),
                  ),
                  DropdownMenuItem(
                    value: CourseExceptionType.add,
                    child: Text('ADD · 临时增加一次课程'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              if (needsTarget) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('目标日期'),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(_targetDate),
                  ),
                  onTap: _pickDate,
                ),
                SectionRangeSelector(
                  startSection: _startSection,
                  endSection: _endSection,
                  onChanged: (selection) => setState(() {
                    _startSection = selection.start;
                    _endSection = selection.end;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _teacher,
                  decoration: const InputDecoration(labelText: '教师'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _campus,
                  decoration: const InputDecoration(labelText: '校区'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _room,
                  decoration: const InputDecoration(labelText: '教室'),
                ),
              ],
              const SizedBox(height: 12),
              CompactNotesField(controller: _note, label: '备注（可选）'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('保存临时变更'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
