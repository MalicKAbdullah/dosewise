import 'package:dose_wise/src/features/profiles/models/profile.dart';

/// Migrates persisted state JSON (vault file or decrypted backup) to the
/// current schema. Runs on every load, so it must be idempotent and must
/// never lose data.
///
/// v1 → v2: multiple profiles. Everything that exists is wrapped into a
/// single default profile ("Me") exactly once; medications and dose
/// records gain a `profileId`.
abstract final class AppDataMigrator {
  static const int currentVersion = 2;

  static Map<String, dynamic> migrate(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    var out = Map<String, dynamic>.of(json);
    if (version < 2) {
      out = _v1ToV2(out);
    }
    return _ensureProfileIntegrity(out);
  }

  /// Wraps a pre-profiles state into the default "Me" profile.
  static Map<String, dynamic> _v1ToV2(Map<String, dynamic> json) => {
        ...json,
        'version': 2,
        'profiles': [Profile.defaults().toJson()],
        'activeProfileId': Profile.defaultId,
        'medications': _withProfileId(json['medications'], Profile.defaultId),
        'records': _withProfileId(json['records'], Profile.defaultId),
      };

  /// Self-healing invariants, applied on every load:
  /// - there is always at least one profile (fresh installs start here);
  /// - `activeProfileId` always points at an existing profile;
  /// - every medication/record `profileId` points at an existing profile.
  static Map<String, dynamic> _ensureProfileIntegrity(
    Map<String, dynamic> json,
  ) {
    final out = Map<String, dynamic>.of(json);
    out['version'] = currentVersion;

    final profiles = (out['profiles'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    if (profiles.isEmpty) profiles.add(Profile.defaults().toJson());
    out['profiles'] = profiles;

    final profileIds = {for (final p in profiles) p['id'] as String};
    final fallbackId = profiles.first['id'] as String;

    final active = out['activeProfileId'];
    if (active is! String || !profileIds.contains(active)) {
      out['activeProfileId'] = fallbackId;
    }

    Map<String, dynamic> reassign(Map<String, dynamic> item) {
      final profileId = item['profileId'];
      if (profileId is String && profileIds.contains(profileId)) return item;
      return {...item, 'profileId': fallbackId};
    }

    out['medications'] = (out['medications'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(reassign)
        .toList();
    out['records'] = (out['records'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(reassign)
        .toList();
    return out;
  }

  static List<Map<String, dynamic>> _withProfileId(
    Object? items,
    String profileId,
  ) =>
      (items as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => {...item, 'profileId': profileId})
          .toList();
}
