import 'dart:convert';

import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/data/app_data_migrator.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A realistic v1 vault payload, exactly as DoseWise 1.1.x wrote it
/// (no profiles anywhere).
Map<String, dynamic> v1Fixture() => jsonDecode(jsonEncode({
      'version': 1,
      'medications': [
        {
          'id': 'm1',
          'name': 'Metformin',
          'dosage': '500 mg',
          'form': 'tablet',
          'colorValue': 0xFF3B82F6,
          'notes': 'With food',
          'startDate': '2026-06-01T00:00:00.000',
          'schedule': {
            'type': 'weekly',
            'times': ['08:00', '20:00'],
            'weekdays': [1, 2, 3, 4, 5, 6, 7],
          },
          'currentStock': 42,
          'lowStockThreshold': 5,
          'remindersEnabled': true,
          'archived': false,
        },
        {
          'id': 'm2',
          'name': 'Vitamin D',
          'dosage': '1000 IU',
          'form': 'other',
          'colorValue': 0xFF22C55E,
          'notes': '',
          'startDate': '2026-01-15T00:00:00.000',
          'schedule': {'type': 'asNeeded', 'times': []},
          'lowStockThreshold': 5,
          'remindersEnabled': true,
          'archived': true,
        },
      ],
      'records': [
        {
          'id': 'r1',
          'medicationId': 'm1',
          'scheduledTime': '2026-07-01T08:00:00.000',
          'outcome': 'taken',
          'recordedAt': '2026-07-01T08:03:00.000',
        },
      ],
      'settings': {'remindersEnabled': false},
      'snoozes': {'m1|2026-07-02T08:00:00.000': '2026-07-02T08:15:00.000'},
    })) as Map<String, dynamic>;

void main() {
  group('v1 -> v2 migration', () {
    test('wraps everything into a default "Me" profile', () {
      final data = AppData.fromJson(v1Fixture());

      expect(data.profiles, hasLength(1));
      expect(data.profiles.single.id, Profile.defaultId);
      expect(data.profiles.single.name, 'Me');
      expect(data.activeProfileId, Profile.defaultId);
      expect(
        data.medications.map((m) => m.profileId),
        everyElement(Profile.defaultId),
      );
      expect(
        data.records.map((r) => r.profileId),
        everyElement(Profile.defaultId),
      );
    });

    test('loses nothing from the v1 payload', () {
      final data = AppData.fromJson(v1Fixture());

      expect(data.medications, hasLength(2));
      final metformin = data.medications.firstWhere((m) => m.id == 'm1');
      expect(metformin.name, 'Metformin');
      expect(metformin.dosage, '500 mg');
      expect(metformin.notes, 'With food');
      expect(metformin.currentStock, 42);
      expect(metformin.schedule.times, hasLength(2));
      expect(data.medications.firstWhere((m) => m.id == 'm2').archived, true);

      expect(data.records.single.id, 'r1');
      expect(data.records.single.outcome, DoseOutcome.taken);
      expect(data.settings.remindersEnabled, isFalse);
      expect(data.snoozes, hasLength(1));
      expect(
        data.snoozes['m1|2026-07-02T08:00:00.000'],
        DateTime(2026, 7, 2, 8, 15),
      );
    });

    test('is idempotent — migrating a migrated payload changes nothing', () {
      final once = AppDataMigrator.migrate(v1Fixture());
      final twice = AppDataMigrator.migrate(once);
      expect(jsonEncode(twice), jsonEncode(once));

      // And through the model: serialize -> load -> serialize is stable.
      final data = AppData.fromJson(v1Fixture());
      final reloaded = AppData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(reloaded.toJson()), jsonEncode(data.toJson()));
    });

    test('a payload without a version field is treated as v1', () {
      final fixture = v1Fixture()..remove('version');
      final data = AppData.fromJson(fixture);
      expect(data.profiles.single.id, Profile.defaultId);
      expect(data.medications, hasLength(2));
    });
  });

  group('v2 integrity healing', () {
    test('a proper v2 payload passes through untouched', () {
      final data = AppData.fromJson(v1Fixture());
      final v2Json =
          jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
      expect(jsonEncode(AppDataMigrator.migrate(v2Json)), jsonEncode(v2Json));
    });

    test('a dangling activeProfileId falls back to the first profile', () {
      final data = AppData.fromJson(v1Fixture());
      final json = data.toJson()..['activeProfileId'] = 'no-such-profile';
      final healed = AppData.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(healed.activeProfileId, Profile.defaultId);
    });

    test('a medication with an unknown profileId is reassigned', () {
      final data = AppData.fromJson(v1Fixture());
      final json =
          jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
      ((json['medications'] as List).first
          as Map<String, dynamic>)['profileId'] = 'ghost';
      final healed = AppData.fromJson(json);
      expect(healed.medications.first.profileId, Profile.defaultId);
    });
  });

  test('a fresh install starts with one default profile and no data', () {
    final data = AppData.defaults();
    expect(data.profiles.single.name, 'Me');
    expect(data.activeProfileId, data.profiles.single.id);
    expect(data.medications, isEmpty);
    expect(data.records, isEmpty);
  });
}
