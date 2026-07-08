/// Abstraction over the platform authentication prompt (biometrics or
/// device credential) so lock logic is testable without platform channels.
abstract interface class IDeviceAuth {
  /// Whether the device can show an authentication prompt at all
  /// (biometrics enrolled, or a device credential set up as fallback).
  Future<bool> canAuthenticate();

  /// Shows the prompt. Returns true when the user authenticated.
  Future<bool> authenticate({required String reason});
}

/// Default used outside main() — e.g. in tests that don't override the
/// provider. Reports no capability and never authenticates.
final class UnavailableDeviceAuth implements IDeviceAuth {
  const UnavailableDeviceAuth();

  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
