import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/providers/medication_detail_providers.dart';
import 'package:dose_wise/src/features/medications/widgets/detail_sections.dart';
import 'package:dose_wise/src/features/medications/widgets/medication_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything about one medication: schedule, supply, adherence, and
/// recent history, plus edit / archive / delete actions.
final class MedicationDetailScreen extends ConsumerWidget {
  const MedicationDetailScreen({required this.medicationId, super.key});

  final String medicationId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Medication medication,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${medication.name}?'),
        content: const Text(
          'This removes the medication and its dose history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(appDataProvider.notifier).deleteMedication(medication.id);
    if (context.mounted) context.pop();
  }

  Future<void> _toggleArchived(
    BuildContext context,
    WidgetRef ref,
    Medication medication,
  ) async {
    final archiving = !medication.archived;
    await ref
        .read(appDataProvider.notifier)
        .setArchived(medication.id, archiving);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          archiving
              ? '${medication.name} archived — doses and reminders paused.'
              : '${medication.name} is active again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medication = ref.watch(medicationProvider(medicationId));

    if (medication == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const VaultEmptyState(
          icon: Icons.medication_outlined,
          message: 'This medication is no longer here.',
        ),
      );
    }

    final stats = ref.watch(medicationDetailStatsProvider(medicationId));

    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push(AppRoutes.editMedication(medication.id)),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) => switch (value) {
              'archive' => _toggleArchived(context, ref, medication),
              _ => _delete(context, ref, medication),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      medication.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(medication.archived ? 'Restore' : 'Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _HeaderCard(medication: medication),
          if (medication.tracksStock) ...[
            const SizedBox(height: AppSpacing.md),
            SupplyCard(
              medication: medication,
              daysLeft: stats.daysOfSupplyLeft,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AdherenceCard(medication: medication, stats: stats),
          const SizedBox(height: AppSpacing.md),
          RecentHistoryCard(records: stats.recentRecords),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

final class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return VaultCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MedicationAvatar(medication: medication, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medication.name,
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${medication.dosage} · ${medication.form.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.schedule,
            text: describeSchedule(medication.schedule),
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.event_outlined,
            text: medication.endDate == null
                ? 'Since ${formatDate(medication.startDate)}'
                : '${formatDate(medication.startDate)} – '
                    '${formatDate(medication.endDate!)}',
          ),
          if (medication.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(icon: Icons.notes_outlined, text: medication.notes),
          ],
          if (medication.archived ||
              medication.isLowStock ||
              !medication.remindersEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (medication.archived)
                  StatusChip(
                    label: 'Archived',
                    icon: Icons.archive_outlined,
                    color: AppColors.textTertiary(brightness),
                  ),
                if (medication.isLowStock)
                  StatusChip(
                    label: 'Low supply',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning(brightness),
                  ),
                if (!medication.remindersEnabled)
                  StatusChip(
                    label: 'Reminders off',
                    icon: Icons.notifications_off_outlined,
                    color: AppColors.textTertiary(brightness),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
