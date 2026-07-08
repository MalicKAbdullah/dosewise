import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/documents_file_store.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/data/i_file_store.dart';
import 'package:dose_wise/src/core/interfaces/key_derivation.dart';
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
    clock: ref.watch(clockProvider),
  ),
);
