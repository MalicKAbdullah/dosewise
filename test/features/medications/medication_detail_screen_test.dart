import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/screens/medication_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  // Friday 2026-07-03, 09:30.
  final now = DateTime(2026, 7, 3, 9, 30);

  final medication = Medication(
    id: 'm1',
    name: 'Metformin',
    dosage: '500 mg',
    form: MedicationForm.tablet,
    colorValue: 0xFF14B8A6,
    startDate: DateTime(2026, 7, 1),
    schedule: const Schedule.weekly(
      times: [DoseTime(hour: 8, minute: 0)],
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    currentStock: 4,
    lowStockThreshold: 5,
  );

  Future<DoseWiseRepository> seededRepo() async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    await repo.upsertMedication(medication);
    // Jul 1 and Jul 2 taken; Jul 3 (today) still open.
    for (final day in [1, 2]) {
      await repo.saveRecord(
        DoseRecord(
          id: 'r$day',
          medicationId: medication.id,
          scheduledTime: DateTime(2026, 7, day, 8),
          outcome: DoseOutcome.taken,
          recordedAt: DateTime(2026, 7, day, 8, 5),
        ),
      );
    }
    return repo;
  }

  Widget app(DoseWiseRepository repo) => ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(
          home: MedicationDetailScreen(medicationId: 'm1'),
        ),
      );

  testWidgets('renders header, supply, adherence, and history from the repo',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(await seededRepo()));
    await tester.pumpAndSettle();

    // Header.
    expect(find.text('Metformin'), findsWidgets);
    expect(find.text('500 mg · Tablet'), findsOneWidget);
    expect(find.textContaining('8:00'), findsWidgets);

    // Supply: 4 on hand, threshold 5 -> low supply chip + warning copy.
    expect(find.text('Supply'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Low supply'), findsOneWidget);
    expect(find.textContaining('Running low'), findsOneWidget);
    expect(find.text('Refill'), findsOneWidget);

    // Adherence: 2 taken of 3 due (Jul 1, 2, 3-so-far) = 67% both windows.
    expect(find.text('Adherence'), findsOneWidget);
    expect(find.text('67%'), findsNWidgets(2));

    // Recent history shows the two taken records.
    expect(find.text('Recent history'), findsOneWidget);
    expect(find.textContaining('Taken'), findsNWidgets(2));
  });

  testWidgets('refill action tops up the stock', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = await seededRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refill'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.tap(find.text('Add to supply'));
    await tester.pumpAndSettle();

    expect(repo.data.medications.single.currentStock, 34);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('Low supply'), findsNothing);
  });

  testWidgets('shows a friendly message when the medication is gone',
      (tester) async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();

    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(
      find.text('This medication is no longer here.'),
      findsOneWidget,
    );
  });
}
