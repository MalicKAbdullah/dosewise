import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/app_lock/controllers/lock_controller.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  Widget app(FakeDeviceAuth auth, ISecureStorage storage) => ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          deviceAuthProvider.overrideWithValue(auth),
          repositoryProvider.overrideWithValue(
            DoseWiseRepository(
              fileStore: InMemoryFileStore(),
              keyManager: DataKeyManager(InMemorySecureStorage()),
            ),
          ),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );

  Finder appLockSwitch() => find.descendant(
        of: find.widgetWithText(SwitchListTile, 'App lock'),
        matching: find.byType(Switch),
      );

  testWidgets('app lock toggle round-trips through secure storage',
      (tester) async {
    final auth = FakeDeviceAuth();
    final storage = InMemorySecureStorage();
    await tester.pumpWidget(app(auth, storage));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(appLockSwitch()).value, isFalse);

    // Enable: requires one successful authentication, then persists.
    await tester.tap(appLockSwitch());
    await tester.pumpAndSettle();
    expect(auth.authCalls, 1);
    expect(tester.widget<Switch>(appLockSwitch()).value, isTrue);
    expect(await LockController.readEnabled(storage), isTrue);

    // Disable: no prompt, flag cleared.
    await tester.tap(appLockSwitch());
    await tester.pumpAndSettle();
    expect(auth.authCalls, 1);
    expect(tester.widget<Switch>(appLockSwitch()).value, isFalse);
    expect(await LockController.readEnabled(storage), isFalse);
  });

  testWidgets('failed authentication keeps the toggle off and explains why',
      (tester) async {
    final auth = FakeDeviceAuth(authResult: false);
    final storage = InMemorySecureStorage();
    await tester.pumpWidget(app(auth, storage));
    await tester.pumpAndSettle();

    await tester.tap(appLockSwitch());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(appLockSwitch()).value, isFalse);
    expect(
      find.text('Authentication is required to turn on app lock.'),
      findsOneWidget,
    );
    expect(await LockController.readEnabled(storage), isFalse);
  });

  testWidgets('shows a graceful not-available state without device auth',
      (tester) async {
    final auth = FakeDeviceAuth(available: false);
    await tester.pumpWidget(app(auth, InMemorySecureStorage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Not available'),
      findsOneWidget,
    );
    final switchWidget = tester.widget<Switch>(appLockSwitch());
    expect(switchWidget.onChanged, isNull, reason: 'toggle disabled');
  });
}
