import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/widgets/medication_visuals.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/profiles/widgets/profile_switcher.dart';
import 'package:dose_wise/src/features/today/providers/today_providers.dart';
import 'package:dose_wise/src/features/today/widgets/dose_tile.dart';
import 'package:dose_wise/src/features/today/widgets/today_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

final class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh due/late states once a minute (also rolls the list over at
    // midnight). One provider bump per minute — no rebuild storms.
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.read(todayTickProvider.notifier).state++,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        leading: const ProfileChip(),
        actions: [
          IconButton(
            tooltip: 'Dose log',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.log),
          ),
        ],
      ),
      body: appData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            const VaultEmptyState(message: 'Could not load your data.'),
        data: (_) => const Column(
          children: [
            _UpdateCard(),
            Expanded(child: _TodayBody()),
          ],
        ),
      ),
    );
  }
}

/// "Update available" card, shown when a newer GitHub release exists and the
/// user hasn't dismissed it this session.
class _UpdateCard extends ConsumerWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateCheckProvider).valueOrNull;
    final dismissed = ref.watch(updateDismissedProvider);
    if (info == null || dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: UpdateBanner(
        info: info,
        onUpdate: () => ref.read(updateServiceProvider).openDownload(info),
        onDismiss: () =>
            ref.read(updateDismissedProvider.notifier).state = true,
      ),
    );
  }
}

/// A row on today's timeline (kept lightweight so the ListView.builder
/// can build tiles lazily).
sealed class _Row {
  const _Row();
}

final class _HeaderRow extends _Row {
  const _HeaderRow();
}

final class _LowStockRow extends _Row {
  const _LowStockRow(this.medications);

  final List<Medication> medications;
}

final class _TimeRow extends _Row {
  const _TimeRow(this.time);

  final DateTime time;
}

final class _DoseRow extends _Row {
  const _DoseRow(this.dose);

  final TodayDose dose;
}

final class _SectionRow extends _Row {
  const _SectionRow(this.title);

  final String title;
}

final class _AsNeededRow extends _Row {
  const _AsNeededRow(this.medication);

  final Medication medication;
}

final class _TodayBody extends ConsumerWidget {
  const _TodayBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayDosesProvider);
    final asNeeded = ref.watch(asNeededMedicationsProvider);
    final lowStock = ref.watch(lowStockMedicationsProvider);

    if (doses.isEmpty && asNeeded.isEmpty) {
      // Guided first-run CTA when the profile has no medications at all;
      // otherwise it is just a quiet day.
      final hasMedications = ref.watch(activeMedicationsProvider).isNotEmpty;
      return VaultEmptyState(
        icon: Icons.medication_outlined,
        message: hasMedications
            ? 'Nothing on the schedule today.\n'
                'Add a medication and its doses will show up here.'
            : 'Let\'s get started.\nAdd your first medication and '
                'DoseWise will handle the reminders.',
        action: VaultButton(
          label:
              hasMedications ? 'Add medication' : 'Add your first medication',
          isFullWidth: false,
          onPressed: () => context.push(AppRoutes.newMedication),
        ),
      );
    }

    final rows = <_Row>[
      const _HeaderRow(),
      if (lowStock.isNotEmpty) _LowStockRow(lowStock),
    ];
    DateTime? lastTime;
    for (final dose in doses) {
      if (lastTime != dose.displayTime) {
        rows.add(_TimeRow(dose.displayTime));
        lastTime = dose.displayTime;
      }
      rows.add(_DoseRow(dose));
    }
    if (asNeeded.isNotEmpty) {
      rows.add(const _SectionRow('As needed'));
      rows.addAll(asNeeded.map(_AsNeededRow.new));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _HeaderRow() => const TodayHeaderCard(),
          _LowStockRow(medications: final meds) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: LowStockBanner(medications: meds),
            ),
          _TimeRow(time: final time) => Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                formatTime(time),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          _DoseRow(dose: final dose) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DoseTile(dose: dose),
            ),
          _SectionRow(title: final title) => Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          _AsNeededRow(medication: final medication) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AsNeededTile(medication: medication),
            ),
        };
      },
    );
  }
}

final class _AsNeededTile extends ConsumerWidget {
  const _AsNeededTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return VaultCard(
      onTap: () => context.push(AppRoutes.medicationDetail(medication.id)),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 44,
            decoration: BoxDecoration(
              color: medicationColor(medication.colorValue),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
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
                Text(
                  '${medication.dosage} · ${medication.form.label}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Log dose'),
            onPressed: () =>
                ref.read(appDataProvider.notifier).logAsNeededDose(medication),
          ),
        ],
      ),
    );
  }
}
