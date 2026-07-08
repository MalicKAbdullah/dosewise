import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/services/refill_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = RefillService();

  Medication med({
    int? stock,
    int threshold = 5,
    Schedule schedule = const Schedule.weekly(
      times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
  }) =>
      Medication(
        id: 'm1',
        name: 'Metformin',
        dosage: '500 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF14B8A6,
        startDate: DateTime(2026, 6, 1),
        schedule: schedule,
        currentStock: stock,
        lowStockThreshold: threshold,
      );

  group('consumeDose', () {
    test('decrements tracked stock by one', () {
      expect(service.consumeDose(med(stock: 10))!.currentStock, 9);
    });

    test('returns null when tracking is off', () {
      expect(service.consumeDose(med()), isNull);
    });

    test('never goes below zero', () {
      expect(service.consumeDose(med(stock: 0)), isNull);
    });
  });

  group('returnDose', () {
    test('restores one unit on undo', () {
      expect(service.returnDose(med(stock: 9))!.currentStock, 10);
    });

    test('returns null when tracking is off', () {
      expect(service.returnDose(med()), isNull);
    });
  });

  group('refill', () {
    test('adds units to existing stock', () {
      expect(service.refill(med(stock: 3), 30).currentStock, 33);
    });

    test('starts tracking from zero when tracking was off', () {
      expect(service.refill(med(), 30).currentStock, 30);
    });
  });

  group('isLowStock', () {
    test('true at or below the threshold, false above', () {
      expect(med(stock: 5).isLowStock, isTrue);
      expect(med(stock: 3).isLowStock, isTrue);
      expect(med(stock: 6).isLowStock, isFalse);
      expect(med().isLowStock, isFalse); // Tracking off.
    });
  });

  group('daysOfSupplyLeft', () {
    test('daily twice-a-day schedule: 10 doses last 5 days', () {
      expect(service.daysOfSupplyLeft(med(stock: 10)), 5);
    });

    test('weekly subset: 7 doses at 1/day on Mon+Thu lasts ~24 days', () {
      final m = med(
        stock: 7,
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {DateTime.monday, DateTime.thursday},
        ),
      );
      // 2 doses per week => 2/7 per day => 7 ÷ (2/7) = 24.5 -> 24.
      expect(service.daysOfSupplyLeft(m), 24);
    });

    test('interval schedule anchors to interval days', () {
      final m = med(
        stock: 4,
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 9, minute: 0)],
          everyDays: 3,
        ),
      );
      expect(service.daysOfSupplyLeft(m), 12);
    });

    test('null for as-needed or untracked medications', () {
      expect(
        service.daysOfSupplyLeft(
          med(stock: 10, schedule: const Schedule.asNeeded()),
        ),
        isNull,
      );
      expect(service.daysOfSupplyLeft(med()), isNull);
    });
  });
}
