import 'dart:convert';

import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoseTime', () {
    test('round trips through "HH:mm"', () {
      const time = DoseTime(hour: 7, minute: 5);
      expect(time.toJson(), '07:05');
      expect(DoseTime.fromJson('07:05'), time);
      expect(DoseTime.fromJson('23:59').minutesOfDay, 23 * 60 + 59);
    });

    test('sorts by time of day', () {
      final times = [
        const DoseTime(hour: 20, minute: 0),
        const DoseTime(hour: 8, minute: 30),
        const DoseTime(hour: 8, minute: 15),
      ]..sort();
      expect(
          times.map((t) => t.toJson()).toList(), ['08:15', '08:30', '20:00']);
    });
  });

  group('Schedule', () {
    test('weekly round trips', () {
      const schedule = Schedule.weekly(
        times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
        weekdays: {DateTime.monday, DateTime.friday},
      );
      final restored = Schedule.fromJson(
        jsonDecode(jsonEncode(schedule.toJson())) as Map<String, dynamic>,
      );
      expect(restored.type, ScheduleType.weekly);
      expect(restored.times, schedule.sortedTimes);
      expect(restored.weekdays, schedule.weekdays);
    });

    test('interval round trips', () {
      const schedule = Schedule.interval(
        times: [DoseTime(hour: 9, minute: 30)],
        everyDays: 3,
      );
      final restored = Schedule.fromJson(
        jsonDecode(jsonEncode(schedule.toJson())) as Map<String, dynamic>,
      );
      expect(restored.type, ScheduleType.interval);
      expect(restored.intervalDays, 3);
      expect(restored.times.single, const DoseTime(hour: 9, minute: 30));
    });

    test('as-needed round trips', () {
      const schedule = Schedule.asNeeded();
      final restored = Schedule.fromJson(
        jsonDecode(jsonEncode(schedule.toJson())) as Map<String, dynamic>,
      );
      expect(restored.type, ScheduleType.asNeeded);
      expect(restored.times, isEmpty);
    });
  });

  group('Medication', () {
    test('round trips with end date and notes', () {
      final medication = Medication(
        id: 'id-1',
        name: 'Metformin',
        dosage: '850 mg',
        form: MedicationForm.capsule,
        colorValue: 0xFF3B82F6,
        notes: 'After dinner',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 8, 31),
        schedule: const Schedule.interval(
          times: [DoseTime(hour: 19, minute: 0)],
          everyDays: 2,
        ),
      );
      final restored = Medication.fromJson(
        jsonDecode(jsonEncode(medication.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, medication.id);
      expect(restored.name, medication.name);
      expect(restored.dosage, medication.dosage);
      expect(restored.form, MedicationForm.capsule);
      expect(restored.colorValue, medication.colorValue);
      expect(restored.notes, medication.notes);
      expect(restored.startDate, DateTime(2026, 6, 1));
      expect(restored.endDate, DateTime(2026, 8, 31));
      expect(restored.schedule.intervalDays, 2);
    });

    test('round trips without end date', () {
      final medication = Medication(
        id: 'id-2',
        name: 'Vitamin D',
        dosage: '1000 IU',
        form: MedicationForm.other,
        colorValue: 0xFF22C55E,
        startDate: DateTime(2026, 1, 15),
        schedule: const Schedule.asNeeded(),
      );
      final restored = Medication.fromJson(
        jsonDecode(jsonEncode(medication.toJson())) as Map<String, dynamic>,
      );
      expect(restored.endDate, isNull);
      expect(restored.notes, '');
      // v1.1 fields default sensibly for v1.0 payloads.
      expect(restored.currentStock, isNull);
      expect(
        restored.lowStockThreshold,
        Medication.defaultLowStockThreshold,
      );
      expect(restored.remindersEnabled, isTrue);
      expect(restored.archived, isFalse);
    });

    test('round trips supply tracking, reminder opt-out, and archived', () {
      final medication = Medication(
        id: 'id-4',
        name: 'Metformin',
        dosage: '850 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF14B8A6,
        startDate: DateTime(2026, 6, 1),
        schedule: const Schedule.asNeeded(),
        currentStock: 12,
        lowStockThreshold: 8,
        remindersEnabled: false,
        archived: true,
      );
      final restored = Medication.fromJson(
        jsonDecode(jsonEncode(medication.toJson())) as Map<String, dynamic>,
      );
      expect(restored.currentStock, 12);
      expect(restored.lowStockThreshold, 8);
      expect(restored.remindersEnabled, isFalse);
      expect(restored.archived, isTrue);
      expect(restored.isLowStock, isFalse); // Not low: 12 > 8.
      expect(restored.copyWith(currentStock: 8).isLowStock, isTrue);
      expect(
        restored.copyWith(clearCurrentStock: true).tracksStock,
        isFalse,
      );
    });

    test('isActiveOn respects the inclusive date range', () {
      final medication = Medication(
        id: 'id-3',
        name: 'Med',
        dosage: '1',
        form: MedicationForm.tablet,
        colorValue: 0,
        startDate: DateTime(2026, 6, 2),
        endDate: DateTime(2026, 6, 4),
        schedule: const Schedule.asNeeded(),
      );
      expect(medication.isActiveOn(DateTime(2026, 6, 1)), isFalse);
      expect(medication.isActiveOn(DateTime(2026, 6, 2)), isTrue);
      expect(medication.isActiveOn(DateTime(2026, 6, 4, 23)), isTrue);
      expect(medication.isActiveOn(DateTime(2026, 6, 5)), isFalse);
    });
  });

  group('DoseRecord', () {
    test('round trips and exposes a matching dose key', () {
      final record = DoseRecord(
        id: 'r1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 6, 1, 8),
        outcome: DoseOutcome.skipped,
        recordedAt: DateTime(2026, 6, 1, 8, 45, 30),
      );
      final restored = DoseRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored.doseKey, record.doseKey);
      expect(restored.outcome, DoseOutcome.skipped);
      expect(restored.recordedAt, record.recordedAt);
    });
  });

  group('AppData', () {
    test('round trips the full envelope', () {
      final data = AppData(
        medications: [
          Medication(
            id: 'm1',
            name: 'Med',
            dosage: '1 tab',
            form: MedicationForm.tablet,
            colorValue: 1,
            startDate: DateTime(2026, 6, 1),
            schedule: const Schedule.weekly(
              times: [DoseTime(hour: 8, minute: 0)],
              weekdays: {1},
            ),
          ),
        ],
        records: [
          DoseRecord(
            id: 'r1',
            medicationId: 'm1',
            scheduledTime: DateTime(2026, 6, 1, 8),
            outcome: DoseOutcome.taken,
            recordedAt: DateTime(2026, 6, 1, 8, 1),
          ),
        ],
        settings: const AppSettings(remindersEnabled: false),
        snoozes: {'m1|2026-06-01T08:00:00.000': DateTime(2026, 6, 1, 8, 15)},
      );
      final restored = AppData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.medications, hasLength(1));
      expect(restored.records, hasLength(1));
      expect(restored.settings.remindersEnabled, isFalse);
      expect(
        restored.snoozes['m1|2026-06-01T08:00:00.000'],
        DateTime(2026, 6, 1, 8, 15),
      );
    });

    test('tolerates missing fields (forward compatibility)', () {
      final restored = AppData.fromJson(const {'version': 1});
      expect(restored.medications, isEmpty);
      expect(restored.records, isEmpty);
      expect(restored.settings.remindersEnabled, isTrue);
      expect(restored.snoozes, isEmpty);
    });
  });
}
