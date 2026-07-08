import 'dart:async';

import 'package:core_storage/core_storage.dart';
import 'package:dose_wise/src/app.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/app_lock/controllers/lock_controller.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/app_lock/services/local_auth_device_auth.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/onboarding/onboarding_flag.dart';
import 'package:dose_wise/src/features/reminders/services/local_notification_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A plain container (instead of a ProviderScope-owned one) so the
  // notification response callbacks below can reach app state.
  late final ProviderContainer container;

  final reminderService = LocalNotificationReminderService(
    onResponse: (actionId, payload) => unawaited(
      _applyNotificationAction(container, actionId, payload),
    ),
  );
  await reminderService.initialize();

  // Read the app-lock and onboarding flags before the first frame so the
  // app starts already locked / on onboarding (no flash of the wrong UI).
  const secureStorage = SecureStorageImpl(FlutterSecureStorage());
  final appLockEnabled = await LockController.readEnabled(secureStorage);
  final onboardingSeen = await OnboardingFlag.read(secureStorage);

  container = ProviderContainer(
    overrides: [
      reminderServiceProvider.overrideWithValue(reminderService),
      secureStorageProvider.overrideWithValue(secureStorage),
      deviceAuthProvider.overrideWithValue(LocalAuthDeviceAuth()),
      appLockEnabledOnLaunchProvider.overrideWithValue(appLockEnabled),
      onboardingSeenOnLaunchProvider.overrideWithValue(onboardingSeen),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DoseWiseApp(),
    ),
  );

  // If a notification action tap launched the app (rather than being
  // handled in the background isolate), apply it now.
  final launch = await reminderService.launchResponse();
  if (launch != null) {
    unawaited(_applyNotificationAction(container, launch.$1, launch.$2));
  }
}

Future<void> _applyNotificationAction(
  ProviderContainer container,
  String? actionId,
  String? payload,
) async {
  final outcome = await container
      .read(appDataProvider.notifier)
      .applyNotificationAction(actionId: actionId, payload: payload);
  if (outcome == null) return;
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        outcome == DoseOutcome.taken ? 'Dose marked as taken' : 'Dose skipped',
      ),
    ),
  );
}
