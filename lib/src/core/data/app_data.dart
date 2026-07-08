import 'package:dose_wise/src/core/data/app_data_migrator.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';

/// User preferences persisted alongside the data.
final class AppSettings {
  const AppSettings({this.remindersEnabled = true});

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      );

  final bool remindersEnabled;

  AppSettings copyWith({bool? remindersEnabled}) => AppSettings(
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      );

  Map<String, dynamic> toJson() => {'remindersEnabled': remindersEnabled};
}

/// The complete application state that is serialized, encrypted, and
/// written to disk as a single unit.
final class AppData {
  const AppData({
    this.profiles = const [],
    this.activeProfileId = Profile.defaultId,
    this.medications = const [],
    this.records = const [],
    this.settings = const AppSettings(),
    this.snoozes = const {},
  });

  /// Runs [AppDataMigrator] first, so loading a pre-profiles vault (or
  /// restoring an old backup) upgrades it in one place.
  factory AppData.fromJson(Map<String, dynamic> json) {
    final migrated = AppDataMigrator.migrate(json);
    return AppData(
      profiles: (migrated['profiles'] as List<dynamic>)
          .map((p) => Profile.fromJson(p as Map<String, dynamic>))
          .toList(),
      activeProfileId: migrated['activeProfileId'] as String,
      medications: (migrated['medications'] as List<dynamic>)
          .map((m) => Medication.fromJson(m as Map<String, dynamic>))
          .toList(),
      records: (migrated['records'] as List<dynamic>)
          .map((r) => DoseRecord.fromJson(r as Map<String, dynamic>))
          .toList(),
      settings: migrated['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(migrated['settings'] as Map<String, dynamic>),
      snoozes: (migrated['snoozes'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, DateTime.parse(value as String))),
    );
  }

  /// A fresh install: no data, one default profile ("Me").
  factory AppData.defaults() => AppData.fromJson(const {'version': 2});

  /// Bump when the persisted shape changes incompatibly (see
  /// [AppDataMigrator]).
  static const int schemaVersion = AppDataMigrator.currentVersion;

  final List<Profile> profiles;

  /// The profile the UI currently shows. Reminders are always scheduled
  /// across all profiles.
  final String activeProfileId;
  final List<Medication> medications;
  final List<DoseRecord> records;
  final AppSettings settings;

  /// Active snoozes: dose key -> the time the dose was pushed back to.
  /// Pruned to today's entries on every snooze write.
  final Map<String, DateTime> snoozes;

  /// The active profile; falls back safely if the id ever dangles.
  Profile get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.isNotEmpty ? profiles.first : Profile.defaults();
  }

  /// Medications belonging to [profileId].
  List<Medication> medicationsFor(String profileId) =>
      medications.where((m) => m.profileId == profileId).toList();

  /// Dose records belonging to [profileId].
  List<DoseRecord> recordsFor(String profileId) =>
      records.where((r) => r.profileId == profileId).toList();

  AppData copyWith({
    List<Profile>? profiles,
    String? activeProfileId,
    List<Medication>? medications,
    List<DoseRecord>? records,
    AppSettings? settings,
    Map<String, DateTime>? snoozes,
  }) =>
      AppData(
        profiles: profiles ?? this.profiles,
        activeProfileId: activeProfileId ?? this.activeProfileId,
        medications: medications ?? this.medications,
        records: records ?? this.records,
        settings: settings ?? this.settings,
        snoozes: snoozes ?? this.snoozes,
      );

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'activeProfileId': activeProfileId,
        'medications': medications.map((m) => m.toJson()).toList(),
        'records': records.map((r) => r.toJson()).toList(),
        'settings': settings.toJson(),
        'snoozes':
            snoozes.map((key, value) => MapEntry(key, value.toIso8601String())),
      };
}
