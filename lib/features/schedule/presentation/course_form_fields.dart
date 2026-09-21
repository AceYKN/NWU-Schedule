import 'package:flutter/material.dart';

import '../../../core/nwu/periods.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/course/week_pattern.dart';

class SectionRangeSelection {
  const SectionRangeSelection({required this.start, required this.end});

  final int start;
  final int end;
}

/// Compact, responsive start/end section picker shared by course forms.
class SectionRangeSelector extends StatelessWidget {
  const SectionRangeSelector({
    required this.startSection,
    required this.endSection,
    required this.onChanged,
    super.key,
  });

  final int startSection;
  final int endSection;
  final ValueChanged<SectionRangeSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final startField = DropdownButtonFormField<int>(
          initialValue: startSection,
          decoration: const InputDecoration(labelText: '开始节'),
          items: _items(),
          onChanged: (value) {
            final start = value ?? startSection;
            onChanged(
              SectionRangeSelection(
                start: start,
                end: endSection < start ? start : endSection,
              ),
            );
          },
        );
        final endField = DropdownButtonFormField<int>(
          key: ValueKey(endSection),
          initialValue: endSection,
          decoration: const InputDecoration(labelText: '结束节'),
          items: _items(),
          onChanged: (value) {
            final end = value ?? endSection;
            onChanged(
              SectionRangeSelection(
                start: startSection,
                end: end < startSection ? startSection : end,
              ),
            );
          },
        );
        if (constraints.maxWidth >= 320) {
          return Row(
            children: [
              Expanded(child: startField),
              const SizedBox(width: 12),
              Expanded(child: endField),
            ],
          );
        }
        return Column(
          children: [
            startField,
            const SizedBox(height: 12),
            endField,
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<int>> _items() => [
        for (final period in NwuPeriodRepository.all)
          DropdownMenuItem(
            value: period.number,
            child: Text('第 ${period.number} 节'),
          ),
      ];
}

class TeachingWeekSelection {
  TeachingWeekSelection({
    required this.startWeek,
    required this.endWeek,
    required this.mode,
    required Set<int> selectedWeeks,
  }) : selectedWeeks = Set.unmodifiable(selectedWeeks);

  final int startWeek;
  final int endWeek;
  final WeekSelectionMode mode;
  final Set<int> selectedWeeks;
}

/// Pure UI for regular and irregular teaching-week masks.
class TeachingWeekSelector extends StatelessWidget {
  const TeachingWeekSelector({
    required this.totalWeeks,
    required this.startWeek,
    required this.endWeek,
    required this.mode,
    required this.selectedWeeks,
    required this.onChanged,
    super.key,
  });

  final int totalWeeks;
  final int startWeek;
  final int endWeek;
  final WeekSelectionMode mode;
  final Set<int> selectedWeeks;
  final ValueChanged<TeachingWeekSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeRange = _safeRange;
    final weeks = _normalisedWeeks(safeRange.start, safeRange.end);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('周次', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final startField = DropdownButtonFormField<int>(
              initialValue: safeRange.start,
              decoration: const InputDecoration(labelText: '起始周'),
              items: _weekItems(),
              onChanged: (value) => _changeRange(
                start: value ?? safeRange.start,
                end: safeRange.end,
              ),
            );
            final endField = DropdownButtonFormField<int>(
              key: ValueKey(safeRange.end),
              initialValue: safeRange.end,
              decoration: const InputDecoration(labelText: '结束周'),
              items: _weekItems(),
              onChanged: (value) => _changeRange(
                start: safeRange.start,
                end: value ?? safeRange.end,
              ),
            );
            if (constraints.maxWidth >= 320) {
              return Row(
                children: [
                  Expanded(child: startField),
                  const SizedBox(width: 12),
                  Expanded(child: endField),
                ],
              );
            }
            return Column(
              children: [
                startField,
                const SizedBox(height: 12),
                endField,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final candidate in WeekSelectionMode.values)
              ChoiceChip(
                label: Text(candidate.label),
                selected: mode == candidate,
                onSelected: (_) => _selectMode(candidate, weeks),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '本安排覆盖 ${weeks.length} 周',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var week = 1; week <= totalWeeks; week++)
              _WeekChip(
                week: week,
                selected: weeks.contains(week),
                onTap: () => _toggleWeek(context, week, weeks),
              ),
          ],
        ),
      ],
    );
  }

  ({int start, int end}) get _safeRange {
    final start = startWeek.clamp(1, totalWeeks).toInt();
    final end = endWeek.clamp(start, totalWeeks).toInt();
    return (start: start, end: end);
  }

  Set<int> _normalisedWeeks(int start, int end) {
    final candidates =
        selectedWeeks.where((week) => week >= 1 && week <= totalWeeks).toSet();
    if (mode != WeekSelectionMode.custom) {
      return _weeksForMode(mode, start, end);
    }
    final custom = candidates.where((week) => week >= start && week <= end);
    if (custom.isNotEmpty) return custom.toSet();
    return {start};
  }

  Set<int> _weeksForMode(WeekSelectionMode selectionMode, int start, int end) {
    if (selectionMode == WeekSelectionMode.custom) {
      return _normalisedWeeks(start, end);
    }
    return {
      for (var week = start; week <= end; week++)
        if (selectionMode == WeekSelectionMode.all ||
            selectionMode == WeekSelectionMode.odd && week.isOdd ||
            selectionMode == WeekSelectionMode.even && week.isEven)
          week,
    };
  }

  void _selectMode(WeekSelectionMode nextMode, Set<int> currentWeeks) {
    if (nextMode == WeekSelectionMode.custom) {
      onChanged(
        TeachingWeekSelection(
          startWeek: currentWeeks.reduce((a, b) => a < b ? a : b),
          endWeek: currentWeeks.reduce((a, b) => a > b ? a : b),
          mode: nextMode,
          selectedWeeks: currentWeeks,
        ),
      );
      return;
    }
    final range = _safeRange;
    onChanged(
      TeachingWeekSelection(
        startWeek: range.start,
        endWeek: range.end,
        mode: nextMode,
        selectedWeeks: _weeksForMode(nextMode, range.start, range.end),
      ),
    );
  }

  void _changeRange({required int start, required int end}) {
    var nextStart = start.clamp(1, totalWeeks).toInt();
    var nextEnd = end.clamp(1, totalWeeks).toInt();
    if (nextStart > nextEnd) nextEnd = nextStart;
    if (nextEnd < nextStart) nextStart = nextEnd;
    if (mode != WeekSelectionMode.custom) {
      onChanged(
        TeachingWeekSelection(
          startWeek: nextStart,
          endWeek: nextEnd,
          mode: mode,
          selectedWeeks: _weeksForMode(mode, nextStart, nextEnd),
        ),
      );
      return;
    }
    final next = selectedWeeks
        .where((week) => week >= nextStart && week <= nextEnd)
        .toSet();
    if (next.isEmpty) next.add(nextStart);
    onChanged(
      TeachingWeekSelection(
        startWeek: next.reduce((a, b) => a < b ? a : b),
        endWeek: next.reduce((a, b) => a > b ? a : b),
        mode: WeekSelectionMode.custom,
        selectedWeeks: next,
      ),
    );
  }

  void _toggleWeek(
    BuildContext context,
    int week,
    Set<int> currentWeeks,
  ) {
    final next = {...currentWeeks};
    if (next.remove(week)) {
      if (next.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('至少选择一个教学周')),
        );
        return;
      }
    } else {
      next.add(week);
    }
    final start = next.reduce((a, b) => a < b ? a : b);
    final end = next.reduce((a, b) => a > b ? a : b);
    onChanged(
      TeachingWeekSelection(
        startWeek: start,
        endWeek: end,
        mode: WeekSelectionMode.custom,
        selectedWeeks: next,
      ),
    );
  }

  List<DropdownMenuItem<int>> _weekItems() => [
        for (var week = 1; week <= totalWeeks; week++)
          DropdownMenuItem(value: week, child: Text('$week')),
      ];
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.week,
    required this.selected,
    required this.onTap,
  });

  final int week;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: selected,
      label: '第 $week 周${selected ? '，已选择' : '，未选择'}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$week',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
          ),
        ),
      ),
    );
  }
}

class CompactNotesField extends StatelessWidget {
  const CompactNotesField({
    required this.controller,
    this.label = '备注',
    super.key,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      minLines: 2,
      maxLines: 3,
    );
  }
}

WeekMask weekMaskFromSelection(TeachingWeekSelection selection) {
  return WeekMask.fromWeeks(selection.selectedWeeks);
}
