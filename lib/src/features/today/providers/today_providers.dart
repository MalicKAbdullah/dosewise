import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DoseState { upcoming, due, late, taken, skipped }

/// A dose on today's timeline joined with its medication and any record.
final class TodayDose {
  const TodayDose({
    required this.dose,
    required this.medication,
    required this.state,
    required this.displayTime,
    this.isSnoozed = false,
    this.record,
  });

  final ScheduledDose dose;
  final Medication medication;
  final DoseState state;

  /// Where the dose sits on the timeline: the scheduled time, or the
  /// snoozed-to time while a snooze is active.
  final DateTime displayTime;

  /// Whether an active snooze pushed this dose back.
  final bool isSnoozed;
  final DoseRecord? record;

  bool get isActioned => state == DoseState.taken || state == DoseState.skipped;

  /// Snoozing makes sense while the dose is awaiting action around its
  /// due time.
  bool get canSnooze =>
      !isActioned && (state == DoseState.due || state == DoseState.late);
}

/// A dose becomes "due" this long before its scheduled time...
const Duration dueWindowBefore = Duration(minutes: 30);

/// ...and "late" this long after it.
const Duration lateAfter = Duration(hours: 1);

DoseState _stateFor(DateTime doseTime, DoseRecord? record, DateTime now) {
  if (record != null) {
    return record.outcome == DoseOutcome.taken
        ? DoseState.taken
        : DoseState.skipped;
  }
  if (now.isBefore(doseTime.subtract(dueWindowBefore))) {
    return DoseState.upcoming;
  }
  if (now.isAfter(doseTime.add(lateAfter))) return DoseState.late;
  return DoseState.due;
}

/// Bumped once a minute by the Today screen's ticker so due/late states
/// stay fresh without any interaction (the timer lives in the widget
/// layer so it is cancelled with the screen).
final todayTickProvider = StateProvider<int>((ref) => 0);

/// Today's doses for the active profile in chronological (display-time)
/// order.
final todayDosesProvider = Provider<List<TodayDose>>((ref) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  ref.watch(todayTickProvider); // Recompute states as time passes.
  final now = ref.watch(clockProvider)();
  final snoozeService = ref.watch(snoozeServiceProvider);
  final medications = ref.watch(activeMedicationsProvider);
  final medicationsById = {for (final m in medications) m.id: m};
  final recordsByKey = {
    for (final r in ref.watch(activeRecordsProvider)) r.doseKey: r,
  };

  final doses = ref
      .watch(doseSchedulerProvider)
      .forDay(medications: medications, day: now)
      .map((dose) {
    final record = recordsByKey[dose.key];
    final displayTime = snoozeService.effectiveTime(dose, data.snoozes);
    return TodayDose(
      dose: dose,
      medication: medicationsById[dose.medicationId]!,
      record: record,
      displayTime: displayTime,
      isSnoozed:
          record == null && snoozeService.isSnoozed(dose, data.snoozes, now),
      state: _stateFor(displayTime, record, now),
    );
  }).toList()
    ..sort((a, b) {
      final byTime = a.displayTime.compareTo(b.displayTime);
      return byTime != 0 ? byTime : a.dose.compareTo(b.dose);
    });
  return doses;
});

/// As-needed medications active today (logged manually, not scheduled).
final asNeededMedicationsProvider = Provider<List<Medication>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(activeMedicationsProvider)
      .where(
        (m) =>
            m.schedule.type == ScheduleType.asNeeded &&
            !m.archived &&
            m.isActiveOn(now),
      )
      .toList();
});

/// (taken, total) for today's progress ring.
final todayProgressProvider = Provider<(int, int)>((ref) {
  final doses = ref.watch(todayDosesProvider);
  final taken = doses.where((d) => d.state == DoseState.taken).length;
  return (taken, doses.length);
});

/// Medications running low on tracked stock (for the Today banner).
final lowStockMedicationsProvider = Provider<List<Medication>>((ref) {
  return ref
      .watch(activeMedicationsProvider)
      .where((m) => !m.archived && m.isLowStock)
      .toList();
});
