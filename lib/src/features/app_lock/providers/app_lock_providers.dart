import 'package:core_lock/core_lock.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-lock wiring on the shared core_lock package: a fingerprint unlocks
/// DoseWise, with an app-set password (never the phone PIN) as the fallback.

const String lockStorageKey = 'dose_wise_app_lock_enabled';

/// Unavailable by default; main() overrides with the local_auth impl.
final deviceAuthProvider =
    Provider<IDeviceAuth>((ref) => const UnavailableDeviceAuth());

/// Whether the lock / biometric were on at launch — read in main() before
/// runApp so the first frame is already locked.
final appLockEnabledOnLaunchProvider = Provider<bool>((ref) => false);
final appLockBiometricOnLaunchProvider = Provider<bool>((ref) => false);

/// Argon2id verifier for the app-lock fallback password.
final passwordHasherProvider =
    Provider<IPasswordHasher>((ref) => const Argon2PasswordHasher());

final lockControllerProvider = ChangeNotifierProvider<LockController>(
  (ref) => LockController(
    deviceAuth: ref.watch(deviceAuthProvider),
    hasher: ref.watch(passwordHasherProvider),
    storage: ref.watch(secureStorageProvider),
    clock: ref.watch(clockProvider),
    storageKey: lockStorageKey,
    appName: 'DoseWise',
    enabled: ref.watch(appLockEnabledOnLaunchProvider),
    biometricEnabled: ref.watch(appLockBiometricOnLaunchProvider),
  ),
);

/// Settings availability: whether the device has enrolled biometrics.
final deviceAuthAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceAuthProvider).canAuthenticate(),
);
