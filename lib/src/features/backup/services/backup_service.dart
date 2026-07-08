import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:dose_wise/src/core/app_info.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/interfaces/key_derivation.dart';

/// Why a backup could not be read.
enum BackupError { invalidFormat, unsupportedVersion, wrongPassphrase }

final class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException($error)';
}

/// Encrypted `.dwbackup` export/import.
///
/// The file is a JSON envelope `{formatVersion, app, appVersion, createdAt,
/// medicationCount, recordCount, salt, nonce, ciphertext}` where the
/// ciphertext is the full app state JSON encrypted with AES-GCM under an
/// Argon2id key derived from a user-chosen backup passphrase (independent
/// of the device data key).
final class BackupService {
  const BackupService({
    required IKeyDerivation keyDerivation,
    required CipherService cipher,
    required DateTime Function() clock,
  })  : _kdf = keyDerivation,
        _cipher = cipher,
        _clock = clock;

  final IKeyDerivation _kdf;
  final CipherService _cipher;
  final DateTime Function() _clock;

  /// v1: pre-profiles state. v2: state carries profiles. Old backups are
  /// still importable — [decode] migrates their state on the way in.
  static const int formatVersion = 2;
  static const String fileExtension = 'dwbackup';
  static const int minPassphraseLength = 8;

  /// Serializes and encrypts the full app state under [passphrase].
  Future<String> export({
    required AppData data,
    required String passphrase,
  }) async {
    final salt = await _cipher.generateSalt();
    final key = await _kdf.deriveKey(passphrase: passphrase, salt: salt);
    final payload = await _cipher.encrypt(
      plaintext: jsonEncode(data.toJson()),
      keyBytes: key,
      salt: salt,
    );
    key.fillRange(0, key.length, 0);
    return jsonEncode({
      'formatVersion': formatVersion,
      'app': 'dosewise',
      'appVersion': AppInfo.version,
      'createdAt': _clock().toIso8601String(),
      'medicationCount': data.medications.length,
      'recordCount': data.records.length,
      'salt': base64Encode(salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
    });
  }

  /// Decrypts a backup produced by [export]. Throws [BackupException] on a
  /// malformed file, unsupported version, or wrong passphrase.
  Future<AppData> decode({
    required String raw,
    required String passphrase,
  }) async {
    final Map<String, dynamic> envelope;
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List ciphertext;
    try {
      envelope = jsonDecode(raw) as Map<String, dynamic>;
      salt = base64Decode(envelope['salt'] as String);
      nonce = base64Decode(envelope['nonce'] as String);
      ciphertext = base64Decode(envelope['ciphertext'] as String);
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
    final version = envelope['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const BackupException(BackupError.unsupportedVersion);
    }

    final key = await _kdf.deriveKey(passphrase: passphrase, salt: salt);
    final String plaintext;
    try {
      plaintext = await _cipher.decrypt(
        payload: EncryptedPayload(
          ciphertext: ciphertext,
          nonce: nonce,
          salt: salt,
        ),
        keyBytes: key,
      );
    } catch (_) {
      // AES-GCM authentication failed: wrong passphrase (or tampered file).
      throw const BackupException(BackupError.wrongPassphrase);
    } finally {
      key.fillRange(0, key.length, 0);
    }

    try {
      // AppData.fromJson also migrates older state schemas, so restoring a
      // backup made by an older DoseWise upgrades it the same way loading
      // an old vault does.
      return AppData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
  }

  /// Merges [imported] into [existing]:
  /// - Profiles merge by id; new ones are added, clashes keep the
  ///   existing side (and the active profile stays put).
  /// - Medications merge by id; on a clash the newer `updatedAt` wins
  ///   (missing timestamps count as oldest; ties keep the existing side).
  /// - Dose records merge by dose occurrence (`doseKey`); the newer
  ///   `recordedAt` wins, which keeps the one-record-per-dose invariant.
  /// - Settings and snoozes are device-local and stay as they are.
  static AppData merge(AppData existing, AppData imported) {
    final profilesById = {for (final p in existing.profiles) p.id: p};
    final profiles = [
      ...existing.profiles,
      for (final p in imported.profiles)
        if (!profilesById.containsKey(p.id)) p,
    ];

    final medsById = {for (final m in existing.medications) m.id: m};
    for (final candidate in imported.medications) {
      final current = medsById[candidate.id];
      if (current == null || _isNewer(candidate.updatedAt, current.updatedAt)) {
        medsById[candidate.id] = candidate;
      }
    }
    final medications = medsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final recordsByDose = {for (final r in existing.records) r.doseKey: r};
    for (final candidate in imported.records) {
      final current = recordsByDose[candidate.doseKey];
      if (current == null || candidate.recordedAt.isAfter(current.recordedAt)) {
        recordsByDose[candidate.doseKey] = candidate;
      }
    }
    final records = recordsByDose.values.toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return existing.copyWith(
      profiles: profiles,
      medications: medications,
      records: records,
    );
  }

  static bool _isNewer(DateTime? candidate, DateTime? current) {
    if (candidate == null) return false;
    if (current == null) return true;
    return candidate.isAfter(current);
  }

  static String suggestedFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'dosewise-${now.year}-${two(now.month)}-${two(now.day)}'
        '.$fileExtension';
  }
}
