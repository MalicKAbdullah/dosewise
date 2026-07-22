import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/core/data/i_file_store.dart';
import 'package:dose_wise/src/core/interfaces/key_derivation.dart';
import 'package:dose_wise/src/features/reminders/services/reminder_service.dart';

/// In-memory [IFileStore] — no dart:io, no platform channels.
final class InMemoryFileStore implements IFileStore {
  Uint8List? bytes;
  int writeCount = 0;

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List data) async {
    bytes = Uint8List.fromList(data);
    writeCount++;
  }

  @override
  Future<void> delete() async => bytes = null;
}

/// In-memory [ISecureStorage] — no flutter_secure_storage plugin.
final class InMemorySecureStorage implements ISecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

/// Fast, deterministic [IKeyDerivation] — real Argon2id is far too slow
/// for unit tests. Different passphrase or salt still yields a different
/// key, so wrong-passphrase paths stay honest.
final class FakeKeyDerivation implements IKeyDerivation {
  @override
  Future<Uint8List> deriveKey({
    required String passphrase,
    required Uint8List salt,
  }) async {
    final input = [...passphrase.codeUnits, ...salt];
    final key = Uint8List(32);
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      for (final byte in input) {
        hash ^= byte ^ i;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      key[i] = hash & 0xFF;
    }
    return key;
  }
}

/// Recording [ReminderService] fake — never touches the notifications
/// plugin.
final class FakeReminderService implements ReminderService {
  List<ReminderRequest> scheduled = [];
  int cancelAllCount = 0;
  bool permissionRequested = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<void> scheduleAll(List<ReminderRequest> requests) async =>
      scheduled = List.of(requests);

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled = [];
  }
}
