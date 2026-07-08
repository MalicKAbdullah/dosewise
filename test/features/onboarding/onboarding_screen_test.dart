import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/onboarding/onboarding_flag.dart';
import 'package:dose_wise/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fakes.dart';

void main() {
  late InMemorySecureStorage storage;

  Widget app() {
    storage = InMemorySecureStorage();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) =>
              const Scaffold(body: Text('Today screen')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        onboardingSeenOnLaunchProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('walks through all three pages and completes', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Never miss a dose'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Private by design'), findsOneWidget);
    expect(
      find.textContaining('health data stays on this device'),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders that do the work'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Landed on Today; the seen flag persisted so it never shows again.
    expect(find.text('Today screen'), findsOneWidget);
    expect(storage.values[OnboardingFlag.storageKey], 'true');
  });

  testWidgets('skip completes immediately from the first page', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Today screen'), findsOneWidget);
    expect(storage.values[OnboardingFlag.storageKey], 'true');
  });
}
