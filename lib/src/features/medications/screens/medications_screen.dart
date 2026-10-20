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

final class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final query = _query.trim().toLowerCase();
    final all = ref.watch(activeMedicationsProvider);
    final active = <Medication>[];
    final archived = <Medication>[];
    for (final medication in all) {
      if (query.isNotEmpty && !medication.name.toLowerCase().contains(query)) {
        continue;
      }
      (medication.archived ? archived : active).add(medication);
    }

    // Flat row list: tiles plus an optional "Archived" section header.
    final rows = <Object>[
      ...active,
      if (archived.isNotEmpty) 'Archived',
      ...archived,
    ];

    final activeRows = rows.takeWhile((r) => r is Medication).toList();
    final archivedRows = rows.skipWhile((r) => r is Medication).skip(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add medication',
        onPressed: () => context.push(AppRoutes.newMedication),
        child: const Icon(Icons.add),
      ),
      body: all.isEmpty
          ? AppEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medications yet',
              message: 'Add one and DoseWise will keep track of every dose.',
              action: VaultButton(
                label: 'Add medication',
                isFullWidth: false,
                onPressed: () => context.push(AppRoutes.newMedication),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: AppSearchField(
                    hint: 'Search medications',
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.search_off,
                          title: 'No medications match your search',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            96,
                          ),
                          children: [
                            if (activeRows.isNotEmpty)
                              RowGroup(
                                children: [
                                  for (final m in activeRows)
                                    _MedicationTile(
                                      medication: m as Medication,
                                      now: now,
                                    ),
                                ],
                              ),
                            if (archived.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const SectionHeader(title: 'Archived'),
                              RowGroup(
                                children: [
                                  for (final m in archivedRows)
                                    _MedicationTile(
                                      medication: m as Medication,
                                      now: now,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                ),
              ],
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
    final ended = !medication.archived &&
        medication.endDate != null &&
        now.isAfter(medication.endDate!) &&
        !medication.isActiveOn(now);

    return Opacity(
      opacity: medication.archived ? 0.6 : 1,
      child: AppListRow(
        leading: MedicationAvatar(medication: medication),
        title: medication.name,
        subtitle: medication.archived
            ? 'Archived'
            : ended
                ? 'Ended ${formatDate(medication.endDate!)}'
                : '${medication.dosage} · ${medication.form.label}',
        trailing: medication.isLowStock && !medication.archived
            ? StatusChip(
                label: 'Low',
                icon: Icons.warning_amber_rounded,
                color: SuiteColors.of(context).warning,
              )
            : null,
        showChevron: true,
        onTap: () => context.push(AppRoutes.medicationDetail(medication.id)),
      ),
    );
  }
}
