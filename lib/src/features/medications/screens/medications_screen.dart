import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/widgets/medication_visuals.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final active = <Medication>[];
    final archived = <Medication>[];
    for (final medication in ref.watch(activeMedicationsProvider)) {
      (medication.archived ? archived : active).add(medication);
    }

    // Flat row list: tiles plus an optional "Archived" section header.
    final rows = <Object>[
      ...active,
      if (archived.isNotEmpty) 'Archived',
      ...archived,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add medication',
        onPressed: () => context.push(AppRoutes.newMedication),
        child: const Icon(Icons.add),
      ),
      body: rows.isEmpty
          ? VaultEmptyState(
              icon: Icons.medication_outlined,
              message: 'No medications yet.\n'
                  'Add one and DoseWise will keep track of every dose.',
              action: VaultButton(
                label: 'Add medication',
                isFullWidth: false,
                onPressed: () => context.push(AppRoutes.newMedication),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      row,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MedicationTile(
                    medication: row as Medication,
                    now: now,
                  ),
                );
              },
            ),
    );
  }
}

final class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.medication, required this.now});

  final Medication medication;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ended = !medication.archived &&
        medication.endDate != null &&
        now.isAfter(medication.endDate!) &&
        !medication.isActiveOn(now);

    return VaultCard(
      onTap: () => context.push(AppRoutes.medicationDetail(medication.id)),
      child: Opacity(
        opacity: medication.archived ? 0.6 : 1,
        child: Row(
          children: [
            MedicationAvatar(medication: medication),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medication.dosage} · ${medication.form.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medication.archived
                        ? 'Archived'
                        : ended
                            ? 'Ended ${formatDate(medication.endDate!)}'
                            : describeSchedule(medication.schedule),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (medication.isLowStock && !medication.archived) ...[
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: 'Low',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning(theme.brightness),
              ),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
