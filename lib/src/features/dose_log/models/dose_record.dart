import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';

enum DoseOutcome { taken, skipped }

/// The user's action on a dose: taken or skipped, and when they acted.
///
/// For scheduled doses [scheduledTime] matches the generated occurrence;
/// for as-needed medications it is the moment the dose was logged.
final class DoseRecord {
  const DoseRecord({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    required this.outcome,
    required this.recordedAt,
    this.profileId = Profile.defaultId,
  });

  factory DoseRecord.fromJson(Map<String, dynamic> json) => DoseRecord(
        id: json['id'] as String,
        medicationId: json['medicationId'] as String,
        scheduledTime: DateTime.parse(json['scheduledTime'] as String),
        outcome: DoseOutcome.values.byName(json['outcome'] as String),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        profileId: json['profileId'] as String? ?? Profile.defaultId,
      );

  final String id;
  final String medicationId;
  final DateTime scheduledTime;
  final DoseOutcome outcome;

  /// Actual timestamp of the user's action.
  final DateTime recordedAt;

  /// The profile whose dose this was (same as its medication's).
  final String profileId;

  /// Matches this record to its [ScheduledDose].
  String get doseKey => ScheduledDose.doseKey(medicationId, scheduledTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'scheduledTime': scheduledTime.toIso8601String(),
        'outcome': outcome.name,
        'recordedAt': recordedAt.toIso8601String(),
        'profileId': profileId,
      };
}
