import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/schedule/services/dose_scheduler.dart';

/// Aggregate adherence over a window: how many doses were scheduled (and
/// already due) versus taken/skipped.
final class AdherenceStats {
  const AdherenceStats({
    required this.scheduled,
    required this.taken,
    required this.skipped,
  });

  static const AdherenceStats empty =
      AdherenceStats(scheduled: 0, taken: 0, skipped: 0);

  final int scheduled;
  final int taken;
  final int skipped;

  int get missed => scheduled - taken - skipped;

  /// taken ÷ scheduled, or null when nothing was scheduled.
  double? get rate => scheduled == 0 ? null : taken / scheduled;
}

/// Adherence for a single calendar day.
final class DayAdherence {
  const DayAdherence({
    required this.day,
    required this.scheduled,
    required this.taken,
  });

  final DateTime day;
  final int scheduled;
  final int taken;

  double? get rate => scheduled == 0 ? null : taken / scheduled;

  bool get isPerfect => scheduled > 0 && taken == scheduled;
}

/// Pure-Dart adherence math over medications and dose records.
///
/// Only doses that are already due (`time <= now`) count as "scheduled",
/// so a dose later today never lowers today's adherence in advance.
final class AdherenceCalculator {
  const AdherenceCalculator({this.scheduler = const DoseScheduler()});

  final DoseScheduler scheduler;

  /// Adherence over the last [days] calendar days, ending at [now]
  /// (inclusive of today so far).
  AdherenceStats period({
    required List<Medication> medications,
    required List<DoseRecord> records,
    required DateTime now,
    required int days,
  }) {
    var scheduled = 0;
    var taken = 0;
    var skipped = 0;
    for (final day in daily(
      medications: medications,
      records: records,
      now: now,
      days: days,
    )) {
      scheduled += day.scheduled;
      taken += day.taken;
    }
    final outcomes = _outcomesByKey(records);
    for (final dose in _dueDoses(medications, now, days)) {
      if (outcomes[dose] == DoseOutcome.skipped) skipped++;
    }
    return AdherenceStats(scheduled: scheduled, taken: taken, skipped: skipped);
  }

  /// One entry per day for the last [days] days, oldest first. The last
  /// entry is today, counting only doses due so far.
  List<DayAdherence> daily({
    required List<Medication> medications,
    required List<DoseRecord> records,
    required DateTime now,
    required int days,
  }) {
    final outcomes = _outcomesByKey(records);
    final today = DateTime(now.year, now.month, now.day);
    final result = <DayAdherence>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final doses = scheduler
          .forDay(medications: medications, day: day)
          .where((d) => !d.time.isAfter(now))
          .toList();
      final taken =
          doses.where((d) => outcomes[d.key] == DoseOutcome.taken).length;
      result.add(
        DayAdherence(day: day, scheduled: doses.length, taken: taken),
      );
    }
    return result;
  }

  /// One [DayAdherence] per calendar day of the month containing [month],
  /// in day order. Days after [now] have nothing due yet, so they come
  /// back with `scheduled == 0` (rendered as "no data" in the heatmap).
  List<DayAdherence> forMonth({
    required List<Medication> medications,
    required List<DoseRecord> records,
    required DateTime month,
    required DateTime now,
  }) {
    final outcomes = _outcomesByKey(records);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final result = <DayAdherence>[];
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final doses = scheduler
          .forDay(medications: medications, day: day)
          .where((dose) => !dose.time.isAfter(now))
          .toList();
      final taken =
          doses.where((d) => outcomes[d.key] == DoseOutcome.taken).length;
      result.add(
        DayAdherence(day: day, scheduled: doses.length, taken: taken),
      );
    }
    return result;
  }

  /// Adherence per medication id over the last [days] days.
  Map<String, AdherenceStats> perMedication({
    required List<Medication> medications,
    required List<DoseRecord> records,
    required DateTime now,
    required int days,
  }) {
    final outcomes = _outcomesByKey(records);
    final counters = <String, List<int>>{
      for (final m in medications) m.id: [0, 0, 0],
    };
    for (final medication in medications) {
      for (final dose
          in _dueDoses([medication], now, days).map((k) => outcomes[k])) {
        final counter = counters[medication.id]!;
        counter[0]++;
        if (dose == DoseOutcome.taken) counter[1]++;
        if (dose == DoseOutcome.skipped) counter[2]++;
      }
    }
    return counters.map(
      (id, c) => MapEntry(
        id,
        AdherenceStats(scheduled: c[0], taken: c[1], skipped: c[2]),
      ),
    );
  }

  /// Number of consecutive "perfect" days (every due dose taken) ending
  /// today or yesterday.
  ///
  /// - Days with nothing scheduled neither extend nor break the streak.
  /// - Today extends the streak when every dose due so far is taken; an
  ///   incomplete today does not break it (the user can still catch up).
  int perfectDayStreak({
    required List<Medication> medications,
    required List<DoseRecord> records,
    required DateTime now,
    int maxLookbackDays = 365,
  }) {
    final outcomes = _outcomesByKey(records);
    var streak = 0;
    for (var i = 0; i < maxLookbackDays; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final doses = scheduler
          .forDay(medications: medications, day: day)
          .where((d) => !d.time.isAfter(now))
          .toList();
      if (doses.isEmpty) continue;
      final allTaken = doses.every((d) => outcomes[d.key] == DoseOutcome.taken);
      if (allTaken) {
        streak++;
      } else if (i == 0) {
        continue; // Today is still in progress — neutral, keep looking back.
      } else {
        break;
      }
    }
    return streak;
  }

  /// Dose keys due within the last [days] days ending at [now].
  Iterable<String> _dueDoses(
    List<Medication> medications,
    DateTime now,
    int days,
  ) {
    final start = DateTime(now.year, now.month, now.day - (days - 1));
    return scheduler
        .generate(medications: medications, rangeStart: start, rangeEnd: now)
        .map((d) => d.key);
  }

  static Map<String, DoseOutcome> _outcomesByKey(List<DoseRecord> records) =>
      {for (final r in records) r.doseKey: r.outcome};
}
