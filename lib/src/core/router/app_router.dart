import 'package:dose_wise/src/core/widgets/app_shell.dart';
import 'package:dose_wise/src/features/backup/screens/backup_screen.dart';
import 'package:dose_wise/src/features/dose_log/screens/dose_log_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medication_detail_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medication_form_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medications_screen.dart';
import 'package:dose_wise/src/features/onboarding/onboarding_flag.dart';
import 'package:dose_wise/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:dose_wise/src/features/settings/screens/settings_screen.dart';
import 'package:dose_wise/src/features/stats/screens/stats_screen.dart';
import 'package:dose_wise/src/features/today/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const String today = '/today';
  static const String medications = '/medications';
  static const String newMedication = '/medications/new';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String log = '/log';
  static const String backup = '/backup';
  static const String onboarding = '/onboarding';

  static String medicationDetail(String id) => '/medications/$id';

  static String editMedication(String id) => '/medications/$id/edit';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.today,
    // First launch: everything funnels into onboarding until it is
    // completed or skipped (the flag is read via ref.read so completing
    // onboarding does not rebuild the router mid-navigation).
    redirect: (context, state) {
      final done = ref.read(onboardingCompleteProvider);
      if (!done && state.matchedLocation != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (done && state.matchedLocation == AppRoutes.onboarding) {
        return AppRoutes.today;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.medications,
                builder: (context, state) => const MedicationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newMedication,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MedicationFormScreen(),
      ),
      GoRoute(
        path: '/medications/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MedicationDetailScreen(
          medicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/medications/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MedicationFormScreen(
          medicationId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.log,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DoseLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.backup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BackupScreen(),
      ),
    ],
  );
});
