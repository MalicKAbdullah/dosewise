import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = AdherenceCalculator();

  final med = Medication(
    id: 'm1',
    name: 'Lisinopril',
    dosage: '10 mg',
    form: MedicationForm.tablet,
    colorValue: 0xFF3B82F6,
    startDate: DateTime(2026, 7, 1),
    schedule: const Schedule.weekly(
      times: [DoseTime(hour: 8, minute: 0)],
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
  );

  DoseRecord taken(DateTime scheduled) => DoseRecord(
        id: 'r-${scheduled.day}',
        medicationId: med.id,
        scheduledTime: scheduled,
        outcome: DoseOutcome.taken,
        recordedAt: scheduled,
      );

  group('forMonth', () {
    // Mid-month "now": July 5, 2026 at noon.
    final now = DateTime(2026, 7, 5, 12);

    test('returns one entry per calendar day of the month, in order', () {
      final days = calculator.forMonth(
        medications: [med],
        records: const [],
        month: DateTime(2026, 7),
        now: now,
      );
      expect(days, hasLength(31));
      expect(days.first.day, DateTime(2026, 7, 1));
      expect(days.last.day, DateTime(2026, 7, 31));
    });

    test('rates reflect taken ÷ scheduled per day', () {
      final days = calculator.forMonth(
        medications: [med],
        records: [
          taken(DateTime(2026, 7, 1, 8)),
          taken(DateTime(2026, 7, 3, 8)),
        ],
        month: DateTime(2026, 7),
        now: now,
      );
      expect(days[0].rate, 1.0); // Jul 1 taken.
      expect(days[1].rate, 0.0); // Jul 2 missed.
      expect(days[2].rate, 1.0); // Jul 3 taken.
    });

    test('future days have nothing scheduled (no data, not zero)', () {
      final days = calculator.forMonth(
        medications: [med],
        records: const [],
        month: DateTime(2026, 7),
        now: now,
      );
      expect(days[5].scheduled, 0); // Jul 6 is after "now".
      expect(days[5].rate, isNull);
      expect(days[30].rate, isNull);
    });

    test('days before the medication started have no data', () {
      final days = calculator.forMonth(
        medications: [med],
        records: const [],
        month: DateTime(2026, 6),
        now: now,
      );
      expect(days.every((d) => d.scheduled == 0), isTrue);
      expect(days, hasLength(30));
    });

    test('archived medications contribute nothing', () {
      final days = calculator.forMonth(
        medications: [med.copyWith(archived: true)],
        records: const [],
        month: DateTime(2026, 7),
        now: now,
      );
      expect(days.every((d) => d.scheduled == 0), isTrue);
    });

    test('today counts only doses already due', () {
      final beforeDose = DateTime(2026, 7, 5, 7, 59);
      final days = calculator.forMonth(
        medications: [med],
        records: const [],
        month: DateTime(2026, 7),
        now: beforeDose,
      );
      expect(days[4].scheduled, 0); // Today's 08:00 dose not due yet.
    });
  });

  test('dose keys stay stable so records match snoozed doses', () {
    final dose = ScheduledDose(
      medicationId: med.id,
      time: DateTime(2026, 7, 5, 8),
    );
    expect(taken(DateTime(2026, 7, 5, 8)).doseKey, dose.key);
  });
}
