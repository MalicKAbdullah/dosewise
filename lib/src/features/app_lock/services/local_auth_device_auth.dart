import 'package:dose_wise/src/features/app_lock/services/device_auth.dart';
import 'package:local_auth/local_auth.dart';

/// Production [IDeviceAuth] backed by the local_auth plugin.
/// Constructed only in main(); everything else depends on the interface.
final class LocalAuthDeviceAuth implements IDeviceAuth {
  LocalAuthDeviceAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      // isDeviceSupported covers device-credential fallback (PIN/pattern)
      // even when no biometrics are enrolled.
      return await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // biometricOnly stays false so the OS offers the device credential
        // (PIN/pattern/passcode) when biometrics are unavailable or fail.
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
