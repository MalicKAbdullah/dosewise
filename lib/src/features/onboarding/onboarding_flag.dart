import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether onboarding has been completed (or skipped). Read once before
/// the first frame in main(), flipped by the onboarding screen.
abstract final class OnboardingFlag {
  static const String storageKey = 'dose_wise_onboarding_seen';

  static Future<bool> read(ISecureStorage storage) async =>
      await storage.read(key: storageKey) == 'true';

  static Future<void> markSeen(ISecureStorage storage) =>
      storage.write(key: storageKey, value: 'true');
}

/// Seeded in main() from secure storage; defaults to true so unit tests
/// and previews never get trapped behind onboarding.
final onboardingSeenOnLaunchProvider = Provider<bool>((ref) => true);

/// Mutable during the session: the router redirects to onboarding while
/// false; completing onboarding flips it and navigates on.
final onboardingCompleteProvider = StateProvider<bool>(
  (ref) => ref.watch(onboardingSeenOnLaunchProvider),
);
