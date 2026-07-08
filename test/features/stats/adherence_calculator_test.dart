import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Medication dailyMed({
  String id = 'm1',
  List<DoseTime> times = const [DoseTime(hour: 8, minute: 0)],
  DateTime? start,
}) =>
    Medication(
      id: id,
      name: 'Med $id',
      dosage: '10 mg',
      form: MedicationForm.tablet,
      colorValue: 0xFF000000,
      startDate: start ?? DateTime(2026, 1, 1),
      schedule: Schedule.weekly(times: times, weekdays: const {
        1, 2, 3, 4, 5, 6, 7, //
      }),
    );

DoseRecord record(
  String medId,
  DateTime scheduled,
  DoseOutcome outcome,
) =>
    DoseRecord(
      id: '$medId-${scheduled.toIso8601String()}',
      medicationId: medId,
      scheduledTime: scheduled,
      outcome: outcome,
      recordedAt: scheduled.add(const Duration(minutes: 5)),
    );

void main() {
  const calculator = AdherenceCalculator();
  // Noon on Wed 2026-06-10.
  final now = DateTime(2026, 6, 10, 12);

  group('period', () {
    test('counts taken over scheduled for the window', () {
      final m = dailyMed();
      final records = [
        record('m1', DateTime(2026, 6, 8, 8), DoseOutcome.taken),
        record('m1', DateTime(2026, 6, 9, 8), DoseOutcome.taken),
        record('m1', DateTime(2026, 6, 10, 8), DoseOutcome.skipped),
      ];
      final stats = calculator.period(
        medications: [m],
        records: records,
        now: now,
        days: 3,
      );
      expect(stats.scheduled, 3);
      expect(stats.taken, 2);
      expect(stats.skipped, 1);
      expect(stats.missed, 0);
      expect(stats.rate, closeTo(2 / 3, 1e-9));
    });

    test('doses later today are not counted as scheduled yet', () {
      final m = dailyMed(
        times: const [
          DoseTime(hour: 8, minute: 0),
          DoseTime(hour: 20, minute: 0),
        ],
      );
      final stats = calculator.period(
        medications: [m],
        records: [record('m1', DateTime(2026, 6, 10, 8), DoseOutcome.taken)],
        now: now, // Noon — the 20:00 dose is still in the future.
        days: 1,
      );
      expect(stats.scheduled, 1);
      expect(stats.taken, 1);
      expect(stats.rate, 1.0);
    });

    test('rate is null when nothing was scheduled', () {
      final stats = calculator.period(
        medications: const [],
        records: const [],
        now: now,
        days: 7,
      );
      expect(stats.scheduled, 0);
      expect(stats.rate, isNull);
    });

    test('unmatched (as-needed) records do not inflate adherence', () {
      final m = dailyMed();
      final stats = calculator.period(
        medications: [m],
        records: [
          // Logged at a non-scheduled time; matches no scheduled dose.
          record('m1', DateTime(2026, 6, 10, 11, 37), DoseOutcome.taken),
        ],
        now: now,
        days: 1,
      );
      expect(stats.scheduled, 1);
      expect(stats.taken, 0);
    });
  });

  group('daily', () {
    test('returns one entry per day, oldest first, today last', () {
      final m = dailyMed();
      final days = calculator.daily(
        medications: [m],
        records: [
          record('m1', DateTime(2026, 6, 9, 8), DoseOutcome.taken),
        ],
        now: now,
        days: 7,
      );
      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 6, 4));
      expect(days.last.day, DateTime(2026, 6, 10));
      expect(days[5].taken, 1); // Jun 9
      expect(days[5].isPerfect, isTrue);
      expect(days[0].taken, 0);
    });

    test('days before the medication existed have zero scheduled', () {
      final m = dailyMed(start: DateTime(2026, 6, 9));
      final days = calculator.daily(
        medications: [m],
        records: const [],
        now: now,
        days: 7,
      );
      expect(days.map((d) => d.scheduled).toList(), [0, 0, 0, 0, 0, 1, 1]);
      expect(days[0].rate, isNull);
    });
  });

  group('perMedication', () {
    test('keeps stats separate per medication', () {
      final a = dailyMed(id: 'a');
      final b = dailyMed(id: 'b');
      final result = calculator.perMedication(
        medications: [a, b],
        records: [
          record('a', DateTime(2026, 6, 9, 8), DoseOutcome.taken),
          record('a', DateTime(2026, 6, 10, 8), DoseOutcome.taken),
          record('b', DateTime(2026, 6, 9, 8), DoseOutcome.skipped),
        ],
        now: now,
        days: 2,
      );
      expect(result['a']!.taken, 2);
      expect(result['a']!.rate, 1.0);
      expect(result['b']!.taken, 0);
      expect(result['b']!.skipped, 1);
      expect(result['b']!.scheduled, 2);
    });
  });

  group('perfectDayStreak', () {
    List<DoseRecord> takenOn(List<DateTime> days) => [
          for (final day in days)
            record(
              'm1',
              DateTime(day.year, day.month, day.day, 8),
              DoseOutcome.taken,
            ),
        ];

    test('counts consecutive fully-taken days including a complete today', () {
      final m = dailyMed();
      final streak = calculator.perfectDayStreak(
        medications: [m],
        records: takenOn([
          DateTime(2026, 6, 8),
          DateTime(2026, 6, 9),
          DateTime(2026, 6, 10),
        ]),
        now: now,
      );
      expect(streak, 3);
    });

    test('an incomplete today is neutral — does not break the streak', () {
      final m = dailyMed();
      final streak = calculator.perfectDayStreak(
        medications: [m],
        records: takenOn([DateTime(2026, 6, 8), DateTime(2026, 6, 9)]),
        now: now, // Today's 08:00 dose is due but unactioned.
      );
      expect(streak, 2);
    });

    test('a missed past day breaks the streak', () {
      final m = dailyMed();
      final streak = calculator.perfectDayStreak(
        medications: [m],
        records: takenOn([
          DateTime(2026, 6, 7),
          DateTime(2026, 6, 9),
          DateTime(2026, 6, 10),
        ]), // Jun 8 missed.
        now: now,
      );
      expect(streak, 2);
    });

    test('a skipped dose breaks the streak', () {
      final m = dailyMed();
      final streak = calculator.perfectDayStreak(
        medications: [m],
        records: [
          ...takenOn([DateTime(2026, 6, 10)]),
          record('m1', DateTime(2026, 6, 9, 8), DoseOutcome.skipped),
        ],
        now: now,
      );
      expect(streak, 1);
    });

    test('days with nothing scheduled neither extend nor break the streak', () {
      // Interval med: doses on Jun 6, 8, 10 only.
      final m = Medication(
        id: 'm1',
        name: 'Med',
        dosage: '10 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF000000,
        startDate: DateTime(2026, 6, 6),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 8, minute: 0)],
          everyDays: 2,
        ),
      );
      final streak = calculator.perfectDayStreak(
        medications: [m],
        records: takenOn([
          DateTime(2026, 6, 6),
          DateTime(2026, 6, 8),
          DateTime(2026, 6, 10),
        ]),
        now: now,
      );
      expect(streak, 3); // Off days (7, 9) are skipped, not broken.
    });

    test('zero when nothing was ever scheduled', () {
      expect(
        calculator.perfectDayStreak(
          medications: const [],
          records: const [],
          now: now,
        ),
        0,
      );
    });
  });
}
