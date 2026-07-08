import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/i_file_store.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';

/// Single source of truth for persisted data.
///
/// Lifecycle: [initialize] obtains the data key and load-decrypt-caches the
/// vault file; every mutation updates the in-memory cache and
/// encrypt-writes the whole vault back to disk (AES-GCM-256).
final class DoseWiseRepository {
  DoseWiseRepository({
    required IFileStore fileStore,
    required DataKeyManager keyManager,
    CipherService cipher = const CipherService(),
  })  : _fileStore = fileStore,
        _keyManager = keyManager,
        _cipher = cipher;

  final IFileStore _fileStore;
  final DataKeyManager _keyManager;
  final CipherService _cipher;

  Uint8List? _key;
  AppData _data = const AppData();

  AppData get data => _data;

  Future<AppData> initialize() async {
    _key = await _keyManager.obtainKey();
    final bytes = await _fileStore.read();
    if (bytes == null) {
      _data = AppData.defaults();
      return _data;
    }
    final plaintext = await _cipher.decrypt(
      payload: EncryptedPayload.fromBytes(bytes),
      keyBytes: _key!,
    );
    _data = AppData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    return _data;
  }

  Future<AppData> upsertMedication(Medication medication) {
    final medications = [..._data.medications]
      ..removeWhere((m) => m.id == medication.id)
      ..add(medication);
    medications.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return _commit(_data.copyWith(medications: medications));
  }

  /// Removes the medication and, to avoid orphaned history, its records.
  Future<AppData> deleteMedication(String medicationId) => _commit(
        _data.copyWith(
          medications:
              _data.medications.where((m) => m.id != medicationId).toList(),
          records: _data.records
              .where((r) => r.medicationId != medicationId)
              .toList(),
        ),
      );

  /// Saves a taken/skipped record, replacing any previous record for the
  /// same dose occurrence. An optional [medicationUpdate] (e.g. a stock
  /// decrement) is committed in the same atomic write, and any snooze for
  /// the dose is cleared.
  Future<AppData> saveRecord(
    DoseRecord record, {
    Medication? medicationUpdate,
  }) {
    final records = [..._data.records]
      ..removeWhere((r) => r.doseKey == record.doseKey)
      ..add(record);
    final snoozes = {..._data.snoozes}..remove(record.doseKey);
    return _commit(
      _data.copyWith(
        records: records,
        snoozes: snoozes,
        medications: _withMedicationUpdate(medicationUpdate),
      ),
    );
  }

  /// Removes the record for a dose occurrence (undo). An optional
  /// [medicationUpdate] (e.g. a stock restore) rides the same write.
  Future<AppData> deleteRecord(
    String doseKey, {
    Medication? medicationUpdate,
  }) =>
      _commit(
        _data.copyWith(
          records: _data.records.where((r) => r.doseKey != doseKey).toList(),
          medications: _withMedicationUpdate(medicationUpdate),
        ),
      );

  /// Replaces the whole app state in one atomic write (backup restore).
  Future<AppData> replaceAll(AppData data) => _commit(data);

  /// Re-reads and decrypts the vault from disk, refreshing the in-memory
  /// cache. Used when another isolate (a notification action handler) may
  /// have written the file since we last read it.
  Future<AppData> reload() async {
    final key = _key;
    if (key == null) return initialize();
    final bytes = await _fileStore.read();
    if (bytes == null) {
      _data = AppData.defaults();
      return _data;
    }
    final plaintext = await _cipher.decrypt(
      payload: EncryptedPayload.fromBytes(bytes),
      keyBytes: key,
    );
    _data = AppData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    return _data;
  }

  /// Replaces the snooze map wholesale (callers own snooze semantics).
  Future<AppData> updateSnoozes(Map<String, DateTime> snoozes) =>
      _commit(_data.copyWith(snoozes: snoozes));

  Future<AppData> updateSettings(AppSettings settings) =>
      _commit(_data.copyWith(settings: settings));

  List<Medication>? _withMedicationUpdate(Medication? update) {
    if (update == null) return null;
    return [
      for (final m in _data.medications) m.id == update.id ? update : m,
    ];
  }

  /// Adds or updates a profile (matched by id).
  Future<AppData> saveProfile(Profile profile) {
    final profiles = [..._data.profiles];
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    return _commit(_data.copyWith(profiles: profiles));
  }

  /// Switches the profile the UI shows. No-op for unknown ids.
  Future<AppData> setActiveProfile(String profileId) async {
    if (!_data.profiles.any((p) => p.id == profileId)) return _data;
    return _commit(_data.copyWith(activeProfileId: profileId));
  }

  /// Deletes a profile and cascades: its medications, their dose records,
  /// and their snoozes all go. Refuses to delete the last profile. If the
  /// active profile is deleted, the first remaining one becomes active.
  Future<AppData> deleteProfile(String profileId) async {
    final profiles = _data.profiles.where((p) => p.id != profileId).toList();
    if (profiles.isEmpty || profiles.length == _data.profiles.length) {
      return _data;
    }
    final removedMedIds = {
      for (final m in _data.medications)
        if (m.profileId == profileId) m.id,
    };
    return _commit(
      _data.copyWith(
        profiles: profiles,
        activeProfileId: _data.activeProfileId == profileId
            ? profiles.first.id
            : _data.activeProfileId,
        medications:
            _data.medications.where((m) => m.profileId != profileId).toList(),
        records: _data.records
            .where(
              (r) =>
                  r.profileId != profileId &&
                  !removedMedIds.contains(r.medicationId),
            )
            .toList(),
        snoozes: {
          for (final entry in _data.snoozes.entries)
            if (!removedMedIds.contains(entry.key.split('|').first))
              entry.key: entry.value,
        },
      ),
    );
  }

  /// Deletes the vault file and the encryption key, and resets the cache.
  Future<AppData> eraseAll() async {
    await _fileStore.delete();
    await _keyManager.deleteKey();
    _key = null;
    _data = AppData.defaults();
    return _data;
  }

  Future<AppData> _commit(AppData next) async {
    final key = _key;
    if (key == null) {
      throw StateError('Repository used before initialize()');
    }
    final payload = await _cipher.encrypt(
      plaintext: jsonEncode(next.toJson()),
      keyBytes: key,
      salt: await _cipher.generateSalt(),
    );
    await _fileStore.write(payload.toBytes());
    _data = next;
    return next;
  }
}
