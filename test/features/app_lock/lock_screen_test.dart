import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/app_lock/widgets/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  Widget app(FakeDeviceAuth auth, {DateTime Function()? clock}) => ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWithValue(auth),
          appLockEnabledOnLaunchProvider.overrideWithValue(true),
          if (clock != null) clockProvider.overrideWithValue(clock),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('Today content'))),
        ),
      );

  testWidgets('locked start covers the app and auto-unlocks with device auth',
      (tester) async {
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(app(auth));

    // First frame: lock screen covers the content and the button is present
    // immediately — before the async availability probe has resolved.
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
    // The retry button stays available after a failure.
    expect(find.text('Unlock DoseWise'), findsOneWidget);

    auth.authResult = true;
    await tester.tap(find.text('Unlock DoseWise'));
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2);
    expect(find.text('Today content'), findsOneWidget);
  });

  testWidgets('the auto-prompt fires again on every background re-lock',
      (tester) async {
    var now = DateTime(2026, 7, 9, 9, 0);
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(app(auth, clock: () => now));
    await tester.pumpAndSettle();

    expect(auth.authCalls, 1);
    expect(find.text('Today content'), findsOneWidget);

    // Background well past the grace period, then resume: the app re-locks
    // and must auto-prompt again without any tap.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 31));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2, reason: 'auto-prompt re-fires on re-lock');
    expect(find.text('Today content'), findsOneWidget);
  });

  testWidgets('unavailable hardware shows a graceful enter path (no lock-out)',
      (tester) async {
    // available:false + authResult:false models a device with no biometrics
    // and no screen lock — authenticate() can never succeed.
    final auth = FakeDeviceAuth(available: false, authResult: false);
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    // Not a dead screen: a clear message plus a way in.
    expect(find.textContaining('you can still enter DoseWise'), findsOneWidget);
    expect(find.text('Enter DoseWise'), findsOneWidget);
    expect(find.text('Today content'), findsNothing);

    await tester.tap(find.text('Enter DoseWise'));
    await tester.pumpAndSettle();

    expect(find.text('Today content'), findsOneWidget);
  });
}
