import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All profiles, in creation order.
final profilesProvider = Provider<List<Profile>>((ref) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  return data.profiles;
});

/// The profile whose data the UI currently shows.
final activeProfileProvider = Provider<Profile>((ref) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  return data.activeProfile;
});

/// Medications scoped to the active profile. Screens should read this
/// instead of `AppData.medications` (which spans all profiles).
final activeMedicationsProvider = Provider<List<Medication>>((ref) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  return data.medicationsFor(data.activeProfile.id);
});

/// Dose records scoped to the active profile.
final activeRecordsProvider = Provider<List<DoseRecord>>((ref) {
  final data = ref.watch(appDataProvider).valueOrNull ?? const AppData();
  return data.recordsFor(data.activeProfile.id);
});
