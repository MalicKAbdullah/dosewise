import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:flutter/material.dart';

/// Controlled editor for a schedule draft. The parent form owns the state;
/// this widget only renders it and reports changes.
final class ScheduleEditor extends StatelessWidget {
  const ScheduleEditor({
    required this.type,
    required this.times,
    required this.weekdays,
    required this.intervalDays,
    required this.onTypeChanged,
    required this.onTimesChanged,
    required this.onWeekdaysChanged,
    required this.onIntervalChanged,
    this.errorText,
    super.key,
  });

  final ScheduleType type;
  final List<DoseTime> times;
  final Set<int> weekdays;
  final int intervalDays;
  final ValueChanged<ScheduleType> onTypeChanged;
  final ValueChanged<List<DoseTime>> onTimesChanged;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final ValueChanged<int> onIntervalChanged;
  final String? errorText;

  static const List<(int, String)> _weekdays = [
    (DateTime.monday, 'Mon'),
    (DateTime.tuesday, 'Tue'),
    (DateTime.wednesday, 'Wed'),
    (DateTime.thursday, 'Thu'),
    (DateTime.friday, 'Fri'),
    (DateTime.saturday, 'Sat'),
    (DateTime.sunday, 'Sun'),
  ];

  Future<void> _addTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final time = DoseTime(hour: picked.hour, minute: picked.minute);
    if (times.contains(time)) return;
    onTimesChanged([...times, time]..sort());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Schedule', style: AppTextStyles.labelStrong),
        const SizedBox(height: AppSpacing.sm),
        AppSegmentedControl<ScheduleType>(
          segments: const [
            AppSegment(value: ScheduleType.weekly, label: 'Weekly'),
            AppSegment(value: ScheduleType.interval, label: 'Every N days'),
            AppSegment(value: ScheduleType.asNeeded, label: 'As needed'),
          ],
          selected: type,
          onChanged: onTypeChanged,
        ),
        if (type == ScheduleType.weekly) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (day, label) in _weekdays)
                AppChip(
                  label: label,
                  selected: weekdays.contains(day),
                  onTap: () => onWeekdaysChanged(
                    weekdays.contains(day)
                        ? ({...weekdays}..remove(day))
                        : {...weekdays, day},
                  ),
                ),
            ],
          ),
        ],
        if (type == ScheduleType.interval) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Every', style: theme.textTheme.bodyMedium),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: intervalDays > 1
                    ? () => onIntervalChanged(intervalDays - 1)
                    : null,
              ),
              Text('$intervalDays', style: AppTextStyles.numberMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: intervalDays < 90
                    ? () => onIntervalChanged(intervalDays + 1)
                    : null,
              ),
              Text(
                intervalDays == 1 ? 'day' : 'days',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        if (type != ScheduleType.asNeeded) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Times of day', style: AppTextStyles.labelStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final time in times)
                InputChip(
                  label: Text(formatDoseTime(time)),
                  onDeleted: () => onTimesChanged([...times]..remove(time)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add time'),
                onPressed: () => _addTime(context),
              ),
            ],
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
