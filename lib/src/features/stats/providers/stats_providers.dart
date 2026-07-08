import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class MedicationAdherence {
  const MedicationAdherence({required this.medication, required this.stats});

  final Medication medication;
  final AdherenceStats stats;
}

/// Everything the Stats screen shows, computed in one pass.
final class StatsSnapshot {
  const StatsSnapshot({
    required this.week,
    required this.month,
    required this.streak,
    required this.weekDaily,
    required this.perMedication,
  });

  final AdherenceStats week;
  final AdherenceStats month;
  final int streak;
  final List<DayAdherence> weekDaily;
  final List<MedicationAdherence> perMedication;
}

/// Stats for the active profile only.
final statsProvider = Provider<StatsSnapshot>((ref) {
  final medications = ref.watch(activeMedicationsProvider);
  final records = ref.watch(activeRecordsProvider);
  final now = ref.watch(clockProvider)();
  final calculator = ref.watch(adherenceCalculatorProvider);

  final perMedicationStats = calculator.perMedication(
    medications: medications,
    records: records,
    now: now,
    days: 30,
  );

  return StatsSnapshot(
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
    streak: calculator.perfectDayStreak(
      medications: medications,
      records: records,
      now: now,
    ),
    weekDaily: calculator.daily(
      medications: medications,
      records: records,
      now: now,
      days: 7,
    ),
    perMedication: [
      for (final medication in medications)
        if (perMedicationStats[medication.id] case final stats?
            when stats.scheduled > 0)
          MedicationAdherence(medication: medication, stats: stats),
    ],
  );
});
