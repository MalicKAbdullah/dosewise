import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/dose_log/providers/dose_log_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// History of taken/skipped doses grouped by day, newest first. The list
/// is flattened so ListView.builder can lazily build long histories.
final class DoseLogScreen extends ConsumerWidget {
  const DoseLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(doseLogProvider);
    final now = ref.watch(clockProvider)();

    // Flatten day headers and entries into one lazily-built list.
    final rows = <Object>[
      for (final day in log) ...[day.day, ...day.entries],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dose log')),
      body: log.isEmpty
          ? const VaultEmptyState(
              icon: Icons.history,
              message:
                  'No dose history yet.\nTaken and skipped doses appear here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      formatDay(row, now: now),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LogTile(entry: row as LogEntry),
                );
              },
            ),
    );
  }
}

final class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = entry.record.outcome == DoseOutcome.taken;
    final color = taken
        ? AppColors.success(theme.brightness)
        : AppColors.textTertiary(theme.brightness);
    final medication = entry.medication;

    return VaultCard(
      child: Row(
        children: [
          Icon(
            taken ? Icons.check_circle : Icons.cancel_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication?.name ?? 'Deleted medication',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  taken
                      ? 'Taken at ${formatTime(entry.record.recordedAt)}'
                      : 'Skipped',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatTime(entry.record.scheduledTime),
            style: AppTextStyles.numberSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
