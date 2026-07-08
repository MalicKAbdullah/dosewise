import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:dose_wise/src/features/reminders/services/reminder_service.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:dose_wise/src/features/stats/providers/stats_providers.dart';
import 'package:dose_wise/src/features/today/providers/today_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  // Friday 2026-07-03, 09:30.
  final now = DateTime(2026, 7, 3, 9, 30);

  const amma = Profile(id: 'p-amma', name: 'Amma', colorValue: 0xFFF59E0B);

  Medication med(String id, String profileId, {String? name}) => Medication(
        id: id,
        name: name ?? 'Med $id',
        dosage: '500 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF6366F1,
        startDate: DateTime(2026, 6, 1),
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
        profileId: profileId,
      );

  Future<(ProviderContainer, DoseWiseRepository, FakeReminderService)>
      makeContainer() async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    await repo.saveProfile(amma);
    await repo
        .upsertMedication(med('mine', Profile.defaultId, name: 'Metformin'));
    await repo.upsertMedication(med('hers', amma.id, name: 'Amlodipine'));
    // My 08:00 dose was taken; Amma's was not.
    await repo.saveRecord(
      DoseRecord(
        id: 'r1',
        medicationId: 'mine',
        scheduledTime: DateTime(2026, 7, 3, 8),
        outcome: DoseOutcome.taken,
        recordedAt: DateTime(2026, 7, 3, 8, 2),
        profileId: Profile.defaultId,
      ),
    );
    final reminders = FakeReminderService();
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        reminderServiceProvider.overrideWithValue(reminders),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appDataProvider.future);
    return (container, repo, reminders);
  }

  test('today, stats, and records scope to the active profile', () async {
    final (container, _, _) = await makeContainer();

    // Active profile is "Me": only my medication shows, my dose is taken.
    expect(
      container.read(activeMedicationsProvider).map((m) => m.id),
      ['mine'],
    );
    expect(container.read(activeRecordsProvider).map((r) => r.id), ['r1']);
    final myDoses = container.read(todayDosesProvider);
    expect(myDoses.single.medication.id, 'mine');
    expect(myDoses.single.state, DoseState.taken);
    final myStats = container.read(statsProvider);
    expect(myStats.week.scheduled, greaterThan(0));
    expect(myStats.week.taken, 1);

    // Switch to Amma: her data only, her dose untaken — proving adherence
    // isolation in both directions.
    await container.read(appDataProvider.notifier).switchProfile(amma.id);
    expect(
      container.read(activeMedicationsProvider).map((m) => m.id),
      ['hers'],
    );
    expect(container.read(activeRecordsProvider), isEmpty);
    final herDoses = container.read(todayDosesProvider);
    expect(herDoses.single.medication.id, 'hers');
    expect(herDoses.single.state, isNot(DoseState.taken));
    final herStats = container.read(statsProvider);
    expect(herStats.week.taken, 0);
    expect(herStats.week.scheduled, greaterThan(0));
  });

  test('reminders cover ALL profiles and carry the profile name', () async {
    final (container, _, reminders) = await makeContainer();
    // Trigger a mutation so reminders resync deterministically.
    await container.read(appDataProvider.notifier).switchProfile(amma.id);

    final byMedication = <String, List<ReminderRequest>>{};
    for (final request in reminders.scheduled) {
      byMedication.putIfAbsent(request.medication.id, () => []).add(request);
    }
    // Both profiles' medications are scheduled, regardless of the active
    // profile.
    expect(byMedication.keys.toSet(), {'mine', 'hers'});

    // With two profiles, titles carry the profile name.
    expect(
      byMedication['hers']!.first.title,
      'Amma — Amlodipine 500 mg',
    );
    expect(byMedication['mine']!.first.title, 'Me — Metformin 500 mg');
  });

  test('reminder titles omit the profile with a single profile', () async {
    final (container, repo, reminders) = await makeContainer();
    await container.read(appDataProvider.notifier).deleteProfile(amma.id);

    expect(repo.data.profiles, hasLength(1));
    expect(reminders.scheduled, isNotEmpty);
    for (final request in reminders.scheduled) {
      expect(request.title, 'Time for Metformin');
    }
  });

  test('ReminderRequest title/body logic', () {
    final dose = ScheduledDose(
      medicationId: 'mine',
      time: DateTime(2026, 7, 3, 20),
    );
    final medication = med('mine', Profile.defaultId, name: 'Metformin');

    expect(
      ReminderRequest(dose: dose, medication: medication).title,
      'Time for Metformin',
    );
    expect(
      ReminderRequest(dose: dose, medication: medication).body,
      '500 mg · Tablet',
    );
    expect(
      ReminderRequest(
        dose: dose,
        medication: medication,
        profileName: 'Amma',
      ).title,
      'Amma — Metformin 500 mg',
    );
  });

  test('marking a dose stamps the medication profile on the record', () async {
    final (container, repo, _) = await makeContainer();
    await container.read(appDataProvider.notifier).switchProfile(amma.id);
    final dose = container.read(todayDosesProvider).single.dose;
    await container
        .read(appDataProvider.notifier)
        .markDose(dose, DoseOutcome.taken);

    final record =
        repo.data.records.firstWhere((r) => r.medicationId == 'hers');
    expect(record.profileId, amma.id);
  });
}
