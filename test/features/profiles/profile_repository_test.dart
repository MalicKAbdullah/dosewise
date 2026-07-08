import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

Medication med(String id, String profileId) => Medication(
      id: id,
      name: 'Med $id',
      dosage: '1 tablet',
      form: MedicationForm.tablet,
      colorValue: 0xFF6366F1,
      startDate: DateTime(2026, 6, 1),
      schedule: const Schedule.weekly(
        times: [DoseTime(hour: 8, minute: 0)],
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
      profileId: profileId,
    );

DoseRecord rec(String id, String medicationId, String profileId) => DoseRecord(
      id: id,
      medicationId: medicationId,
      scheduledTime: DateTime(2026, 7, 1, 8),
      outcome: DoseOutcome.taken,
      recordedAt: DateTime(2026, 7, 1, 8, 5),
      profileId: profileId,
    );

void main() {
  late DoseWiseRepository repo;

  const amma = Profile(id: 'p-amma', name: 'Amma', colorValue: 0xFFF59E0B);

  setUp(() async {
    repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
  });

  test('saveProfile adds and updates by id', () async {
    await repo.saveProfile(amma);
    expect(repo.data.profiles.map((p) => p.name), ['Me', 'Amma']);

    await repo.saveProfile(amma.copyWith(name: 'Ammi'));
    expect(repo.data.profiles.map((p) => p.name), ['Me', 'Ammi']);
    expect(repo.data.profiles, hasLength(2));
  });

  test('setActiveProfile switches; unknown ids are ignored', () async {
    await repo.saveProfile(amma);
    await repo.setActiveProfile(amma.id);
    expect(repo.data.activeProfileId, amma.id);

    await repo.setActiveProfile('ghost');
    expect(repo.data.activeProfileId, amma.id);
  });

  test('deleteProfile cascades medications, records, and snoozes', () async {
    await repo.saveProfile(amma);
    await repo.upsertMedication(med('mine', Profile.defaultId));
    await repo.upsertMedication(med('hers', amma.id));
    await repo.saveRecord(rec('r-mine', 'mine', Profile.defaultId));
    await repo.saveRecord(rec('r-hers', 'hers', amma.id));
    await repo.updateSnoozes({
      'mine|2026-07-02T08:00:00.000': DateTime(2026, 7, 2, 8, 15),
      'hers|2026-07-02T08:00:00.000': DateTime(2026, 7, 2, 8, 15),
    });

    await repo.deleteProfile(amma.id);

    expect(repo.data.profiles.map((p) => p.id), [Profile.defaultId]);
    expect(repo.data.medications.map((m) => m.id), ['mine']);
    expect(repo.data.records.map((r) => r.id), ['r-mine']);
    expect(repo.data.snoozes.keys, ['mine|2026-07-02T08:00:00.000']);
  });

  test('deleting the active profile activates the first remaining one',
      () async {
    await repo.saveProfile(amma);
    await repo.setActiveProfile(amma.id);
    await repo.deleteProfile(amma.id);
    expect(repo.data.activeProfileId, Profile.defaultId);
  });

  test('the last profile cannot be deleted', () async {
    final before = repo.data;
    await repo.deleteProfile(Profile.defaultId);
    expect(repo.data.profiles, hasLength(1));
    expect(repo.data.activeProfileId, before.activeProfileId);
  });

  test('profiles survive a save/load round trip', () async {
    final store = InMemoryFileStore();
    final secure = InMemorySecureStorage();
    final first = DoseWiseRepository(
      fileStore: store,
      keyManager: DataKeyManager(secure),
    );
    await first.initialize();
    await first.saveProfile(amma);
    await first.setActiveProfile(amma.id);
    await first.upsertMedication(med('hers', amma.id));

    final second = DoseWiseRepository(
      fileStore: store,
      keyManager: DataKeyManager(secure),
    );
    final data = await second.initialize();
    expect(data.profiles.map((p) => p.name), ['Me', 'Amma']);
    expect(data.activeProfileId, amma.id);
    expect(data.medications.single.profileId, amma.id);
  });
}
