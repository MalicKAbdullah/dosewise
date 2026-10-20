import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/widgets/profile_switcher.dart';
import 'package:dose_wise/src/features/today/providers/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Built once and reused: constructing a [DateFormat] parses its skeleton,
/// which is wasted work on every rebuild (the header rebuilds each minute
/// as the ticker refreshes due/late states).
final DateFormat _headerDateFormat = DateFormat.MMMMEEEEd();

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Date eyebrow, greeting and the profile / dose-log actions.
final class TodayGreeting extends ConsumerWidget {
  const TodayGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final c = SuiteColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _headerDateFormat.format(now),
                style: AppTextStyles.label.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(_greeting(now), style: AppTextStyles.h2),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Dose log',
          icon: const Icon(Icons.history),
          onPressed: () => context.push(AppRoutes.log),
        ),
        const ProfileChip(),
      ],
    );
  }
}

/// The one hero of Today: doses taken out of doses due, the sentence that
/// explains it, and what still needs attention.
final class TodayHeaderCard extends ConsumerWidget {
  const TodayHeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayDosesProvider);
    final (taken, total) = ref.watch(todayProgressProvider);
    final c = SuiteColors.of(context);
    final needsYou = doses
        .where((d) => d.state == DoseState.due || d.state == DoseState.late)
        .length;
    final upcoming = doses.where((d) => d.state == DoseState.upcoming).length;
    final skipped = doses.where((d) => d.state == DoseState.skipped).length;

    final sentence = total == 0
        ? 'No scheduled doses'
        : taken == total
            ? 'All done for today!'
            : '$taken of $total doses taken today';

    return HeroMetricCard(
      label: 'Doses today',
      value: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$taken'),
                TextSpan(
                  text: '/$total',
                  style: AppTextStyles.numberLarge.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
            style: AppTextStyles.hero.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppProgressBar(
            value: total == 0 ? 0 : taken / total,
            color: c.accent,
          ),
        ],
      ),
      deltaCaption: sentence,
      footer: [
        StatTile(
          label: 'Done',
          value: '$taken',
          dotColor: c.positive,
        ),
        StatTile(
          label: 'Needs you',
          value: '$needsYou',
          dotColor: needsYou > 0 ? c.warning : c.textTertiary,
        ),
        StatTile(
          label: skipped > 0 ? 'Later · $skipped skipped' : 'Later',
          value: '$upcoming',
          dotColor: c.info,
        ),
      ],
    );
  }
}

/// Soft warning banner listing medications that are running low.
final class LowStockBanner extends StatelessWidget {
  const LowStockBanner({required this.medications, super.key});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final names = medications.map((m) => m.name).join(', ');
    return AppBanner(
      kind: BannerKind.warning,
      title: medications.length == 1
          ? '$names is running low — plan a refill soon.'
          : 'Running low: $names',
      onTap: () => context.push(
        AppRoutes.medicationDetail(medications.first.id),
      ),
    );
  }
}
