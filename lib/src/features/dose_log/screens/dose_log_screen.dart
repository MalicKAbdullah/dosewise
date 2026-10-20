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

    return Scaffold(
      appBar: AppBar(title: const Text('Dose log')),
      body: log.isEmpty
          ? const AppEmptyState(
              icon: Icons.history,
              title: 'No dose history yet',
              message: 'Taken and skipped doses appear here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                for (final day in log) ...[
                  SectionHeader(title: formatDay(day.day, now: now)),
                  RowGroup(
                    separatorIndent: 52,
                    children: [
                      for (final entry in day.entries) _LogTile(entry: entry),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

final class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final taken = entry.record.outcome == DoseOutcome.taken;
    final color = taken ? c.positive : c.textTertiary;
    final medication = entry.medication;

    return AppListRow(
      dense: true,
      leading: Icon(
        taken ? Icons.check_circle : Icons.cancel_outlined,
        color: color,
      ),
      title: medication?.name ?? 'Deleted medication',
      subtitle:
          taken ? 'Taken at ${formatTime(entry.record.recordedAt)}' : 'Skipped',
      trailing: Text(
        formatTime(entry.record.scheduledTime),
        style: AppTextStyles.numberSmall.copyWith(color: c.textSecondary),
      ),
    );
  }
}
