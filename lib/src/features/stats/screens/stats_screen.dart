import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/medications/widgets/medication_visuals.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/stats/providers/heatmap_providers.dart';
import 'package:dose_wise/src/features/stats/providers/stats_providers.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:dose_wise/src/features/stats/services/pdf/adherence_report_pdf_service.dart';
import 'package:dose_wise/src/features/stats/widgets/adherence_bar_chart.dart';
import 'package:dose_wise/src/features/stats/widgets/adherence_heatmap.dart';
import 'package:dose_wise/src/features/stats/widgets/day_doses_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static String _percent(AdherenceStats stats) {
    final rate = stats.rate;
    return rate == null ? '—' : '${(rate * 100).round()}%';
  }

  /// Asks for the report window (30/90 days), renders the PDF off the UI
  /// thread, and hands it to the share sheet.
  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export report (PDF)'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(30),
            child: const Text('Last 30 days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(90),
            child: const Text('Last 90 days'),
          ),
        ],
      ),
    );
    if (days == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = ref.read(clockProvider)();
      final bytes = await AdherenceReportPdfService.renderInBackground(
        medications: ref.read(activeMedicationsProvider),
        records: ref.read(activeRecordsProvider),
        now: now,
        days: days,
        patientName: ref.read(activeProfileProvider).name,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}dosewise-report-'
        '${DateFormat('yyyy-MM-dd').format(now)}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'DoseWise $days-day report',
        ),
      );
      await file.delete();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create the PDF report.')),
      );
    }
  }

  Future<void> _shareReport(WidgetRef ref) async {
    final report = ref.read(reportBuilderProvider).build(
          medications: ref.read(activeMedicationsProvider),
          records: ref.read(activeRecordsProvider),
          now: ref.read(clockProvider)(),
        );
    await SharePlus.instance.share(
      ShareParams(text: report, subject: 'DoseWise adherence report'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final hasData = stats.month.scheduled > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          if (hasData) ...[
            IconButton(
              tooltip: 'Export report (PDF)',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _exportPdf(context, ref),
            ),
            IconButton(
              tooltip: 'Share report',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _shareReport(ref),
            ),
          ],
          IconButton(
            tooltip: 'Dose log',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.log),
          ),
        ],
      ),
      body: !hasData
          ? AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'No adherence data yet',
              message: 'Add a medication with a schedule '
                  'and your stats will build up here.',
              action: VaultButton(
                label: 'Add medication',
                isFullWidth: false,
                onPressed: () => context.push(AppRoutes.newMedication),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.md,
              ),
              children: [
                _AdherenceHero(stats: stats),
                const SizedBox(height: AppSpacing.smd),
                VaultCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('This week', style: AppTextStyles.h4),
                      const SizedBox(height: AppSpacing.md),
                      RepaintBoundary(
                        child: AdherenceBarChart(days: stats.weekDaily),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.smd),
                const _HeatmapCard(),
                if (stats.perMedication.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'By medication · 30 days'),
                  for (final item in stats.perMedication) ...[
                    _MedicationAdherenceTile(item: item),
                    const SizedBox(height: AppSpacing.smd),
                  ],
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

/// Reused across rebuilds so the skeleton is parsed once, not per build.
final DateFormat _monthTitleFormat = DateFormat.yMMMM();

/// Month calendar heatmap with previous/next navigation.
final class _HeatmapCard extends ConsumerWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(heatmapMonthProvider);
    final days = ref.watch(heatmapDaysProvider);
    final offset = ref.watch(heatmapMonthOffsetProvider);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthTitleFormat.format(month),
                  style: AppTextStyles.h4,
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(heatmapMonthOffsetProvider.notifier).state--,
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: offset >= 0
                    ? null
                    : () =>
                        ref.read(heatmapMonthOffsetProvider.notifier).state++,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: RepaintBoundary(
              key: ValueKey(month),
              child: AdherenceHeatmap(
                days: days,
                today: today,
                onDayTap: (day) => showDayDosesSheet(context, day.day),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AdherenceHero extends StatelessWidget {
  const _AdherenceHero({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final rate = stats.month.rate;
    return HeroMetricCard(
      label: 'Adherence · last 30 days',
      value: Text(
        StatsScreen._percent(stats.month),
        style: AppTextStyles.hero.copyWith(color: c.textPrimary),
      ),
      deltaCaption:
          '${stats.month.taken} of ${stats.month.scheduled} doses taken',
      footer: [
        StatTile(
          label: '7-day',
          value: StatsScreen._percent(stats.week),
          dotColor: c.accent,
        ),
        StatTile(
          label: 'Streak',
          value: '${stats.streak}d',
          dotColor: c.positive,
        ),
        StatTile(
          label: 'Missed',
          value: '${stats.month.missed}',
          dotColor: (rate != null && stats.month.missed > 0)
              ? c.warning
              : c.textTertiary,
        ),
      ],
    );
  }
}

final class _MedicationAdherenceTile extends StatelessWidget {
  const _MedicationAdherenceTile({required this.item});

  final MedicationAdherence item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = item.stats.rate ?? 0;
    return VaultCard(
      onTap: () => context.push(AppRoutes.medicationDetail(item.medication.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 6,
                backgroundColor: medicationColor(item.medication.colorValue),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.medication.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(rate * 100).round()}%',
                style: AppTextStyles.number
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            value: rate,
            height: 6,
            color: medicationColor(item.medication.colorValue),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.stats.taken} taken · ${item.stats.skipped} skipped · '
            '${item.stats.missed} missed of ${item.stats.scheduled}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
