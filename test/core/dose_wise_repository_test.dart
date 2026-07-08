import 'dart:convert';

import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

Medication sampleMed({String id = 'm1', String name = 'Ibuprofen'}) =>
    Medication(
      id: id,
      name: name,
      dosage: '400 mg',
      form: MedicationForm.tablet,
      colorValue: 0xFFEF4444,
      notes: 'With food',
      startDate: DateTime(2026, 6, 1),
      schedule: const Schedule.weekly(
        times: [DoseTime(hour: 8, minute: 0)],
        weekdays: {1, 3, 5},
      ),
    );

DoseRecord sampleRecord({String medId = 'm1'}) => DoseRecord(
      id: 'r1',
      medicationId: medId,
      scheduledTime: DateTime(2026, 6, 1, 8),
      outcome: DoseOutcome.taken,
      recordedAt: DateTime(2026, 6, 1, 8, 12),
    );

void main() {
  late InMemoryFileStore fileStore;
  late InMemorySecureStorage secureStorage;

  DoseWiseRepository makeRepo() => DoseWiseRepository(
        fileStore: fileStore,
        keyManager: DataKeyManager(secureStorage),
      );

  setUp(() {
    fileStore = InMemoryFileStore();
    secureStorage = InMemorySecureStorage();
  });

  test('first launch: empty data, key generated into secure storage', () async {
    final repo = makeRepo();
    final data = await repo.initialize();

    expect(data.medications, isEmpty);
    expect(data.records, isEmpty);
    expect(fileStore.bytes, isNull); // Nothing written until a mutation.

    final storedKey = secureStorage.values[DataKeyManager.storageKey];
    expect(storedKey, isNotNull);
    expect(base64Decode(storedKey!), hasLength(32)); // 256-bit key.
  });

  test('encrypt-write / load-decrypt round trip across instances', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed());
    await repo.saveRecord(sampleRecord());
    await repo.updateSettings(const AppSettings(remindersEnabled: false));

    // Fresh repository over the same stores (simulates app restart).
    final reloaded = makeRepo();
    final data = await reloaded.initialize();

    expect(data.medications, hasLength(1));
    final med = data.medications.single;
    expect(med.name, 'Ibuprofen');
    expect(med.schedule.type, ScheduleType.weekly);
    expect(med.schedule.weekdays, {1, 3, 5});
    expect(data.records.single.outcome, DoseOutcome.taken);
    expect(data.settings.remindersEnabled, isFalse);
  });

  test('vault file on disk is ciphertext, not plaintext JSON', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed(name: 'SecretDrugName'));

    final raw = String.fromCharCodes(fileStore.bytes!);
    expect(raw.contains('SecretDrugName'), isFalse);
    expect(raw.contains('medications'), isFalse);
  });

  test('decryption fails with a different key', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed());

    // Simulate a key that no longer matches the file.
    secureStorage.values[DataKeyManager.storageKey] =
        base64Encode(List<int>.filled(32, 7));

    final reloaded = makeRepo();
    await expectLater(reloaded.initialize(), throwsA(anything));
  });

  test('saveRecord replaces an existing record for the same dose', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.saveRecord(sampleRecord());

    final updated = DoseRecord(
      id: 'r2',
      medicationId: 'm1',
      scheduledTime: DateTime(2026, 6, 1, 8),
      outcome: DoseOutcome.skipped,
      recordedAt: DateTime(2026, 6, 1, 9),
    );
    final data = await repo.saveRecord(updated);

    expect(data.records, hasLength(1));
    expect(data.records.single.outcome, DoseOutcome.skipped);
  });

  test('deleteRecord removes the record (undo)', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.saveRecord(sampleRecord());
    final data = await repo.deleteRecord(sampleRecord().doseKey);
    expect(data.records, isEmpty);
  });

  test('deleteMedication cascades its records', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed());
    await repo.upsertMedication(sampleMed(id: 'm2', name: 'Aspirin'));
    await repo.saveRecord(sampleRecord());
    await repo.saveRecord(DoseRecord(
      id: 'r9',
      medicationId: 'm2',
      scheduledTime: DateTime(2026, 6, 2, 8),
      outcome: DoseOutcome.taken,
      recordedAt: DateTime(2026, 6, 2, 8),
    ));

    final data = await repo.deleteMedication('m1');
    expect(data.medications.map((m) => m.id), ['m2']);
    expect(data.records.map((r) => r.medicationId), ['m2']);
  });

  test('upsertMedication updates in place and keeps the list sorted', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed(id: 'a', name: 'Zinc'));
    await repo.upsertMedication(sampleMed(id: 'b', name: 'Aspirin'));
    final data =
        await repo.upsertMedication(sampleMed(id: 'a', name: 'Amoxicillin'));

    expect(data.medications.map((m) => m.name), ['Amoxicillin', 'Aspirin']);
  });

  test('mutation before initialize throws', () async {
    final repo = makeRepo();
    await expectLater(
      repo.upsertMedication(sampleMed()),
      throwsA(isA<StateError>()),
    );
  });

  test('eraseAll wipes file, key, and cache', () async {
    final repo = makeRepo();
    await repo.initialize();
    await repo.upsertMedication(sampleMed());
    expect(fileStore.bytes, isNotNull);

    final data = await repo.eraseAll();

    expect(data.medications, isEmpty);
    expect(fileStore.bytes, isNull);
    expect(
        secureStorage.values.containsKey(DataKeyManager.storageKey), isFalse);

    // Re-initialize starts a fresh vault with a fresh key.
    final fresh = await repo.initialize();
    expect(fresh.medications, isEmpty);
    expect(secureStorage.values[DataKeyManager.storageKey], isNotNull);
  });
}
