import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:dose_wise/src/features/schedule/services/snooze_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SnoozeService();
  final doseTime = DateTime(2026, 7, 3, 8, 0);
  final dose = ScheduledDose(medicationId: 'm1', time: doseTime);

  group('snooze', () {
    test('pushes the dose 15 minutes from now', () {
      final now = DateTime(2026, 7, 3, 9, 30);
      final snoozes = service.snooze({}, dose, now);
      expect(snoozes[dose.key], DateTime(2026, 7, 3, 9, 45));
    });

    test('snoozing again restarts from the new now', () {
      final first = service.snooze({}, dose, DateTime(2026, 7, 3, 9, 30));
      final second = service.snooze(first, dose, DateTime(2026, 7, 3, 9, 46));
      expect(second[dose.key], DateTime(2026, 7, 3, 10, 1));
    });

    test('prunes stale entries from earlier days while snoozing', () {
      final stale = {
        'old|2026-07-01T08:00:00.000': DateTime(2026, 7, 1, 8, 15)
      };
      final snoozes = service.snooze(stale, dose, DateTime(2026, 7, 3, 9, 30));
      expect(snoozes.keys, [dose.key]);
    });
  });

  group('effectiveTime', () {
    test('is the scheduled time without a snooze', () {
      expect(service.effectiveTime(dose, {}), doseTime);
    });

    test('is the snoozed-to time with an active snooze', () {
      final until = DateTime(2026, 7, 3, 9, 45);
      expect(service.effectiveTime(dose, {dose.key: until}), until);
    });

    test('ignores a snooze that is not after the scheduled time', () {
      final until = DateTime(2026, 7, 3, 7, 0);
      expect(service.effectiveTime(dose, {dose.key: until}), doseTime);
    });
  });

  group('isSnoozed', () {
    final until = DateTime(2026, 7, 3, 9, 45);

    test('true while the pushed-back time is still ahead', () {
      expect(
        service.isSnoozed(dose, {dose.key: until}, DateTime(2026, 7, 3, 9, 30)),
        isTrue,
      );
    });

    test('false once the snoozed time has passed', () {
      expect(
        service.isSnoozed(dose, {dose.key: until}, DateTime(2026, 7, 3, 9, 50)),
        isFalse,
      );
    });

    test('false without a snooze', () {
      expect(service.isSnoozed(dose, {}, DateTime(2026, 7, 3, 9)), isFalse);
    });
  });

  group('clear and prune', () {
    test('clear removes one dose key', () {
      final snoozes = {dose.key: DateTime(2026, 7, 3, 9, 45)};
      expect(service.clear(snoozes, dose.key), isEmpty);
    });

    test('prune keeps today, drops earlier days', () {
      final now = DateTime(2026, 7, 3, 12);
      final snoozes = {
        'a': DateTime(2026, 7, 3, 0, 5),
        'b': DateTime(2026, 7, 2, 23, 55),
      };
      expect(service.prune(snoozes, now).keys, ['a']);
    });
  });
}
