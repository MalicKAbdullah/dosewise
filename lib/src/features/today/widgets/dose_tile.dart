import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/widgets/medication_visuals.dart';
import 'package:dose_wise/src/features/today/providers/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One dose on today's timeline with Take/Skip/Snooze/Undo actions and
/// animated status styling.
final class DoseTile extends ConsumerWidget {
  const DoseTile({required this.dose, super.key});

  final TodayDose dose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final medication = dose.medication;
    final notifier = ref.read(appDataProvider.notifier);
    final muted = dose.state == DoseState.skipped;

    return VaultCard(
      onTap: () => context.push(AppRoutes.medicationDetail(medication.id)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: muted ? 0.6 : 1,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: muted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medication.dosage} · ${medication.form.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _StatusBadge(dose: dose),
                      if (medication.isLowStock)
                        StatusChip(
                          label: 'Low supply',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning(theme.brightness),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: dose.isActioned
                  ? IconButton(
                      key: const ValueKey('undo'),
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: () => notifier.undoDose(dose.dose.key),
                    )
                  : Row(
                      key: const ValueKey('actions'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dose.canSnooze)
                          IconButton(
                            tooltip: 'Snooze 15 min',
                            icon: Icon(
                              Icons.snooze,
                              color: AppColors.info(theme.brightness),
                            ),
                            onPressed: () => notifier.snoozeDose(dose.dose),
                          ),
                        IconButton(
                          tooltip: 'Skip',
                          icon: Icon(
                            Icons.close,
                            color: AppColors.textSecondary(theme.brightness),
                          ),
                          onPressed: () => notifier.markDose(
                            dose.dose,
                            DoseOutcome.skipped,
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Take',
                          icon: const Icon(Icons.check),
                          onPressed: () => notifier.markDose(
                            dose.dose,
                            DoseOutcome.taken,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.dose});

  final TodayDose dose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (label, color) = dose.isSnoozed
        ? (
            'Snoozed · ${formatTime(dose.displayTime)}',
            AppColors.info(brightness),
          )
        : switch (dose.state) {
            DoseState.upcoming => (
                'Upcoming',
                AppColors.textSecondary(brightness),
              ),
            DoseState.due => ('Due now', theme.colorScheme.primary),
            DoseState.late => ('Late', AppColors.warning(brightness)),
            DoseState.taken => ('Taken', AppColors.success(brightness)),
            DoseState.skipped => (
                'Skipped',
                AppColors.textTertiary(brightness),
              ),
          };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
