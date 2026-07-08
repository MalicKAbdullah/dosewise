import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/today/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  // Friday 2026-07-03, 09:30 local — the 08:00 dose is now late.
  final now = DateTime(2026, 7, 3, 9, 30);

  Medication med({
    String id = 'm1',
    String name = 'Amoxicillin',
    Schedule schedule = const Schedule.weekly(
      times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    int? stock,
  }) =>
      Medication(
        id: id,
        name: name,
        dosage: '500 mg',
        form: MedicationForm.capsule,
        colorValue: 0xFF6366F1,
        startDate: DateTime(2026, 6, 1),
        schedule: schedule,
        currentStock: stock,
      );

  Future<(DoseWiseRepository, FakeReminderService)> seededRepo(
    List<Medication> medications,
  ) async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    for (final medication in medications) {
      await repo.upsertMedication(medication);
    }
    return (repo, FakeReminderService());
  }

  Widget app(DoseWiseRepository repo, FakeReminderService reminders) =>
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reminderServiceProvider.overrideWithValue(reminders),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: TodayScreen()),
      );

  testWidgets('renders today\'s doses from the repository with progress',
      (tester) async {
    final (repo, reminders) = await seededRepo([med()]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    // Two dose tiles for the same medication (08:00 and 20:00).
    expect(find.text('Amoxicillin'), findsNWidgets(2));
    expect(find.text('500 mg · Capsule'), findsNWidgets(2));
    expect(find.text('0 of 2 doses taken today'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    // 08:00 is over an hour past at 09:30 → late; 20:00 is upcoming.
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('marking a dose taken updates progress and persists a record',
      (tester) async {
    final (repo, reminders) = await seededRepo([med()]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Take').first);
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 doses taken today'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(repo.data.records, hasLength(1));
    expect(repo.data.records.single.recordedAt, now);
    // Reminders were rescheduled after the mutation.
    expect(reminders.scheduled, isNotEmpty);
  });

  testWidgets('skipping and undoing a dose works', (tester) async {
    final (repo, reminders) = await seededRepo([med()]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Skip').first);
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsOneWidget);
    expect(repo.data.records, hasLength(1));

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsNothing);
    expect(repo.data.records, isEmpty);
  });

  testWidgets('shows the guided first-medication CTA when the profile is empty',
      (tester) async {
    final (repo, reminders) = await seededRepo([]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    expect(find.text('Add your first medication'), findsOneWidget);
  });

  testWidgets('shows the quiet-day empty state when doses exist other days',
      (tester) async {
    // Monday-only schedule — "now" is Friday 2026-07-03, nothing due.
    final (repo, reminders) = await seededRepo([
      med(
        schedule: const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: {DateTime.monday},
        ),
      ),
    ]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing on the schedule today'),
      findsOneWidget,
    );
  });

  testWidgets('snoozing a late dose moves its timeline slot 15 minutes',
      (tester) async {
    final (repo, reminders) = await seededRepo([med()]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    // Only the late 08:00 dose can snooze (20:00 is merely upcoming).
    expect(find.byTooltip('Snooze 15 min'), findsOneWidget);
    await tester.tap(find.byTooltip('Snooze 15 min'));
    await tester.pumpAndSettle();

    // 09:30 + 15 min → the dose now sits at 09:45 with a snoozed badge.
    final snoozedTime = formatTime(DateTime(2026, 7, 3, 9, 45));
    expect(find.text('Snoozed · $snoozedTime'), findsOneWidget);
    expect(find.text(snoozedTime), findsOneWidget); // New time group header.
    expect(repo.data.snoozes.values.single, DateTime(2026, 7, 3, 9, 45));

    // Taking the dose clears the snooze and records the original time.
    await tester.tap(find.byTooltip('Take').first);
    await tester.pumpAndSettle();
    expect(repo.data.snoozes, isEmpty);
    expect(
      repo.data.records.single.scheduledTime,
      DateTime(2026, 7, 3, 8, 0),
    );
  });

  testWidgets('taking a dose consumes tracked stock; undo returns it',
      (tester) async {
    final (repo, reminders) = await seededRepo([med(stock: 10)]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Take').first);
    await tester.pumpAndSettle();
    expect(repo.data.medications.single.currentStock, 9);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(repo.data.medications.single.currentStock, 10);
  });

  testWidgets('low tracked stock surfaces a supply warning', (tester) async {
    final (repo, reminders) = await seededRepo([med(stock: 3)]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    expect(find.textContaining('running low'), findsOneWidget);
    expect(find.text('Low supply'), findsNWidgets(2)); // Both dose tiles.
  });

  testWidgets('as-needed medications get a manual log section', (tester) async {
    final (repo, reminders) = await seededRepo([
      med(
        id: 'prn',
        name: 'Paracetamol',
        schedule: const Schedule.asNeeded(),
      ),
    ]);
    await tester.pumpWidget(app(repo, reminders));
    await tester.pumpAndSettle();

    expect(find.text('As needed'), findsOneWidget);
    await tester.tap(find.text('Log dose'));
    await tester.pumpAndSettle();
    expect(repo.data.records, hasLength(1));
    expect(repo.data.records.single.medicationId, 'prn');
  });
}
