import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class LogEntry {
  const LogEntry({required this.record, required this.medication});

  final DoseRecord record;

  /// Null when the medication was deleted after the record was made.
  final Medication? medication;
}

final class LogDay {
  const LogDay({required this.day, required this.entries});

  final DateTime day;
  final List<LogEntry> entries;
}

/// Dose history for the active profile grouped by day, newest day (and
/// newest dose) first.
final doseLogProvider = Provider<List<LogDay>>((ref) {
  final medicationsById = {
    for (final m in ref.watch(activeMedicationsProvider)) m.id: m,
  };

  final byDay = <DateTime, List<LogEntry>>{};
  for (final record in ref.watch(activeRecordsProvider)) {
    final t = record.scheduledTime;
    final day = DateTime(t.year, t.month, t.day);
    byDay.putIfAbsent(day, () => []).add(
          LogEntry(
            record: record,
            medication: medicationsById[record.medicationId],
          ),
        );
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      LogDay(
        day: day,
        entries: byDay[day]!
          ..sort(
            (a, b) => b.record.scheduledTime.compareTo(a.record.scheduledTime),
          ),
      ),
  ];
});
