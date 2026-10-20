import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/core/data/data_key_manager.dart';
import 'package:dose_wise/src/core/data/dose_wise_repository.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/dose_log/screens/dose_log_screen.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/screens/medication_detail_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medication_form_screen.dart';
import 'package:dose_wise/src/features/medications/screens/medications_screen.dart';
import 'package:dose_wise/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:dose_wise/src/features/settings/screens/settings_screen.dart';
import 'package:dose_wise/src/features/stats/screens/stats_screen.dart';
import 'package:dose_wise/src/features/today/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo!),
              reminderServiceProvider.overrideWithValue(FakeReminderService()),
              clockProvider.overrideWithValue(() => now),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(
                  brightness,
                  accent: AppAccents.dosewise,
                ),
                home: entry.value(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(_out!).createSync(recursive: true);
          File('$_out/${entry.key}-${brightness.name}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
        });
      }, skip: _out == null);
    }
  }
}
