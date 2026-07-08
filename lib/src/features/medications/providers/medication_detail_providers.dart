import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The medication with the given id, or null once deleted.
final medicationProvider = Provider.family<Medication?, String>((ref, id) {
  final medications = ref.watch(
    appDataProvider.select(
      (data) => data.valueOrNull?.medications ?? const <Medication>[],
    ),
  );
  for (final medication in medications) {
    if (medication.id == id) return medication;
  }
  return null;
});

/// Everything the detail screen shows about one medication.
final class MedicationDetailStats {
  const MedicationDetailStats({
    required this.week,
    required this.month,
    required this.recentDaily,
    required this.recentRecords,
    required this.daysOfSupplyLeft,
  });

  final AdherenceStats week;
  final AdherenceStats month;

  /// Last 14 days for the mini bar chart, oldest first.
  final List<DayAdherence> recentDaily;

  /// Newest-first dose history, capped for display.
  final List<DoseRecord> recentRecords;

  /// Estimated days before the tracked stock runs out, if known.
  final int? daysOfSupplyLeft;
}

final medicationDetailStatsProvider =
    Provider.family<MedicationDetailStats, String>((ref, id) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  final now = ref.watch(clockProvider)();
  final calculator = ref.watch(adherenceCalculatorProvider);
  final medication = ref.watch(medicationProvider(id));

  final medications = [if (medication != null) medication];
  final records = data.records.where((r) => r.medicationId == id).toList()
    ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

  return MedicationDetailStats(
    week: calculator.period(
      medications: medications,
      records: records,
      now: now,
      days: 7,
    ),
    month: calculator.period(
      medications: medications,
      records: records,
      now: now,
      days: 30,
    ),
    recentDaily: calculator.daily(
      medications: medications,
      records: records,
      now: now,
      days: 14,
    ),
    recentRecords: records.take(10).toList(),
    daysOfSupplyLeft: medication == null
        ? null
        : ref.watch(refillServiceProvider).daysOfSupplyLeft(medication),
  );
});
