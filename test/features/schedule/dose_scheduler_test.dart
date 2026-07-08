import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:dose_wise/src/features/schedule/services/dose_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

Medication med({
  String id = 'm1',
  required Schedule schedule,
  required DateTime start,
  DateTime? end,
}) =>
    Medication(
      id: id,
      name: 'Med $id',
      dosage: '500 mg',
      form: MedicationForm.tablet,
      colorValue: 0xFF000000,
      startDate: start,
      endDate: end,
      schedule: schedule,
    );

void main() {
  const scheduler = DoseScheduler();

  // Mon 2026-06-01 .. Sun 2026-06-07 is a clean Mon-Sun week.
  final monday = DateTime(2026, 6, 1);

  List<ScheduledDose> generate(
    List<Medication> meds,
    DateTime start,
    DateTime end,
  ) =>
      scheduler.generate(medications: meds, rangeStart: start, rangeEnd: end);

  group('weekly schedules', () {
    test('generates doses at each time on each selected weekday', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
          weekdays: {DateTime.monday, DateTime.friday},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 7, 23, 59));

      expect(doses, hasLength(4)); // Mon x2, Fri x2
      expect(
        doses.map((d) => d.time),
        [
          DateTime(2026, 6, 1, 8),
          DateTime(2026, 6, 1, 20),
          DateTime(2026, 6, 5, 8),
          DateTime(2026, 6, 5, 20),
        ],
      );
    });

    test('every-day weekly schedule produces a dose every day', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 9, minute: 30)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 14, 23, 59));
      expect(doses, hasLength(14));
    });

    test('no selected weekdays yields nothing', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 9, minute: 0)],
          weekdays: {},
        ),
      );
      expect(generate([m], monday, DateTime(2026, 6, 30)), isEmpty);
    });

    test('times within a day come out sorted even if declared unsorted', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [
            DoseTime(hour: 20, minute: 0),
            DoseTime(hour: 8, minute: 0),
            DoseTime(hour: 12, minute: 15),
          ],
          weekdays: {DateTime.monday},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 1, 23, 59));
      expect(
        doses.map((d) => d.time.hour).toList(),
        [8, 12, 20],
      );
    });
  });

  group('range boundaries', () {
    final m = med(
      start: DateTime(2026, 1, 1),
      schedule: const Schedule.weekly(
        times: [DoseTime(hour: 8, minute: 0)],
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
    );

    test('dose exactly at rangeStart is included', () {
      final doses =
          generate([m], DateTime(2026, 6, 1, 8), DateTime(2026, 6, 1, 9));
      expect(doses, hasLength(1));
    });

    test('dose exactly at rangeEnd is included', () {
      final doses =
          generate([m], DateTime(2026, 6, 1, 7), DateTime(2026, 6, 1, 8));
      expect(doses, hasLength(1));
    });

    test('dose just outside the range is excluded', () {
      final before =
          generate([m], DateTime(2026, 6, 1, 8, 1), DateTime(2026, 6, 1, 23));
      final after =
          generate([m], DateTime(2026, 6, 1), DateTime(2026, 6, 1, 7, 59));
      expect(before, isEmpty);
      expect(after, isEmpty);
    });

    test('inverted range yields nothing', () {
      expect(
          generate([m], DateTime(2026, 6, 2), DateTime(2026, 6, 1)), isEmpty);
    });

    test('range spanning a month boundary works', () {
      final doses =
          generate([m], DateTime(2026, 6, 29), DateTime(2026, 7, 2, 23, 59));
      expect(doses, hasLength(4)); // Jun 29, 30, Jul 1, 2
    });
  });

  group('active date range', () {
    test('medication added mid-period produces no doses before startDate', () {
      final m = med(
        start: DateTime(2026, 6, 4),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 7, 23, 59));
      expect(doses.map((d) => d.time.day).toList(), [4, 5, 6, 7]);
    });

    test('end date is inclusive; nothing after it', () {
      final m = med(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 3),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 30));
      expect(doses.map((d) => d.time.day).toList(), [1, 2, 3]);
    });

    test('start date time-of-day is ignored (date granularity)', () {
      // Started at 22:00 on June 1 — the 08:00 dose on June 1 still counts.
      final m = med(
        start: DateTime(2026, 6, 1, 22),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 1, 23, 59));
      expect(doses, hasLength(1));
    });

    test('medication fully outside the range yields nothing', () {
      final m = med(
        start: DateTime(2026, 7, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      expect(generate([m], monday, DateTime(2026, 6, 7)), isEmpty);
    });
  });

  group('interval schedules', () {
    test('every 3 days anchored to the start date', () {
      final m = med(
        start: DateTime(2026, 6, 1),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 9, minute: 0)],
          everyDays: 3,
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 10, 23, 59));
      expect(doses.map((d) => d.time.day).toList(), [1, 4, 7, 10]);
    });

    test('anchor holds when the range starts after the start date', () {
      final m = med(
        start: DateTime(2026, 6, 1),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 9, minute: 0)],
          everyDays: 3,
        ),
      );
      // Range Jun 5-10: only anchored days 7 and 10 qualify — not Jun 5.
      final doses =
          generate([m], DateTime(2026, 6, 5), DateTime(2026, 6, 10, 23, 59));
      expect(doses.map((d) => d.time.day).toList(), [7, 10]);
    });

    test('interval of 1 behaves like daily', () {
      final m = med(
        start: DateTime(2026, 6, 1),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 9, minute: 0)],
          everyDays: 1,
        ),
      );
      expect(
        generate([m], monday, DateTime(2026, 6, 7, 23, 59)),
        hasLength(7),
      );
    });

    test('interval anchored across a month boundary', () {
      final m = med(
        start: DateTime(2026, 5, 30),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 9, minute: 0)],
          everyDays: 5,
        ),
      );
      // May 30 → Jun 4 → Jun 9.
      final doses = generate([m], monday, DateTime(2026, 6, 10, 23, 59));
      expect(doses.map((d) => d.time.day).toList(), [4, 9]);
    });

    test('multiple times per interval day', () {
      final m = med(
        start: DateTime(2026, 6, 1),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
          everyDays: 2,
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 5, 23, 59));
      expect(doses, hasLength(6)); // Jun 1, 3, 5 x2
    });
  });

  group('as-needed and empty input', () {
    test('as-needed medications never produce scheduled doses', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.asNeeded(),
      );
      expect(generate([m], monday, DateTime(2026, 12, 31)), isEmpty);
    });

    test('no medications yields nothing', () {
      expect(generate([], monday, DateTime(2026, 6, 30)), isEmpty);
    });
  });

  group('combination and ordering', () {
    test('doses across medications are sorted by time then id', () {
      final a = med(
        id: 'a',
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final b = med(
        id: 'b',
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 7, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([b, a], monday, DateTime(2026, 6, 1, 23, 59));
      expect(
        doses.map((d) => '${d.medicationId}@${d.time.hour}').toList(),
        ['b@7', 'a@8', 'b@8'],
      );
    });

    test('dose keys are unique and stable', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = generate([m], monday, DateTime(2026, 6, 7, 23, 59));
      expect(doses.map((d) => d.key).toSet(), hasLength(doses.length));
      expect(
        doses.first.key,
        ScheduledDose.doseKey('m1', DateTime(2026, 6, 1, 8)),
      );
    });
  });

  group('forDay', () {
    test('returns exactly the doses of that calendar day', () {
      final m = med(
        start: DateTime(2026, 1, 1),
        schedule: const Schedule.weekly(
          times: [
            DoseTime(hour: 0, minute: 0),
            DoseTime(hour: 23, minute: 59),
          ],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final doses = scheduler.forDay(
        medications: [m],
        day: DateTime(2026, 6, 3, 15, 30),
      );
      expect(doses, hasLength(2));
      expect(doses.first.time, DateTime(2026, 6, 3));
      expect(doses.last.time, DateTime(2026, 6, 3, 23, 59));
    });
  });
}
