import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which month the heatmap shows: 0 = this month, -1 = last month, ...
final heatmapMonthOffsetProvider = StateProvider<int>((ref) => 0);

/// The first day of the month the heatmap currently shows.
final heatmapMonthProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  final offset = ref.watch(heatmapMonthOffsetProvider);
  return DateTime(now.year, now.month + offset);
});

/// Daily adherence (active profile) for every day of the selected month.
final heatmapDaysProvider = Provider<List<DayAdherence>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref.watch(adherenceCalculatorProvider).forMonth(
        medications: ref.watch(activeMedicationsProvider),
        records: ref.watch(activeRecordsProvider),
        month: ref.watch(heatmapMonthProvider),
        now: now,
      );
});

/// One dose on a tapped heatmap day, joined with its outcome (if any).
final class DayDoseEntry {
  const DayDoseEntry({
    required this.medication,
    required this.time,
    this.outcome,
  });

  final Medication medication;
  final DateTime time;
  final DoseOutcome? outcome;
}

/// All scheduled doses on a calendar day with their outcomes, plus any
/// as-needed doses logged that day.
final dayDosesProvider =
    Provider.family<List<DayDoseEntry>, DateTime>((ref, day) {
  final medications = ref.watch(activeMedicationsProvider);
  final records = ref.watch(activeRecordsProvider);
  final medicationsById = {for (final m in medications) m.id: m};
  final recordsByKey = {for (final r in records) r.doseKey: r};

  final scheduled = ref
      .watch(doseSchedulerProvider)
      .forDay(medications: medications, day: day);
  final scheduledKeys = {for (final d in scheduled) d.key};

  final entries = <DayDoseEntry>[
    for (final dose in scheduled)
      DayDoseEntry(
        medication: medicationsById[dose.medicationId]!,
        time: dose.time,
        outcome: recordsByKey[dose.key]?.outcome,
      ),
    // Manually logged doses (as-needed) that fall on this day.
    for (final record in records)
      if (!scheduledKeys.contains(record.doseKey) &&
          record.scheduledTime.year == day.year &&
          record.scheduledTime.month == day.month &&
          record.scheduledTime.day == day.day &&
          medicationsById[record.medicationId] != null)
        DayDoseEntry(
          medication: medicationsById[record.medicationId]!,
          time: record.scheduledTime,
          outcome: record.outcome,
        ),
  ]..sort((a, b) => a.time.compareTo(b.time));
  return entries;
});
