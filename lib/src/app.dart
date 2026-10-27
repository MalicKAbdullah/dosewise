import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets code outside the widget tree (notification action handling in
/// main.dart) show confirmation snackbars.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final class DoseWiseApp extends ConsumerStatefulWidget {
  const DoseWiseApp({super.key});

  @override
  ConsumerState<DoseWiseApp> createState() => _DoseWiseAppState();
}

final class _DoseWiseAppState extends ConsumerState<DoseWiseApp> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Notification "Take"/"Skip" taps are persisted by a background
    // isolate; pick those writes up whenever the app comes back.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(appDataProvider.notifier).reloadFromDisk(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);
    final lock = ref.watch(lockControllerProvider);
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp.router(
        title: 'DoseWise',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.build(Brightness.light, accent: AppAccents.dosewise),
        darkTheme: AppTheme.build(Brightness.dark, accent: AppAccents.dosewise),
        themeMode: appearance.mode,
        routerConfig: router,
        // The gate covers the navigator with the lock screen while locked.
        builder: (context, child) => AppLockGate(
          controller: lock,
          appMark: const SuiteAppIcon(app: SuiteApp.dosewise, size: 64),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
