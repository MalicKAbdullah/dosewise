import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/reminders/services/notification_action_handler.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  final now = DateTime(2026, 7, 3, 8, 10);
  final doseTime = DateTime(2026, 7, 3, 8);

  Medication med({String id = 'm1', int? stock}) => Medication(
        id: id,
        name: 'Metformin',
        dosage: '500 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF14B8A6,
        startDate: DateTime(2026, 6, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
        currentStock: stock,
      );

  Future<DoseWiseRepository> seededRepo({int? stock}) async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    await repo.upsertMedication(med(stock: stock));
    return repo;
  }

  NotificationActionHandler handler(DoseWiseRepository repo) {
    var counter = 0;
    return NotificationActionHandler(
      repository: repo,
      idGenerator: () => 'record-${counter++}',
      clock: () => now,
    );
  }

  String payloadFor({String medicationId = 'm1', DateTime? time}) =>
      NotificationActionHandler.encodePayload(
        ScheduledDose(medicationId: medicationId, time: time ?? doseTime),
      );

  group('payload codec', () {
    test('round trips the dose identity', () {
      final dose = ScheduledDose(medicationId: 'm1', time: doseTime);
      final decoded = NotificationActionHandler.decodePayload(
        NotificationActionHandler.encodePayload(dose),
      );
      expect(decoded, dose);
    });

    test('malformed payloads decode to null', () {
      for (final junk in [
        null,
        '',
        'not json',
        '{}',
        '{"medicationId": 5}',
        '{"medicationId": "m1"}',
        '{"medicationId": "m1", "scheduledTime": "yesterday"}',
      ]) {
        expect(
          NotificationActionHandler.decodePayload(junk),
          isNull,
          reason: '$junk',
        );
      }
    });
  });

  test('Take persists a taken record for the exact dose occurrence', () async {
    final repo = await seededRepo();
    final outcome = await handler(repo).handle(
      actionId: NotificationActions.take,
      payload: payloadFor(),
    );

    expect(outcome, DoseOutcome.taken);
    final record = repo.data.records.single;
    expect(record.medicationId, 'm1');
    expect(record.scheduledTime, doseTime);
    expect(record.outcome, DoseOutcome.taken);
    expect(record.recordedAt, now);
    expect(record.doseKey, ScheduledDose.doseKey('m1', doseTime));
  });

  test('Take consumes tracked stock and stamps updatedAt', () async {
    final repo = await seededRepo(stock: 10);
    await handler(repo).handle(
      actionId: NotificationActions.take,
      payload: payloadFor(),
    );
    expect(repo.data.medications.single.currentStock, 9);
    expect(repo.data.medications.single.updatedAt, now);
  });

  test('Skip persists a skipped record and leaves stock alone', () async {
    final repo = await seededRepo(stock: 10);
    final outcome = await handler(repo).handle(
      actionId: NotificationActions.skip,
      payload: payloadFor(),
    );
    expect(outcome, DoseOutcome.skipped);
    expect(repo.data.records.single.outcome, DoseOutcome.skipped);
    expect(repo.data.medications.single.currentStock, 10);
  });

  test('a repeat action replaces the record for the same dose', () async {
    final repo = await seededRepo();
    final h = handler(repo);
    await h.handle(
      actionId: NotificationActions.skip,
      payload: payloadFor(),
    );
    await h.handle(
      actionId: NotificationActions.take,
      payload: payloadFor(),
    );
    expect(repo.data.records, hasLength(1));
    expect(repo.data.records.single.outcome, DoseOutcome.taken);
  });

  test('body taps and unknown actions do nothing', () async {
    final repo = await seededRepo();
    for (final actionId in [null, '', 'snooze', 'TAKE']) {
      final outcome = await handler(repo).handle(
        actionId: actionId,
        payload: payloadFor(),
      );
      expect(outcome, isNull, reason: '$actionId');
    }
    expect(repo.data.records, isEmpty);
  });

  test('malformed payload or unknown medication does nothing', () async {
    final repo = await seededRepo();
    expect(
      await handler(repo).handle(
        actionId: NotificationActions.take,
        payload: 'garbage',
      ),
      isNull,
    );
    expect(
      await handler(repo).handle(
        actionId: NotificationActions.take,
        payload: payloadFor(medicationId: 'deleted-med'),
      ),
      isNull,
    );
    expect(repo.data.records, isEmpty);
  });

  test('the write is persisted (visible to a fresh repository)', () async {
    final store = InMemoryFileStore();
    final secure = InMemorySecureStorage();
    final repo = DoseWiseRepository(
      fileStore: store,
      keyManager: DataKeyManager(secure),
    );
    await repo.initialize();
    await repo.upsertMedication(med());
    await handler(repo).handle(
      actionId: NotificationActions.take,
      payload: payloadFor(),
    );

    // Simulates the main isolate re-reading the vault after the
    // background isolate wrote it.
    final fresh = DoseWiseRepository(
      fileStore: store,
      keyManager: DataKeyManager(secure),
    );
    final data = await fresh.initialize();
    expect(data.records.single.outcome, DoseOutcome.taken);
  });
}
