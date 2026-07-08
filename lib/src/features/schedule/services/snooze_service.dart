import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';

/// Pure-Dart snooze logic. A snooze pushes one dose occurrence's display
/// time (and its reminder) back without touching the medication schedule.
///
/// Snoozes are keyed by the dose's stable [ScheduledDose.key], so records,
/// adherence math, and undo all keep working against the original time.
final class SnoozeService {
  const SnoozeService({this.snoozeDuration = const Duration(minutes: 15)});

  final Duration snoozeDuration;

  /// The time the dose should surface at: the snoozed-to time when one is
  /// set and still in the future of the original time, otherwise the
  /// original scheduled time.
  DateTime effectiveTime(
    ScheduledDose dose,
    Map<String, DateTime> snoozes,
  ) {
    final until = snoozes[dose.key];
    if (until == null || !until.isAfter(dose.time)) return dose.time;
    return until;
  }

  /// Whether the dose is currently snoozed (its pushed-back time is still
  /// ahead of [now]).
  bool isSnoozed(
    ScheduledDose dose,
    Map<String, DateTime> snoozes,
    DateTime now,
  ) {
    final until = snoozes[dose.key];
    return until != null && until.isAfter(dose.time) && until.isAfter(now);
  }

  /// Returns a new snooze map with [dose] pushed back [snoozeDuration]
  /// from [now]. Repeated snoozes stack (each starts from now again).
  Map<String, DateTime> snooze(
    Map<String, DateTime> snoozes,
    ScheduledDose dose,
    DateTime now,
  ) =>
      {...prune(snoozes, now), dose.key: now.add(snoozeDuration)};

  /// Removes the snooze for [doseKey] (e.g. once the dose is actioned).
  Map<String, DateTime> clear(
    Map<String, DateTime> snoozes,
    String doseKey,
  ) =>
      {...snoozes}..remove(doseKey);

  /// Drops snoozes from before today so the persisted map stays tiny.
  Map<String, DateTime> prune(
    Map<String, DateTime> snoozes,
    DateTime now,
  ) {
    final startOfDay = DateTime(now.year, now.month, now.day);
    return {
      for (final entry in snoozes.entries)
        if (!entry.value.isBefore(startOfDay)) entry.key: entry.value,
    };
  }
}
