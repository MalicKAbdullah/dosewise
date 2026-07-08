import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:dose_wise/src/features/today/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  final now = DateTime(2026, 7, 3, 9, 30);

  const amma = Profile(id: 'p-amma', name: 'Amma', colorValue: 0xFFF59E0B);

  Medication med(String id, String profileId, String name) => Medication(
        id: id,
        name: name,
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

  Future<DoseWiseRepository> seededRepo({bool withAmma = true}) async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    if (withAmma) await repo.saveProfile(amma);
    await repo.upsertMedication(med('mine', Profile.defaultId, 'Metformin'));
    if (withAmma) {
      await repo.upsertMedication(med('hers', amma.id, 'Amlodipine'));
    }
    return repo;
  }

  Widget app(DoseWiseRepository repo) => ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: TodayScreen()),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();
  }

  testWidgets('switching profiles swaps the Today timeline', (tester) async {
    final repo = await seededRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('Amlodipine'), findsNothing);

    await openSheet(tester);
    await tester.tap(find.text('Amma'));
    await tester.pumpAndSettle();

    expect(repo.data.activeProfileId, amma.id);
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('Metformin'), findsNothing);
  });

  testWidgets('adding a profile switches to it (fresh and empty)',
      (tester) async {
    final repo = await seededRepo(withAmma: false);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await openSheet(tester);
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Abbu');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.data.profiles.map((p) => p.name), ['Me', 'Abbu']);
    expect(repo.data.activeProfile.name, 'Abbu');
    // The new profile has no medications yet → guided first-run CTA.
    expect(find.text('Add your first medication'), findsOneWidget);
  });

  testWidgets('renaming a profile', (tester) async {
    final repo = await seededRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await openSheet(tester);
    await tester.tap(find.byTooltip('Profile options for Amma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ammi');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      repo.data.profiles.firstWhere((p) => p.id == amma.id).name,
      'Ammi',
    );
  });

  testWidgets(
      'deleting a profile requires typing its name and cascades its data',
      (tester) async {
    final repo = await seededRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await openSheet(tester);
    await tester.tap(find.byTooltip('Profile options for Amma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();

    // Until the exact name is typed, the destructive button is disabled.
    final deleteButton = find.widgetWithText(FilledButton, 'Delete profile');
    expect(tester.widget<FilledButton>(deleteButton).enabled, isFalse);
    await tester.enterText(find.byType(TextField).last, 'Wrong');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(deleteButton).enabled, isFalse);

    await tester.enterText(find.byType(TextField).last, 'Amma');
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(repo.data.profiles.map((p) => p.id), [Profile.defaultId]);
    expect(repo.data.medications.map((m) => m.id), ['mine']);
  });

  testWidgets('the last profile offers no delete option', (tester) async {
    final repo = await seededRepo(withAmma: false);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await openSheet(tester);
    await tester.tap(find.byTooltip('Profile options for Me'));
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete…'), findsNothing);
  });
}
