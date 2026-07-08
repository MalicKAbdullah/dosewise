import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/screens/medication_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  final now = DateTime(2026, 7, 3, 9);

  late DoseWiseRepository repo;

  Future<void> pumpForm(WidgetTester tester, Widget widget) async {
    // Tall viewport so the whole form (incl. the save button) is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
  });

  Widget app() => ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: MedicationFormScreen()),
      );

  testWidgets(
      'save with empty fields shows validation errors and saves '
      'nothing', (tester) async {
    await pumpForm(tester, app());

    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Dosage is required'), findsOneWidget);
    expect(repo.data.medications, isEmpty);
  });

  testWidgets('weekly schedule requires at least one weekday', (tester) async {
    await pumpForm(tester, app());

    await tester.enterText(find.byType(TextFormField).at(0), 'Amoxicillin');
    await tester.enterText(find.byType(TextFormField).at(1), '500 mg');

    // Deselect all default weekdays.
    for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one weekday.'), findsOneWidget);
    expect(repo.data.medications, isEmpty);
  });

  testWidgets('valid form saves an encrypted medication', (tester) async {
    await pumpForm(tester, app());

    await tester.enterText(find.byType(TextFormField).at(0), 'Amoxicillin');
    await tester.enterText(find.byType(TextFormField).at(1), '500 mg');

    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(repo.data.medications, hasLength(1));
    final saved = repo.data.medications.single;
    expect(saved.name, 'Amoxicillin');
    expect(saved.dosage, '500 mg');
    expect(saved.schedule.type, ScheduleType.weekly);
    expect(saved.schedule.weekdays, hasLength(7));
    expect(
      saved.schedule.times.single,
      const DoseTime(hour: 8, minute: 0),
    );
  });
}
