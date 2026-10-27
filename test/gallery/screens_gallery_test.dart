import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/app.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/dose_log/screens/dose_log_screen.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/screens/medication_detail_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medication_form_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medications_screen.dart';
import 'package:dose_wise/src/features/onboarding/onboarding_flag.dart';
import 'package:dose_wise/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:dose_wise/src/features/settings/screens/settings_screen.dart';
import 'package:dose_wise/src/features/stats/screens/stats_screen.dart';
import 'package:dose_wise/src/features/today/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fakes.dart';

/// Design previews, only on request: `GALLERY=<out dir> flutter test
/// test/gallery`. Pixels differ per platform, so these are not CI goldens.
final String? _out = Platform.environment['GALLERY'];

Future<void> _loadFonts() async {
  Future<void> family(String name, List<Future<ByteData>> files) async {
    final loader = FontLoader(name);
    files.forEach(loader.addFont);
    await loader.load();
  }

  Future<ByteData> bundled(String file) =>
      rootBundle.load('packages/core_theme/fonts/$file');
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/Users/abdullah/development/flutter';
  await family(AppTextStyles.fontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      bundled('MonaSans-$w.ttf'),
  ]);
  await family(AppTextStyles.displayFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      bundled('MonaSansDisplay-$w.ttf'),
  ]);
  await family(AppTextStyles.monoFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold'])
      bundled('MonaSansMono-$w.ttf'),
  ]);
  await family('MaterialIcons', [
    Future.value(
      ByteData.sublistView(
        File(
          '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytesSync(),
      ),
    ),
  ]);
}

/// The fingerprint prompt is dismissed, so the lock stays up for the shot.
final class _DismissedAuth implements IDeviceAuth {
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Reversible stand-in for Argon2 so the shots render at once.
final class _FakeHasher implements IPasswordHasher {
  @override
  Future<String> hash(String password) async => 'h:$password';
  @override
  Future<bool> verify(String password, String stored) async =>
      stored == 'h:$password';
}

/// The appearance choice as the app loads it: [brightness] saved by the
/// Settings toggle.
Future<AppearanceController> _appearance(Brightness brightness) {
  SharedPreferences.setMockInitialValues({
    AppearanceController.storageKey: brightness.name,
  });
  return AppearanceController.load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_out!).createSync(recursive: true);
      File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });

void main() {
  // Tuesday 2026-07-07, 14:30.
  final now = DateTime(2026, 7, 7, 14, 30);

  Medication med(
    String id,
    String name,
    String dosage,
    MedicationForm form,
    int color,
    Schedule schedule, {
    int? stock,
  }) =>
      Medication(
        id: id,
        name: name,
        dosage: dosage,
        form: form,
        colorValue: color,
        startDate: DateTime(2026, 5, 1),
        schedule: schedule,
        currentStock: stock,
        lowStockThreshold: 7,
      );

  const everyDay = {1, 2, 3, 4, 5, 6, 7};
  final meds = [
    med(
        'm1',
        'Metformin',
        '500 mg',
        MedicationForm.tablet,
        0xFF0E9F55,
        const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)],
          weekdays: everyDay,
        ),
        stock: 42),
    med(
        'm2',
        'Lisinopril',
        '10 mg',
        MedicationForm.tablet,
        0xFF1F6FEB,
        const Schedule.weekly(
          times: [DoseTime(hour: 8, minute: 0)],
          weekdays: everyDay,
        ),
        stock: 5),
    med(
        'm3',
        'Vitamin D3',
        '1000 IU',
        MedicationForm.capsule,
        0xFFB58100,
        const Schedule.weekly(
          times: [DoseTime(hour: 13, minute: 0)],
          weekdays: everyDay,
        )),
    med(
        'm4',
        'Amoxicillin',
        '500 mg',
        MedicationForm.capsule,
        0xFF7341E6,
        const Schedule.weekly(
          times: [DoseTime(hour: 14, minute: 0), DoseTime(hour: 22, minute: 0)],
          weekdays: everyDay,
        )),
    med('m5', 'Ibuprofen', '200 mg', MedicationForm.tablet, 0xFFDC3B42,
        const Schedule.asNeeded()),
  ];

  Future<DoseWiseRepository> seeded() async {
    final repo = DoseWiseRepository(
      fileStore: InMemoryFileStore(),
      keyManager: DataKeyManager(InMemorySecureStorage()),
    );
    await repo.initialize();
    for (final m in meds) {
      await repo.upsertMedication(m);
    }
    var n = 0;
    for (var d = 40; d >= 0; d--) {
      final day = DateTime(now.year, now.month, now.day - d);
      for (final m in meds.take(4)) {
        for (final t in m.schedule.times) {
          final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
          if (at.isAfter(now)) continue;
          if (d == 0 && t.hour >= 13) continue;
          n++;
          if ((n * 7) % 11 == 0) continue; // missed
          await repo.saveRecord(
            DoseRecord(
              id: 'r$n',
              medicationId: m.id,
              scheduledTime: at,
              outcome: n % 13 == 0 ? DoseOutcome.skipped : DoseOutcome.taken,
              recordedAt: at.add(const Duration(minutes: 6)),
            ),
          );
        }
      }
    }
    return repo;
  }

  final screens = <String, Widget Function()>{
    'today': () => const TodayScreen(),
    'medications': () => const MedicationsScreen(),
    'stats': () => const StatsScreen(),
    'settings': () => const SettingsScreen(),
    'detail': () => const MedicationDetailScreen(medicationId: 'm2'),
    'form': () => const MedicationFormScreen(),
    'log': () => const DoseLogScreen(),
    'onboarding': () => const OnboardingScreen(),
  };

  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} ${brightness.name}', (tester) async {
        await tester.runAsync(_loadFonts);
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        addTearDown(tester.view.reset);
        final repo = await tester.runAsync(seeded);
        final appearance = await tester.runAsync(() => _appearance(brightness));
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo!),
              reminderServiceProvider.overrideWithValue(FakeReminderService()),
              clockProvider.overrideWithValue(() => now),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
              appearanceProvider.overrideWithValue(appearance!),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(
                  Brightness.light,
                  accent: AppAccents.dosewise,
                ),
                darkTheme: AppTheme.build(
                  Brightness.dark,
                  accent: AppAccents.dosewise,
                ),
                themeMode: appearance.mode,
                home: entry.value(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await _capture(tester, key, '${entry.key}-${brightness.name}');
      }, skip: _out == null);
    }
  }

  /// The real app, locked: [DoseWiseApp] with its AppLockGate over the
  /// navigator, themed by the saved appearance.
  Future<void> lockShot(
    WidgetTester tester,
    String name,
    Brightness brightness, {
    required bool biometric,
    Size size = const Size(390, 844),
    Future<void> Function()? act,
  }) async {
    await tester.runAsync(_loadFonts);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    addTearDown(tester.view.reset);
    final repo = await tester.runAsync(seeded);
    final appearance = await tester.runAsync(() => _appearance(brightness));
    final storage = InMemorySecureStorage();
    storage.values.addAll({
      '${lockStorageKey}_verifier': 'h:right',
      '${lockStorageKey}_recovery': 'h:key',
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo!),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          clockProvider.overrideWithValue(() => now),
          secureStorageProvider.overrideWithValue(storage),
          appearanceProvider.overrideWithValue(appearance!),
          deviceAuthProvider.overrideWithValue(_DismissedAuth()),
          passwordHasherProvider.overrideWithValue(_FakeHasher()),
          appLockEnabledOnLaunchProvider.overrideWithValue(true),
          appLockBiometricOnLaunchProvider.overrideWithValue(biometric),
          onboardingSeenOnLaunchProvider.overrideWithValue(true),
        ],
        child: RepaintBoundary(key: key, child: const DoseWiseApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    if (act != null) await act();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, name);
    await tester.pumpWidget(const SizedBox());
  }

  for (final b in Brightness.values) {
    final n = b.name;
    testWidgets('lock biometric $n', (t) async {
      await lockShot(t, 'lock-biometric-$n', b, biometric: true);
    }, skip: _out == null);
    testWidgets('lock password $n', (t) async {
      await lockShot(t, 'lock-password-$n', b, biometric: false);
    }, skip: _out == null);
    testWidgets('lock error $n', (t) async {
      await lockShot(
        t,
        'lock-error-$n',
        b,
        biometric: false,
        act: () async {
          await t.enterText(find.byType(TextField), 'nope');
          await t.pump();
          await t.tap(find.text('Unlock'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
        },
      );
    }, skip: _out == null);
    testWidgets('lock recovery $n', (t) async {
      await lockShot(
        t,
        'lock-recovery-$n',
        b,
        biometric: true,
        act: () async {
          await t.tap(find.text('Forgot password?'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
        },
      );
    }, skip: _out == null);
  }
  testWidgets('lock small light', (t) async {
    await lockShot(
      t,
      'lock-small-360x640-light',
      Brightness.light,
      biometric: true,
      size: const Size(360, 640),
    );
  }, skip: _out == null);
}
