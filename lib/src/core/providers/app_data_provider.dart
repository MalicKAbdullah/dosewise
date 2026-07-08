import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/backup/services/backup_service.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/medication_colors.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:dose_wise/src/features/reminders/services/notification_action_handler.dart';
import 'package:dose_wise/src/features/reminders/services/reminder_service.dart';
import 'package:dose_wise/src/features/schedule/models/scheduled_dose.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDataProvider =
    AsyncNotifierProvider<AppDataNotifier, AppData>(AppDataNotifier.new);

/// Owns all mutations. Every mutation persists via the repository, then
/// reschedules reminders to reflect the new data.
final class AppDataNotifier extends AsyncNotifier<AppData> {
  static const int reminderHorizonDays = 7;

  DoseWiseRepository get _repository => ref.read(repositoryProvider);

  @override
  Future<AppData> build() async {
    final data = await _repository.initialize();
    await _syncReminders(data);
    return data;
  }

  /// Saves a medication, stamping [Medication.updatedAt] so backup merges
  /// can pick the newer version of a medication edited on two devices.
  Future<void> upsertMedication(Medication medication) => _mutate(
        (repo) => repo.upsertMedication(
          medication.copyWith(updatedAt: ref.read(clockProvider)()),
        ),
      );

  Future<void> deleteMedication(String medicationId) =>
      _mutate((repo) => repo.deleteMedication(medicationId));

  /// Archives or restores a medication. Archived medications keep their
  /// history but stop producing doses and reminders.
  Future<void> setArchived(String medicationId, bool archived) async {
    final medication = _medicationById(medicationId);
    if (medication == null) return;
    await upsertMedication(medication.copyWith(archived: archived));
  }

  /// Marks a scheduled dose taken or skipped, recording the actual time.
  /// Taking a dose consumes one unit of tracked stock.
  Future<void> markDose(ScheduledDose dose, DoseOutcome outcome) {
    final medication = _medicationById(dose.medicationId);
    final record = DoseRecord(
      id: ref.read(uuidProvider).v4(),
      medicationId: dose.medicationId,
      scheduledTime: dose.time,
      outcome: outcome,
      recordedAt: ref.read(clockProvider)(),
      profileId: medication?.profileId ?? Profile.defaultId,
    );
    final update = outcome == DoseOutcome.taken && medication != null
        ? ref.read(refillServiceProvider).consumeDose(medication)
        : null;
    return _mutate(
      (repo) => repo.saveRecord(
        record,
        medicationUpdate: _stamped(update),
      ),
    );
  }

  /// Logs a dose of an as-needed medication right now.
  Future<void> logAsNeededDose(Medication medication) {
    final now = ref.read(clockProvider)();
    final record = DoseRecord(
      id: ref.read(uuidProvider).v4(),
      medicationId: medication.id,
      scheduledTime: now,
      outcome: DoseOutcome.taken,
      recordedAt: now,
      profileId: medication.profileId,
    );
    final update = ref.read(refillServiceProvider).consumeDose(medication);
    return _mutate(
      (repo) => repo.saveRecord(record, medicationUpdate: _stamped(update)),
    );
  }

  /// Removes the taken/skipped record for a dose (undo). Undoing a taken
  /// dose returns one unit of tracked stock.
  Future<void> undoDose(String doseKey) {
    final data = state.valueOrNull ?? const AppData();
    DoseRecord? record;
    for (final r in data.records) {
      if (r.doseKey == doseKey) record = r;
    }
    Medication? update;
    if (record != null && record.outcome == DoseOutcome.taken) {
      final medication = _medicationById(record.medicationId);
      if (medication != null) {
        update = ref.read(refillServiceProvider).returnDose(medication);
      }
    }
    return _mutate(
      (repo) => repo.deleteRecord(doseKey, medicationUpdate: _stamped(update)),
    );
  }

  Medication? _stamped(Medication? update) =>
      update?.copyWith(updatedAt: ref.read(clockProvider)());

  /// Pushes a due/late dose back (default 15 minutes) — its spot on the
  /// timeline and its reminder move; adherence math is untouched.
  Future<void> snoozeDose(ScheduledDose dose) {
    final now = ref.read(clockProvider)();
    final snoozes = ref.read(snoozeServiceProvider).snooze(
          (state.valueOrNull ?? const AppData()).snoozes,
          dose,
          now,
        );
    return _mutate((repo) => repo.updateSnoozes(snoozes));
  }

  /// Adds [units] to a medication's stock (refill picked up).
  Future<void> refillMedication(String medicationId, int units) async {
    final medication = _medicationById(medicationId);
    if (medication == null || units <= 0) return;
    final refilled = ref.read(refillServiceProvider).refill(medication, units);
    await upsertMedication(refilled);
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      await ref.read(reminderServiceProvider).requestPermission();
    }
    final settings = (state.valueOrNull ?? const AppData())
        .settings
        .copyWith(remindersEnabled: enabled);
    await _mutate((repo) => repo.updateSettings(settings));
  }

  /// Creates a profile and switches to it.
  Future<void> addProfile(String name) async {
    final data = state.valueOrNull ?? const AppData();
    final profile = Profile(
      id: ref.read(uuidProvider).v4(),
      name: name.trim(),
      colorValue: MedicationColors
          .palette[data.profiles.length % MedicationColors.palette.length],
    );
    if (profile.name.isEmpty) return;
    await _mutate((repo) async {
      await repo.saveProfile(profile);
      return repo.setActiveProfile(profile.id);
    });
  }

  Future<void> renameProfile(String profileId, String name) async {
    final data = state.valueOrNull ?? const AppData();
    Profile? profile;
    for (final p in data.profiles) {
      if (p.id == profileId) profile = p;
    }
    final trimmed = name.trim();
    if (profile == null || trimmed.isEmpty) return;
    await _mutate((repo) => repo.saveProfile(profile!.copyWith(name: trimmed)));
  }

  /// Deletes a profile and everything belonging to it (medications, dose
  /// history, snoozes). The repository refuses to delete the last one.
  Future<void> deleteProfile(String profileId) =>
      _mutate((repo) => repo.deleteProfile(profileId));

  Future<void> switchProfile(String profileId) =>
      _mutate((repo) => repo.setActiveProfile(profileId));

  /// Applies a Take/Skip notification action delivered to the running app
  /// (foreground tap or launch-by-notification). Returns the persisted
  /// outcome, or null when the response was not actionable.
  Future<DoseOutcome?> applyNotificationAction({
    required String? actionId,
    required String? payload,
  }) async {
    await future;
    final handler = NotificationActionHandler(
      repository: _repository,
      refillService: ref.read(refillServiceProvider),
      idGenerator: ref.read(uuidProvider).v4,
      clock: ref.read(clockProvider),
    );
    final outcome = await handler.handle(actionId: actionId, payload: payload);
    if (outcome != null) {
      state = AsyncData(_repository.data);
      await _syncReminders(_repository.data);
    }
    return outcome;
  }

  /// Re-reads the vault from disk. Called when the app resumes, because
  /// the notification-action background isolate may have written records
  /// while this isolate held a stale in-memory copy.
  Future<void> reloadFromDisk() async {
    await future;
    final data = await _repository.reload();
    state = AsyncData(data);
    await _syncReminders(data);
  }

  /// Applies a decrypted backup: merge it into the current state or
  /// replace the state with it (see [BackupService.merge]).
  Future<void> importBackup(AppData imported, {required bool merge}) async {
    final current = state.valueOrNull ?? const AppData();
    final next = merge ? BackupService.merge(current, imported) : imported;
    await _mutate((repo) => repo.replaceAll(next));
  }

  /// Deletes the vault file and encryption key, then starts fresh.
  Future<void> eraseAll() async {
    await _repository.eraseAll();
    await ref.read(reminderServiceProvider).cancelAll();
    final data = await _repository.initialize();
    state = AsyncData(data);
  }

  Medication? _medicationById(String id) {
    final medications = state.valueOrNull?.medications ?? const [];
    for (final medication in medications) {
      if (medication.id == id) return medication;
    }
    return null;
  }

  Future<void> _mutate(
    Future<AppData> Function(DoseWiseRepository repo) action,
  ) async {
    await future; // Ensure the repository finished initializing.
    final next = await action(_repository);
    state = AsyncData(next);
    await _syncReminders(next);
  }

  /// Replaces pending notifications with the next week of unactioned
  /// doses, honoring per-medication opt-outs and active snoozes.
  Future<void> _syncReminders(AppData data) async {
    final service = ref.read(reminderServiceProvider);
    if (!data.settings.remindersEnabled) {
      await service.cancelAll();
      return;
    }
    final now = ref.read(clockProvider)();
    final snoozeService = ref.read(snoozeServiceProvider);
    final actionedKeys = {for (final r in data.records) r.doseKey};
    final medicationsById = {for (final m in data.medications) m.id: m};
    // Reminders cover every profile's doses, not just the active one; the
    // profile name is added once there is more than one profile.
    final profileNamesById = data.profiles.length > 1
        ? {for (final p in data.profiles) p.id: p.name}
        : const <String, String>{};
    final requests = ref
        .read(doseSchedulerProvider)
        .generate(
          medications:
              data.medications.where((m) => m.remindersEnabled).toList(),
          rangeStart: now,
          rangeEnd: now.add(const Duration(days: reminderHorizonDays)),
        )
        .where((d) => !actionedKeys.contains(d.key))
        .map(
          (d) => ScheduledDose(
            medicationId: d.medicationId,
            time: snoozeService.effectiveTime(d, data.snoozes),
          ),
        )
        .where((d) => d.time.isAfter(now))
        .map(
      (d) {
        final medication = medicationsById[d.medicationId]!;
        return ReminderRequest(
          dose: d,
          medication: medication,
          profileName: profileNamesById[medication.profileId],
        );
      },
    ).toList();
    await service.scheduleAll(requests);
  }
}
