import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fakes.dart';

void main() {
  testWidgets('Settings → Appearance → Dark switches the theme and saves it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appearance = await AppearanceController.load();
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await tester.runAsync(repo.initialize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          appearanceProvider.overrideWithValue(appearance),
        ],
        child: ListenableBuilder(
          listenable: appearance,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.build(
              Brightness.light,
              accent: AppAccents.dosewise,
            ),
            darkTheme: AppTheme.build(
              Brightness.dark,
              accent: AppAccents.dosewise,
            ),
            themeMode: appearance.mode,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(appearance.mode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppearanceController.storageKey), 'dark');
  });
}
