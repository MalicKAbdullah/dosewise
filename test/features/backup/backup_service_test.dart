import 'dart:convert';

import 'package:core_crypto/core_crypto.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/features/backup/services/backup_service.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

Medication med(
  String id, {
  String name = 'Metformin',
  DateTime? updatedAt,
  int? stock,
}) =>
    Medication(
      id: id,
      name: name,
      dosage: '500 mg',
      form: MedicationForm.tablet,
      colorValue: 0xFF14B8A6,
      startDate: DateTime(2026, 6, 1),
      schedule: const Schedule.weekly(
        times: [DoseTime(hour: 8, minute: 0)],
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
      currentStock: stock,
      updatedAt: updatedAt,
    );

DoseRecord record(
  String id, {
  String medicationId = 'm1',
  DateTime? scheduledTime,
  DateTime? recordedAt,
  DoseOutcome outcome = DoseOutcome.taken,
}) {
  final scheduled = scheduledTime ?? DateTime(2026, 7, 1, 8);
  return DoseRecord(
    id: id,
    medicationId: medicationId,
    scheduledTime: scheduled,
    outcome: outcome,
    recordedAt: recordedAt ?? scheduled.add(const Duration(minutes: 5)),
  );
}

void main() {
  late BackupService service;

  setUp(() {
    service = BackupService(
      keyDerivation: FakeKeyDerivation(),
      cipher: const CipherService(),
      clock: () => DateTime(2026, 7, 5, 10),
    );
  });

  test('export produces the documented envelope', () async {
    final raw = await service.export(
      data: AppData(
        medications: [med('m1'), med('m2', name: 'Lisinopril')],
        records: [record('r1')],
      ),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    expect(envelope['formatVersion'], BackupService.formatVersion);
    expect(envelope['app'], 'dosewise');
    expect(envelope['appVersion'], isNotEmpty);
    expect(envelope['createdAt'], '2026-07-05T10:00:00.000');
    expect(envelope['medicationCount'], 2);
    expect(envelope['recordCount'], 1);
    expect(envelope['salt'], isNotEmpty);
    expect(envelope['nonce'], isNotEmpty);
    expect(envelope['ciphertext'], isNotEmpty);
  });

  test('ciphertext leaks no plaintext', () async {
    final raw = await service.export(
      data: AppData(medications: [med('m1', name: 'VerySecretDrug')]),
      passphrase: 'correct horse',
    );
    expect(raw.contains('SecretDrug'), isFalse);
    expect(raw.contains('500 mg'), isFalse);
  });

  test('round-trip restores everything exactly, unicode included', () async {
    final original = AppData(
      profiles: [Profile.defaults()],
      medications: [
        med('m1', name: 'Insulin 💉 (naïve « dose »)'),
        med('m2', name: 'Ω-3 ω', updatedAt: DateTime(2026, 7, 1)),
      ],
      records: [record('r1'), record('r2', outcome: DoseOutcome.skipped)],
      settings: const AppSettings(remindersEnabled: false),
      snoozes: {'m1|2026-07-01T08:00:00.000': DateTime(2026, 7, 1, 8, 15)},
    );
    final raw = await service.export(
      data: original,
      passphrase: 'correct horse',
    );
    final restored = await service.decode(
      raw: raw,
      passphrase: 'correct horse',
    );
    expect(jsonEncode(restored.toJson()), jsonEncode(original.toJson()));
    expect(restored.medications.first.name, 'Insulin 💉 (naïve « dose »)');
  });

  test('wrong passphrase throws wrongPassphrase', () async {
    final raw = await service.export(
      data: AppData(medications: [med('m1')]),
      passphrase: 'correct horse',
    );
    expect(
      () => service.decode(raw: raw, passphrase: 'wrong horse'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('tampered ciphertext also fails as wrongPassphrase', () async {
    final raw = await service.export(
      data: AppData(medications: [med('m1')]),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['ciphertext'] as String);
    bytes[0] ^= 0xFF;
    envelope['ciphertext'] = base64Encode(bytes);
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('garbage input throws invalidFormat', () async {
    for (final junk in ['not json', '{}', '{"salt": 5}', '[]']) {
      expect(
        () => service.decode(raw: junk, passphrase: 'x'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.invalidFormat,
          ),
        ),
        reason: junk,
      );
    }
  });

  test('a v1 (pre-profiles) backup imports and migrates', () async {
    // Craft a genuine v1 file: envelope formatVersion 1, ciphertext holding
    // a v1 state JSON without any profile fields.
    const cipher = CipherService();
    final kdf = FakeKeyDerivation();
    final salt = await cipher.generateSalt();
    final key = await kdf.deriveKey(passphrase: 'correct horse', salt: salt);
    final v1State = {
      'version': 1,
      'medications': [
        (med('m1').toJson()
          ..remove('profileId')
          ..remove('updatedAt')),
      ],
      'records': [record('r1').toJson()..remove('profileId')],
      'settings': {'remindersEnabled': true},
      'snoozes': <String, String>{},
    };
    final payload = await cipher.encrypt(
      plaintext: jsonEncode(v1State),
      keyBytes: key,
      salt: salt,
    );
    final raw = jsonEncode({
      'formatVersion': 1,
      'app': 'dosewise',
      'appVersion': '1.1.1',
      'createdAt': '2026-07-01T10:00:00.000',
      'medicationCount': 1,
      'recordCount': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
    });

    final restored = await service.decode(
      raw: raw,
      passphrase: 'correct horse',
    );
    expect(restored.profiles.single.id, Profile.defaultId);
    expect(restored.medications.single.profileId, Profile.defaultId);
    expect(restored.records.single.profileId, Profile.defaultId);
  });

  test('a future format version is rejected', () async {
    final raw = await service.export(
      data: AppData(medications: [med('m1')]),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    envelope['formatVersion'] = 99;
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.unsupportedVersion,
        ),
      ),
    );
  });

  group('merge', () {
    test('adds new medications and keeps untouched ones', () {
      final existing = AppData(medications: [med('a'), med('b')]);
      final imported = AppData(medications: [med('c', name: 'New med')]);
      final merged = BackupService.merge(existing, imported);
      expect(merged.medications.map((m) => m.id).toSet(), {'a', 'b', 'c'});
    });

    test('newer medication updatedAt wins on id clashes — either direction',
        () {
      final older = med('a', name: 'Old name', updatedAt: DateTime(2026, 7, 1));
      final newer = med('a', name: 'New name', updatedAt: DateTime(2026, 7, 3));

      expect(
        BackupService.merge(
          AppData(medications: [older]),
          AppData(medications: [newer]),
        ).medications.single.name,
        'New name',
      );
      expect(
        BackupService.merge(
          AppData(medications: [newer]),
          AppData(medications: [older]),
        ).medications.single.name,
        'New name',
      );
    });

    test('missing updatedAt loses to a stamped one, ties keep existing', () {
      final unstamped = med('a', name: 'Unstamped');
      final stamped = med('a', name: 'Stamped', updatedAt: DateTime(2026));
      expect(
        BackupService.merge(
          AppData(medications: [unstamped]),
          AppData(medications: [stamped]),
        ).medications.single.name,
        'Stamped',
      );
      expect(
        BackupService.merge(
          AppData(medications: [stamped]),
          AppData(medications: [unstamped]),
        ).medications.single.name,
        'Stamped',
      );

      final mine = med('a', name: 'Mine', updatedAt: DateTime(2026));
      final theirs = med('a', name: 'Theirs', updatedAt: DateTime(2026));
      expect(
        BackupService.merge(
          AppData(medications: [mine]),
          AppData(medications: [theirs]),
        ).medications.single.name,
        'Mine',
      );
    });

    test('records merge by dose occurrence; newer recordedAt wins both ways',
        () {
      final scheduled = DateTime(2026, 7, 1, 8);
      final early = record(
        'r1',
        scheduledTime: scheduled,
        recordedAt: DateTime(2026, 7, 1, 8, 5),
        outcome: DoseOutcome.skipped,
      );
      // Same dose occurrence actioned again later on another device —
      // different record id, same doseKey.
      final late_ = record(
        'r2',
        scheduledTime: scheduled,
        recordedAt: DateTime(2026, 7, 1, 9),
      );

      for (final (a, b) in [(early, late_), (late_, early)]) {
        final merged = BackupService.merge(
          AppData(records: [a]),
          AppData(records: [b]),
        );
        expect(merged.records.single.id, 'r2', reason: 'newer action wins');
        expect(merged.records.single.outcome, DoseOutcome.taken);
      }
    });

    test('disjoint records from both sides are all kept', () {
      final merged = BackupService.merge(
        AppData(
            records: [record('r1', scheduledTime: DateTime(2026, 7, 1, 8))]),
        AppData(
            records: [record('r2', scheduledTime: DateTime(2026, 7, 2, 8))]),
      );
      expect(merged.records, hasLength(2));
    });

    test('profiles merge by id; the active profile stays put', () {
      const other = Profile(id: 'p-amma', name: 'Amma', colorValue: 0xFFF59E0B);
      final existing = AppData(
        profiles: [Profile.defaults()],
        activeProfileId: Profile.defaultId,
      );
      final imported = AppData(
        profiles: [
          const Profile(
            id: Profile.defaultId,
            name: 'Renamed elsewhere',
            colorValue: 0xFF000000,
          ),
          other,
        ],
        activeProfileId: 'p-amma',
        medications: [med('hers').copyWith()],
      );

      final merged = BackupService.merge(existing, imported);
      expect(merged.profiles.map((p) => p.id), [Profile.defaultId, 'p-amma']);
      // Clash keeps the existing side; new profile is added.
      expect(merged.profiles.first.name, 'Me');
      expect(merged.activeProfileId, Profile.defaultId);
    });

    test('merge keeps device-local settings and snoozes', () {
      final existing = AppData(
        settings: const AppSettings(remindersEnabled: false),
        snoozes: {'k': DateTime(2026, 7, 1, 9)},
      );
      final imported = AppData(
        settings: const AppSettings(),
        snoozes: {'other': DateTime(2026, 7, 2, 9)},
      );
      final merged = BackupService.merge(existing, imported);
      expect(merged.settings.remindersEnabled, isFalse);
      expect(merged.snoozes.keys, ['k']);
    });
  });

  test('suggested file name is date-stamped', () {
    expect(
      BackupService.suggestedFileName(DateTime(2026, 7, 5)),
      'dosewise-2026-07-05.dwbackup',
    );
  });
}
