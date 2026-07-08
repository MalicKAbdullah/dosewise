import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/app_lock/widgets/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  Widget app(FakeDeviceAuth auth) => ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWithValue(auth),
          appLockEnabledOnLaunchProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('Today content'))),
        ),
      );

  testWidgets('locked start covers the app and auto-unlocks with device auth',
      (tester) async {
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(app(auth));

    // First frame: lock screen covers the content and the prompt fires.
    expect(find.text('DoseWise'), findsOneWidget);
    expect(find.text('Unlock DoseWise'), findsOneWidget);
    expect(find.text('Today content'), findsNothing);

    await tester.pumpAndSettle();
    expect(auth.authCalls, 1, reason: 'auth prompted on screen entry');
    expect(find.text('Unlock DoseWise'), findsNothing);
    expect(find.text('Today content'), findsOneWidget);
  });

  testWidgets('failed auth shows friendly retry copy; button retries',
      (tester) async {
    final auth = FakeDeviceAuth(authResult: false);
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    expect(
      find.text("Unlocking didn't finish. Try again when you're ready."),
      findsOneWidget,
    );
    expect(find.text('Today content'), findsNothing);

    auth.authResult = true;
    await tester.tap(find.text('Unlock DoseWise'));
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2);
    expect(find.text('Today content'), findsOneWidget);
  });
}
