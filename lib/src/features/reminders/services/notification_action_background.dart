import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/documents_file_store.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/features/reminders/services/notification_action_handler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles "Take" / "Skip" taps while the app process is dead or in the
/// background. flutter_local_notifications runs this in a dedicated
/// background isolate, so it bootstraps its own storage stack (secure
/// storage for the data key, the vault file, AES-GCM) instead of touching
/// any app singletons.
///
/// Must be a top-level function and survive tree-shaking in AOT builds,
/// hence the entry-point pragma.
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse response) async {
  // The background isolate has no bindings yet; both plugins used below
  // (flutter_secure_storage, path_provider) speak over platform channels
  // and need them.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = DoseWiseRepository(
      fileStore: DocumentsFileStore(),
      keyManager: const DataKeyManager(
        SecureStorageImpl(FlutterSecureStorage()),
      ),
    );
    await repository.initialize();
    await NotificationActionHandler(repository: repository).handle(
      actionId: response.actionId,
      payload: response.payload,
    );
  } catch (_) {
    // Never crash the background isolate; the dose can still be marked
    // in the app. The main isolate reloads the vault on resume, so a
    // successful write here is picked up as soon as the app is opened.
  }
}
