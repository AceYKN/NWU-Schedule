import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../core/nwu/periods.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/course/course.dart';
import '../../../domain/course/meeting_rule.dart';
import '../../../domain/errors/app_error.dart';

class ManualCoursePage extends ConsumerStatefulWidget {
  const ManualCoursePage({this.courseId, super.key});

  final String? courseId;

  @override
  ConsumerState<ManualCoursePage> createState() => _ManualCoursePageState();
}

class _ManualCoursePageState extends ConsumerState<ManualCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _teachingClass = TextEditingController();
  final _credits = TextEditingController();
  final _assessment = TextEditingController();
  final _teacher = TextEditingController();
  final _campus = TextEditingController();
  final _room = TextEditingController();
  final _weeks = TextEditingController();
  final _note = TextEditingController();
  int _weekday = 1;
  int _startSection = 1;
  int _endSection = 2;
  bool _saving = false;
  bool _initialized = false;
  Course? _existingCourse;
  List<MeetingRule> _existingRules = const [];
  int _selectedRuleIndex = 0;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _code,
      _teachingClass,
      _credits,
      _assessment,
      _teacher,
      _campus,
      _room,
      _weeks,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _optionalCredits() {
    final value = _credits.text.trim();
    return value.isEmpty ? null : double.parse(value);
  }

  void _loadRule(MeetingRule rule) {
    _teacher.text = rule.teacher ?? '';
    _campus.text = rule.campus ?? '';
    _room.text = rule.room ?? '';
    _weeks.text = formatWeekMask(rule.weekMask);
    _weekday = rule.weekday;
    _startSection = rule.startSection;
    _endSection = rule.endSection;
  }

  void _initializeEdit(ScheduleReady ready) {
    if (_initialized || widget.courseId == null) return;
    for (final course in ready.engine.courses) {
      if (course.id == widget.courseId) _existingCourse = course;
    }
    if (_existingCourse == null) return;
    _existingRules = ready.engine.meetingRules
        .where((rule) => rule.courseId == widget.courseId)
        .toList(growable: false);
    _name.text = _existingCourse!.name;
    _code.text = _existingCourse!.code ?? '';
    _teachingClass.text = _existingCourse!.teachingClass ?? '';
    _credits.text = _existingCourse!.credits?.toString() ?? '';
    _assessment.text = _existingCourse!.assessment ?? '';
    _note.text = _existingCourse!.note ?? '';
    if (_existingRules.isNotEmpty) _loadRule(_existingRules.first);
    _initialized = true;
  }

  Future<void> _save(ScheduleReady ready) async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final totalWeeks = ready.engine.calendarEngine.definition.totalWeeks;
      final mask = WeekMask.parseManual(_weeks.text, maxWeek: totalWeeks);
      final id = _existingCourse?.id ??
          'manual-${DateTime.now().microsecondsSinceEpoch}';
      final course = _existingCourse?.copyWith(
            name: _name.text.trim(),
            code: _optional(_code),
            teachingClass: _optional(_teachingClass),
            credits: _optionalCredits(),
            assessment: _optional(_assessment),
            note: _optional(_note),
          ) ??
          Course(
            id: id,
            semesterId: ready.semester.id,
            sourceType: CourseSourceType.manual,
            name: _name.text.trim(),
            code: _optional(_code),
            teachingClass: _optional(_teachingClass),
            credits: _optionalCredits(),
            assessment: _optional(_assessment),
            note: _optional(_note),
          );
      final rules = List<MeetingRule>.of(_existingRules);
      final existingRule = rules.isEmpty ? null : rules[_selectedRuleIndex];
      final rule = existingRule?.copyWith(
            weekday: _weekday,
            startSection: _startSection,
            endSection: _endSection,
            teacher: _optional(_teacher),
            campus: _optional(_campus),
            room: _optional(_room),
            weekMask: mask,
          ) ??
          MeetingRule(
            id: '$id-rule',
            courseId: id,
            weekday: _weekday,
            startSection: _startSection,
            endSection: _endSection,
            teacher: _optional(_teacher),
            campus: _optional(_campus),
            room: _optional(_room),
            weekMask: mask,
          );
      if (rules.isEmpty) {
        rules.add(rule);
      } else {
        rules[_selectedRuleIndex] = rule;
      }
      await ref.read(scheduleDataRepositoryProvider).saveCourse(course, rules);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/schedule');
      messenger.showSnackBar(
        const SnackBar(content: Text('课程已保存到本地')),
      );
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

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('无法读取学期')),
      data: (state) {
        if (state is! ScheduleReady) {
          return const Center(child: Text('请先在设置中创建学期'));
        }
        _initializeEdit(state);
        if (widget.courseId != null && _existingCourse == null) {
          return const Center(child: Text('找不到这门课程'));
        }
        final totalWeeks = state.engine.calendarEngine.definition.totalWeeks;
        if (_weeks.text.isEmpty) _weeks.text = '1-$totalWeeks周';
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              Text(widget.courseId == null ? '手动添加课程' : '编辑整门课程',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(state.semester.label),
              const SizedBox(height: 22),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '课程名 *'),
                maxLength: 80,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入课程名' : null,
              ),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: '课程代码'),
              ),
              TextFormField(
                controller: _teachingClass,
                decoration: const InputDecoration(labelText: '教学班'),
              ),
              TextFormField(
                controller: _credits,
                decoration: const InputDecoration(labelText: '学分'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  return parsed == null || parsed < 0 ? '请输入有效学分' : null;
                },
              ),
              TextFormField(
                controller: _assessment,
                decoration: const InputDecoration(labelText: '考核方式'),
              ),
              if (_existingRules.length > 1) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedRuleIndex,
                  decoration: const InputDecoration(labelText: '选择上课安排'),
                  items: List.generate(
                    _existingRules.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text('安排 ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedRuleIndex = value;
                      _loadRule(_existingRules[value]);
                    });
                  },
                ),
                const Text('每次保存只修改选中的上课安排，其余安排保持不变。'),
              ],
              TextFormField(
                controller: _teacher,
                decoration: const InputDecoration(labelText: '教师'),
              ),
              TextFormField(
                controller: _campus,
                decoration: const InputDecoration(labelText: '校区'),
              ),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(labelText: '教室'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: '星期'),
                items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('星期${'一二三四五六日'[index]}'),
                        )),
                onChanged: (value) => setState(() => _weekday = value ?? 1),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: DropdownButtonFormField<int>(
                    initialValue: _startSection,
                    decoration: const InputDecoration(labelText: '开始节'),
                    items: List.generate(
                        NwuPeriodRepository.all.length,
                        (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('第 ${index + 1} 节'),
                            )),
                    onChanged: (value) => setState(() {
                      _startSection = value ?? 1;
                      if (_endSection < _startSection) {
                        _endSection = _startSection;
                      }
                    }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: DropdownButtonFormField<int>(
                    key: ValueKey(_endSection),
                    initialValue: _endSection,
                    decoration: const InputDecoration(labelText: '结束节'),
                    items: List.generate(
                        NwuPeriodRepository.all.length,
                        (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('第 ${index + 1} 节'),
                            )),
                    onChanged: (value) =>
                        setState(() => _endSection = value ?? 1),
                    validator: (value) => value == null || value < _startSection
                        ? '结束节不能早于开始节'
                        : null,
                  )),
                ],
              ),
              TextFormField(
                controller: _weeks,
                decoration: InputDecoration(
                  labelText: '周次 *',
                  helperText: '如 1-$totalWeeks周、1-15周单周、1,3,5周',
                ),
                validator: (value) {
                  try {
                    WeekMask.parseManual(value ?? '', maxWeek: totalWeeks);
                    return null;
                  } catch (_) {
                    return '请输入有效周次';
                  }
                },
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: '备注'),
                maxLines: 2,
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
