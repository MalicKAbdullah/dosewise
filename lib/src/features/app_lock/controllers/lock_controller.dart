import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/features/app_lock/services/device_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Owns the optional app-lock state: whether the lock is enabled (persisted
/// in platform secure storage) and whether the app is currently locked.
///
/// Pure Dart apart from [AppLifecycleState] — tested with a fake
/// [IDeviceAuth], an in-memory [ISecureStorage], and a fixed clock.
final class LockController extends ChangeNotifier {
  /// [enabled] is the flag read at cold start (see [readEnabled]); when the
  /// lock is enabled the app starts locked.
  LockController({
    required IDeviceAuth deviceAuth,
    required ISecureStorage storage,
    required DateTime Function() clock,
    bool enabled = false,
  })  : _deviceAuth = deviceAuth,
        _storage = storage,
        _clock = clock,
        _enabled = enabled,
        _locked = enabled;

  static const String storageKey = 'dose_wise_app_lock_enabled';

  /// Backgrounding for longer than this re-locks the app.
  static const Duration backgroundGrace = Duration(seconds: 30);

  static const String _enableReason = 'Confirm to turn on app lock';
  static const String _unlockReason = 'Unlock DoseWise';

  final IDeviceAuth _deviceAuth;
  final ISecureStorage _storage;
  final DateTime Function() _clock;

  bool _enabled;
  bool _locked;
  bool _authInFlight = false;
  DateTime? _backgroundedAt;

  bool get isEnabled => _enabled;

  bool get isLocked => _locked;

  /// Reads the persisted flag before the controller exists, so main() can
  /// construct the app already locked (no unlocked flash on cold start).
  static Future<bool> readEnabled(ISecureStorage storage) async =>
      await storage.read(key: storageKey) == 'true';

  /// Whether the device can offer the lock at all (settings availability).
  Future<bool> canAuthenticate() => _deviceAuth.canAuthenticate();

  /// Turns the lock on or off. Enabling requires one successful
  /// authentication first. Returns true when the change was applied.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled == _enabled) return true;
    if (enabled) {
      if (!await _deviceAuth.canAuthenticate()) return false;
      if (!await _prompt(_enableReason)) return false;
    }
    _enabled = enabled;
    if (enabled) {
      await _storage.write(key: storageKey, value: 'true');
    } else {
      _locked = false;
      await _storage.delete(key: storageKey);
    }
    notifyListeners();
    return true;
  }

  /// Runs the authentication prompt; on success the app unlocks.
  Future<bool> unlock() async {
    if (!_locked) return true;
    if (_authInFlight) return false;
    if (!await _prompt(_unlockReason)) return false;
    _locked = false;
    _backgroundedAt = null;
    notifyListeners();
    return true;
  }

  /// Re-locks when the app was backgrounded past [backgroundGrace].
  /// `inactive` is ignored: it fires for transient overlays, including the
  /// biometric prompt itself.
  void onLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        // The OS auth UI backgrounds the app too — don't count that time.
        if (!_authInFlight) _backgroundedAt ??= _clock();
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (_enabled &&
            !_locked &&
            backgroundedAt != null &&
            _clock().difference(backgroundedAt) > backgroundGrace) {
          _locked = true;
          notifyListeners();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<bool> _prompt(String reason) async {
    _authInFlight = true;
    try {
      return await _deviceAuth.authenticate(reason: reason);
    } finally {
      _authInFlight = false;
    }
  }
}
