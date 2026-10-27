import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_backup/core_backup.dart';
import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_update/core_update.dart';
import 'package:dose_wise/src/core/app_info.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/documents_file_store.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/data/i_file_store.dart';
import 'package:dose_wise/src/core/interfaces/key_derivation.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/features/backup/services/backup_service.dart';
import 'package:dose_wise/src/features/medications/services/refill_service.dart';
import 'package:dose_wise/src/features/reminders/services/reminder_service.dart';
import 'package:dose_wise/src/features/schedule/services/dose_scheduler.dart';
import 'package:dose_wise/src/features/schedule/services/snooze_service.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:dose_wise/src/features/stats/services/report_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Injectable clock so widgets and providers are testable at a fixed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The System / Light / Dark choice. It is loaded before runApp so the first
/// frame (the lock screen included) has the right theme, so main() always
/// overrides this provider.
final appearanceProvider = Provider<AppearanceController>(
  (ref) => throw UnimplementedError('appearanceProvider is set in main()'),
);

final secureStorageProvider = Provider<ISecureStorage>(
  (ref) => const SecureStorageImpl(FlutterSecureStorage()),
);

final fileStoreProvider = Provider<IFileStore>(
  (ref) => DocumentsFileStore(),
);

final repositoryProvider = Provider<DoseWiseRepository>(
  (ref) => DoseWiseRepository(
    fileStore: ref.watch(fileStoreProvider),
    keyManager: DataKeyManager(ref.watch(secureStorageProvider)),
  ),
);

final doseSchedulerProvider =
    Provider<DoseScheduler>((ref) => const DoseScheduler());

final adherenceCalculatorProvider =
    Provider<AdherenceCalculator>((ref) => const AdherenceCalculator());

final snoozeServiceProvider =
    Provider<SnoozeService>((ref) => const SnoozeService());

final refillServiceProvider =
    Provider<RefillService>((ref) => const RefillService());

final reportBuilderProvider = Provider<AdherenceReportBuilder>(
  (ref) => AdherenceReportBuilder(
    calculator: ref.watch(adherenceCalculatorProvider),
  ),
);

/// No-op by default; main() overrides this with the
/// flutter_local_notifications implementation. Tests keep the no-op or
/// inject a fake.
final reminderServiceProvider =
    Provider<ReminderService>((ref) => const NoopReminderService());

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

/// Argon2id in production; tests override with a fast fake.
final keyDerivationProvider = Provider<IKeyDerivation>(
  (ref) => const Argon2KeyDerivation(KeyDerivationService()),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    keyDerivation: ref.watch(keyDerivationProvider),
    cipher: const CipherService(),
    appVersion: () => ref.read(appVersionProvider.future),
    clock: ref.watch(clockProvider),
  ),
);

/// Backup destination folder (shared engine). Android uses the Storage Access
/// Framework so a Google Drive folder can be picked; iOS uses app documents.
final backupFolderProvider = Provider<IBackupFolder>(
  (ref) =>
      Platform.isAndroid ? SafBackupFolder() : const AppDocumentsBackupFolder(),
);

/// Scheduled auto-backup engine (shared core_backup), namespaced to DoseWise.
final autoBackupServiceProvider = Provider<AutoBackupService>(
  (ref) => AutoBackupService(
    storage: ref.watch(secureStorageProvider),
    folder: ref.watch(backupFolderProvider),
    keyPrefix: 'dose_wise',
    fileLabel: 'DoseWise',
    fileExtension: BackupService.fileExtension,
    now: ref.watch(clockProvider),
  ),
);

/// Produces the encrypted `.dwbackup` bytes for the current data, reusing the
/// existing [BackupService]. Fed to the auto-backup engine and "Back up now".
final doseBackupProducerProvider = Provider<BackupProducer>((ref) {
  return (passphrase) async {
    final data = await ref.read(appDataProvider.future);
    final json = await ref
        .read(backupServiceProvider)
        .export(data: data, passphrase: passphrase!);
    return Uint8List.fromList(utf8.encode(json));
  };
});

// -- In-app update (core_update) ------------------------------------------

/// Secure-storage key for the auto-check preference.
const String updateAutoCheckKey = 'dose_wise_update_autocheck';

final updateServiceProvider = Provider<IUpdateService>(
  (_) => GithubUpdateService(owner: 'MalicKAbdullah', repo: 'dosewise'),
);

/// Auto-check preference (persisted; on by default). Toggle in Settings.
final updateAutoCheckProvider = FutureProvider<bool>(
  (ref) async =>
      await ref.watch(secureStorageProvider).read(key: updateAutoCheckKey) !=
      'false',
);

/// The pending update (null when disabled, up to date, or offline).
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (!await ref.watch(updateAutoCheckProvider.future)) return null;
  return ref.watch(updateServiceProvider).check();
});

/// Session-only dismissal of the update banner.
final updateDismissedProvider = StateProvider<bool>((_) => false);
