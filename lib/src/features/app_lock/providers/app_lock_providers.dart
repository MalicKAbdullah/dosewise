import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/app_lock/controllers/lock_controller.dart';
import 'package:dose_wise/src/features/app_lock/services/device_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unavailable by default; main() overrides this with the local_auth
/// implementation. Tests keep the default or inject a fake.
final deviceAuthProvider =
    Provider<IDeviceAuth>((ref) => const UnavailableDeviceAuth());

/// Whether the app-lock flag was set at launch — read in main() before
/// runApp so the first frame is already locked when the lock is on.
final appLockEnabledOnLaunchProvider = Provider<bool>((ref) => false);

final lockControllerProvider = ChangeNotifierProvider<LockController>(
  (ref) => LockController(
    deviceAuth: ref.watch(deviceAuthProvider),
    storage: ref.watch(secureStorageProvider),
    clock: ref.watch(clockProvider),
    enabled: ref.watch(appLockEnabledOnLaunchProvider),
  ),
);

/// Settings availability: whether the device can show an auth prompt.
final deviceAuthAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceAuthProvider).canAuthenticate(),
);
