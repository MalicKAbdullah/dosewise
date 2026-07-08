import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/stats/providers/heatmap_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet listing every dose on a tapped heatmap day.
Future<void> showDayDosesSheet(BuildContext context, DateTime day) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _DayDosesSheet(day: day),
    );

final class _DayDosesSheet extends ConsumerWidget {
  const _DayDosesSheet({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(dayDosesProvider(day));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(day), style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Nothing was scheduled or logged this day.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _DayDoseRow(entry: entries[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _DayDoseRow extends StatelessWidget {
  const _DayDoseRow({required this.entry});

  final DayDoseEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (label, color) = switch (entry.outcome) {
      DoseOutcome.taken => ('Taken', AppColors.success(brightness)),
      DoseOutcome.skipped => ('Skipped', AppColors.textTertiary(brightness)),
      null => ('Missed', AppColors.warning(brightness)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(entry.medication.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.medication.name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatTime(entry.time),
            style: AppTextStyles.numberSmall
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
