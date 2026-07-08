import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';

/// A dose reminder ready to be scheduled as a notification.
final class ReminderRequest {
  const ReminderRequest({
    required this.dose,
    required this.medication,
    this.profileName,
  });

  final ScheduledDose dose;
  final Medication medication;

  /// Set when more than one profile exists, so caregivers can tell whose
  /// dose a reminder is for. Null in single-profile mode.
  final String? profileName;

  /// Notification title: "Time for Metformin", or with multiple profiles
  /// "Amma — Metformin 500 mg".
  String get title => profileName == null
      ? 'Time for ${medication.name}'
      : '$profileName — ${medication.name} ${medication.dosage}'.trim();

  /// Notification body, e.g. "500 mg · Tablet".
  String get body => '${medication.dosage} · ${medication.form.label}'.trim();

  /// Deterministic 31-bit notification id derived from the dose identity.
  int get notificationId {
    // FNV-1a over the dose key: stable across runs (unlike hashCode).
    var hash = 0x811c9dc5;
    for (final unit in dose.key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}

/// Schedules dose notifications. Abstract so tests and widget previews can
/// inject a fake — the plugin-backed implementation is only constructed in
/// main().
abstract interface class ReminderService {
  Future<void> initialize();

  /// Asks the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Replaces all pending notifications with the given upcoming doses.
  Future<void> scheduleAll(List<ReminderRequest> requests);

  Future<void> cancelAll();
}

/// Default no-op implementation used outside a real device context.
final class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleAll(List<ReminderRequest> requests) async {}

  @override
  Future<void> cancelAll() async {}
}
