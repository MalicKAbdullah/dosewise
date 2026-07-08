import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';

/// Pure-Dart schedule engine. Expands medication schedules into the
/// concrete [ScheduledDose] occurrences that fall inside a time range.
///
/// Rules:
/// - A dose is included when `rangeStart <= dose.time <= rangeEnd`.
/// - A medication only produces doses on days inside its active range
///   (`startDate`..`endDate`, both inclusive, date granularity).
/// - Interval schedules are anchored to the medication start date: doses
///   fall on start date, start date + N days, start date + 2N days, ...
/// - As-needed medications never produce scheduled doses.
/// - Archived medications never produce scheduled doses.
final class DoseScheduler {
  const DoseScheduler();

  /// All doses for [medications] within `[rangeStart, rangeEnd]`
  /// (inclusive), sorted by time, then medication id.
  List<ScheduledDose> generate({
    required List<Medication> medications,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (rangeEnd.isBefore(rangeStart)) return const [];

    final doses = <ScheduledDose>[];
    final firstDay = _dateOnly(rangeStart);
    final lastDay = _dateOnly(rangeEnd);

    for (final medication in medications) {
      if (medication.archived) continue;
      var day = firstDay;
      while (!day.isAfter(lastDay)) {
        if (medication.isActiveOn(day) &&
            medication.schedule.occursOn(day, medication.startDate)) {
          for (final time in medication.schedule.sortedTimes) {
            final doseTime = time.onDay(day);
            if (!doseTime.isBefore(rangeStart) && !doseTime.isAfter(rangeEnd)) {
              doses.add(
                ScheduledDose(medicationId: medication.id, time: doseTime),
              );
            }
          }
        }
        // Construct the next calendar day explicitly; adding a Duration to
        // a local DateTime drifts across DST transitions.
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }

    return doses..sort();
  }

  /// All doses scheduled on the calendar day containing [day].
  List<ScheduledDose> forDay({
    required List<Medication> medications,
    required DateTime day,
  }) {
    final start = _dateOnly(day);
    return generate(
      medications: medications,
      rangeStart: start,
      rangeEnd: start.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      ),
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
