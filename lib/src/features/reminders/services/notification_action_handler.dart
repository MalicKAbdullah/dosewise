import 'dart:convert';

import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/services/refill_service.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:uuid/uuid.dart';

/// Notification action button ids ("Take" / "Skip" on a dose reminder).
abstract final class NotificationActions {
  static const String take = 'take';
  static const String skip = 'skip';
}

/// Pure-Dart core of the notification action path: parse the payload a
/// reminder was scheduled with, then persist the matching dose record
/// through the repository. Runs both in the app process (foreground taps,
/// launch-from-notification) and in the background isolate.
final class NotificationActionHandler {
  NotificationActionHandler({
    required DoseWiseRepository repository,
    RefillService refillService = const RefillService(),
    String Function()? idGenerator,
    DateTime Function() clock = DateTime.now,
  })  : _repository = repository,
        _refillService = refillService,
        _idGenerator = idGenerator ?? const Uuid().v4,
        _clock = clock;

  final DoseWiseRepository _repository;
  final RefillService _refillService;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  /// Encodes the dose identity carried by a reminder notification.
  static String encodePayload(ScheduledDose dose) => jsonEncode({
        'medicationId': dose.medicationId,
        'scheduledTime': dose.time.toIso8601String(),
      });

  /// Parses a payload produced by [encodePayload]; null when malformed.
  static ScheduledDose? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return ScheduledDose(
        medicationId: json['medicationId'] as String,
        time: DateTime.parse(json['scheduledTime'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Applies a notification response. Returns the outcome that was
  /// persisted, or null when the response was not an actionable Take/Skip
  /// (plain body tap, malformed payload, or unknown medication).
  ///
  /// Mirrors the in-app Take/Skip semantics: one record per dose
  /// occurrence (a repeat tap replaces the previous record) and a taken
  /// dose consumes one unit of tracked stock.
  Future<DoseOutcome?> handle({
    required String? actionId,
    required String? payload,
  }) async {
    final outcome = switch (actionId) {
      NotificationActions.take => DoseOutcome.taken,
      NotificationActions.skip => DoseOutcome.skipped,
      _ => null,
    };
    if (outcome == null) return null;

    final dose = decodePayload(payload);
    if (dose == null) return null;

    Medication? medication;
    for (final m in _repository.data.medications) {
      if (m.id == dose.medicationId) medication = m;
    }
    if (medication == null) return null;

    final now = _clock();
    final update = outcome == DoseOutcome.taken
        ? _refillService.consumeDose(medication)?.copyWith(updatedAt: now)
        : null;
    await _repository.saveRecord(
      DoseRecord(
        id: _idGenerator(),
        medicationId: dose.medicationId,
        scheduledTime: dose.time,
        outcome: outcome,
        recordedAt: now,
        profileId: medication.profileId,
      ),
      medicationUpdate: update,
    );
    return outcome;
  }
}
