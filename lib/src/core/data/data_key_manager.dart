import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';

/// Owns the random 256-bit data-encryption key. Generated once on first
/// launch and kept in platform secure storage (Keychain / Keystore).
final class DataKeyManager {
  const DataKeyManager(this._secureStorage);

  static const String storageKey = 'dose_wise_data_key';
  static const int _keyLengthBytes = 32;

  final ISecureStorage _secureStorage;

  /// Returns the existing key, generating and persisting one if absent.
  Future<Uint8List> obtainKey() async {
    final stored = await _secureStorage.read(key: storageKey);
    if (stored != null) {
      return Uint8List.fromList(base64Decode(stored));
    }
    final key = _generateKey();
    await _secureStorage.write(key: storageKey, value: base64Encode(key));
    return key;
  }

  /// Destroys the key. Any data encrypted with it becomes unrecoverable.
  Future<void> deleteKey() => _secureStorage.delete(key: storageKey);

  static Uint8List _generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_keyLengthBytes, (_) => random.nextInt(256)),
    );
  }
}
