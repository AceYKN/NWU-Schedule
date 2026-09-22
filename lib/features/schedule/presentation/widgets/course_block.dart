import 'package:flutter/material.dart';

import '../../../../domain/course/course_exception.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../../domain/settings/schedule_display_preferences.dart';
import '../../../shared/presentation/course_card.dart';
import '../../../shared/presentation/course_color_resolver.dart';
import 'course_display_formatter.dart';

class CourseBlock extends StatelessWidget {
  const CourseBlock({
    required this.entry,
    required this.preferences,
    required this.width,
    required this.height,
    required this.visibleDayCount,
    this.isCurrent = false,
    super.key,
  });

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;
  final double width;
  final double height;
  final int visibleDayCount;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColors = CourseColorResolver.resolveSchedule(
      entry.course,
      scheme,
    );
    final location = CourseDisplayFormatter.location(entry);
    final ghost = !entry.active;
    final lines = _lines(location);
    final status = _statusLabel(entry.exceptionType);
    final label = CourseDisplayFormatter.semanticsLabel(entry);
    final foreground = ghost
        ? scheme.onSurfaceVariant.withValues(alpha: .55)
        : activeColors.onContainer;
    final background = ghost
        ? scheme.surfaceContainerHighest.withValues(alpha: .14)
        : activeColors.container;
    final borderColor = ghost
        ? scheme.outlineVariant.withValues(alpha: .7)
        : isCurrent
            ? scheme.primary
            : scheme.outlineVariant.withValues(alpha: .35);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label，点击查看课程详情',
      onTap: () => showCourseDetails(context, entry.instance),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showCourseDetails(context, entry.instance),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: visibleDayCount >= 7 || width < 68 ? 3 : 5,
                vertical: visibleDayCount >= 7 || width < 68 ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor,
                  width: isCurrent && !ghost ? 2 : .7,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _line(lines.first, foreground, true)),
                      if (status != null) ...[
                        const SizedBox(width: 2),
                        _StatusBadge(
                          label: status.label,
                          color: status.color(scheme),
                        ),
                      ],
                    ],
                  ),
                  for (final line in lines.skip(1))
                    _line(line, foreground, false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _lines(String? location) {
    final title = CourseDisplayFormatter.title(entry.course.name);
    if (!entry.active) return [title];
    if (height < 48) return [title];

    final lines = <String>[title];
    if (location != null) lines.add(location);
    if (height >= 80 &&
        preferences.showTeacher &&
        entry.teacher != null &&
        entry.teacher!.trim().isNotEmpty) {
      lines.add(entry.teacher!.trim());
    }
    return lines;
  }

  _CourseStatus? _statusLabel(CourseExceptionType? type) {
    return switch (type) {
      CourseExceptionType.add => const _CourseStatus('加', _StatusKind.add),
      CourseExceptionType.move => const _CourseStatus('调', _StatusKind.move),
      CourseExceptionType.cancel =>
        const _CourseStatus('停', _StatusKind.cancel),
      null => null,
    };
  }

  Widget _line(String value, Color color, bool title) {
    return Text(
      value,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: title ? 12 : 10,
        height: 1.15,
        fontWeight: title ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

enum _StatusKind { add, move, cancel }

class _CourseStatus {
  const _CourseStatus(this.label, this.kind);

  final String label;
  final _StatusKind kind;

  Color color(ColorScheme scheme) {
    return switch (kind) {
      _StatusKind.add => scheme.tertiary,
      _StatusKind.move => scheme.secondary,
      _StatusKind.cancel => scheme.error,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
