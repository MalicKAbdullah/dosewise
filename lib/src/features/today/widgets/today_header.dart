import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/today/providers/today_providers.dart';
import 'package:dose_wise/src/features/today/widgets/progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The date + progress summary card at the top of Today.
final class TodayHeaderCard extends ConsumerWidget {
  const TodayHeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (taken, total) = ref.watch(todayProgressProvider);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);

    return VaultCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.MMMMEEEEd().format(now),
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    total == 0
                        ? 'No scheduled doses'
                        : taken == total
                            ? 'All done for today!'
                            : '$taken of $total doses taken today',
                    key: ValueKey('$taken/$total'),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ProgressRing(taken: taken, total: total),
        ],
      ),
    );
  }
}

/// Soft warning banner listing medications that are running low.
final class LowStockBanner extends StatelessWidget {
  const LowStockBanner({required this.medications, super.key});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final warning = AppColors.warning(theme.brightness);
    final container = isDark
        ? AppColors.warningContainerDark
        : AppColors.warningContainerLight;
    final names = medications.map((m) => m.name).join(', ');

    return Material(
      color: container.withValues(alpha: isDark ? 0.6 : 0.7),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        onTap: () => context.push(
          AppRoutes.medicationDetail(medications.first.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  medications.length == 1
                      ? '$names is running low — plan a refill soon.'
                      : 'Running low: $names',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
