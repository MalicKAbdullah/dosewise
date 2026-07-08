import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/stats/services/report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = AdherenceReportBuilder();

  Medication med(String id, String name) => Medication(
        id: id,
        name: name,
        dosage: '500 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF14B8A6,
        startDate: DateTime(2026, 7, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );

  DoseRecord record(
    String medicationId,
    DateTime scheduled, {
    DoseOutcome outcome = DoseOutcome.taken,
  }) =>
      DoseRecord(
        id: 'r-$medicationId-${scheduled.day}-${scheduled.hour}',
        medicationId: medicationId,
        scheduledTime: scheduled,
        outcome: outcome,
        recordedAt: scheduled,
      );

  // July 5, 2026 at noon: five days of history (Jul 1–5).
  final now = DateTime(2026, 7, 5, 12);

  test('summarizes the period, overall rate, and per-medication lines', () {
    final metformin = med('m1', 'Metformin');
    final report = builder.build(
      medications: [metformin],
      records: [
        record('m1', DateTime(2026, 7, 1, 8)),
        record('m1', DateTime(2026, 7, 2, 8)),
        record('m1', DateTime(2026, 7, 3, 8), outcome: DoseOutcome.skipped),
        record('m1', DateTime(2026, 7, 4, 8)),
        // Jul 5 dose missed (due, no record).
      ],
      now: now,
    );

    expect(report, contains('30-day adherence report'));
    expect(report, contains('Jun 6, 2026 to Jul 5, 2026'));
    // 3 taken of 5 due = 60%.
    expect(report, contains('Overall: 60% (3 of 5 doses taken)'));
    expect(report, contains('Skipped: 1 · Missed: 1'));
    expect(
      report,
      contains('- Metformin (500 mg): 60% — 3/5 taken, 1 skipped, 1 missed'),
    );
    expect(report, contains('Data stays on the device.'));
  });

  test('medications with nothing scheduled are omitted', () {
    final report = builder.build(
      medications: [
        med('m1', 'Metformin'),
        med('m2', 'FutureMed').copyWith(startDate: DateTime(2027, 1, 1)),
      ],
      records: [record('m1', DateTime(2026, 7, 4, 8))],
      now: now,
    );
    expect(report, contains('Metformin'));
    expect(report, isNot(contains('FutureMed')));
  });

  test('handles an empty vault gracefully', () {
    final report = builder.build(medications: [], records: [], now: now);
    expect(report, contains('Overall: n/a'));
  });
}
