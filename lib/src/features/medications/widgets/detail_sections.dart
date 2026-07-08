import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/providers/medication_detail_providers.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:dose_wise/src/features/stats/widgets/adherence_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supply status + refill action for a stock-tracked medication.
final class SupplyCard extends ConsumerWidget {
  const SupplyCard({
    required this.medication,
    required this.daysLeft,
    super.key,
  });

  final Medication medication;
  final int? daysLeft;

  Future<void> _refill(BuildContext context, WidgetRef ref) async {
    final units = await showRefillDialog(context, medication);
    if (units == null || units <= 0) return;
    await ref
        .read(appDataProvider.notifier)
        .refillMedication(medication.id, units);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final low = medication.isLowStock;
    final stock = medication.currentStock ?? 0;
    final stockColor =
        low ? AppColors.warning(brightness) : theme.colorScheme.onSurface;

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supply', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        '$stock',
                        key: ValueKey(stock),
                        style: AppTextStyles.numberLarge
                            .copyWith(color: stockColor),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysLeft == null
                          ? 'doses left'
                          : 'doses left · about $daysLeft '
                              '${daysLeft == 1 ? 'day' : 'days'} of supply',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (low) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Running low — time to plan a refill.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning(brightness),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                onPressed: () => _refill(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Refill'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks how many units were added. Returns null when cancelled.
Future<int?> showRefillDialog(BuildContext context, Medication medication) {
  final controller = TextEditingController(text: '30');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Refill ${medication.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How many doses did you add?'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 30'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(controller.text.trim())),
          child: const Text('Add to supply'),
        ),
      ],
    ),
  );
}

/// 7-day / 30-day adherence numbers plus a 14-day mini bar chart.
final class AdherenceCard extends StatelessWidget {
  const AdherenceCard({
    required this.medication,
    required this.stats,
    super.key,
  });

  final Medication medication;
  final MedicationDetailStats stats;

  static String _percent(AdherenceStats stats) =>
      stats.rate == null ? '—' : '${(stats.rate! * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = stats.month.scheduled > 0;

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adherence', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (!hasData)
            Text(
              'No scheduled doses in the last 30 days yet.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _AdherenceStat(
                    label: 'Last 7 days',
                    value: _percent(stats.week),
                  ),
                ),
                Expanded(
                  child: _AdherenceStat(
                    label: 'Last 30 days',
                    value: _percent(stats.month),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            RepaintBoundary(
              child: AdherenceBarChart(
                days: stats.recentDaily,
                height: 120,
                barColor: Color(medication.colorValue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _AdherenceStat extends StatelessWidget {
  const _AdherenceStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppTextStyles.numberLarge
                .copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// The last few taken/skipped records for this medication.
final class RecentHistoryCard extends StatelessWidget {
  const RecentHistoryCard({required this.records, super.key});

  final List<DoseRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent history', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (records.isEmpty)
            Text(
              'Doses you take or skip will show up here.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final record in records)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      record.outcome == DoseOutcome.taken
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      size: 18,
                      color: record.outcome == DoseOutcome.taken
                          ? AppColors.success(brightness)
                          : AppColors.textTertiary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${formatDate(record.scheduledTime)} · '
                        '${formatTime(record.scheduledTime)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      record.outcome == DoseOutcome.taken
                          ? 'Taken ${formatTime(record.recordedAt)}'
                          : 'Skipped',
                      style: AppTextStyles.numberSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
