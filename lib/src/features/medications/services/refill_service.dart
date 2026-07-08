import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';

/// Pure-Dart supply (refill) transitions. Stock only moves for
/// medications that track it ([Medication.currentStock] non-null).
final class RefillService {
  const RefillService();

  /// One unit consumed (dose marked taken / as-needed dose logged).
  /// Returns null when nothing changes (tracking off or already empty).
  Medication? consumeDose(Medication medication) {
    final stock = medication.currentStock;
    if (stock == null || stock <= 0) return null;
    return medication.copyWith(currentStock: stock - 1);
  }

  /// One unit returned (a taken dose was undone). Returns null when the
  /// medication does not track stock.
  Medication? returnDose(Medication medication) {
    final stock = medication.currentStock;
    if (stock == null) return null;
    return medication.copyWith(currentStock: stock + 1);
  }

  /// Adds [units] to the current stock (a refill was picked up). Starts
  /// tracking from zero when tracking was off.
  Medication refill(Medication medication, int units) {
    assert(units > 0, 'refill units must be positive');
    return medication.copyWith(
      currentStock: (medication.currentStock ?? 0) + units,
    );
  }

  /// Estimated days of supply left given how many doses a day the
  /// schedule calls for. Null when unknown (tracking off or no daily dose).
  int? daysOfSupplyLeft(Medication medication) {
    final stock = medication.currentStock;
    if (stock == null) return null;
    final schedule = medication.schedule;
    final perDay = switch (schedule.type) {
      ScheduleType.weekly =>
        schedule.times.length * schedule.weekdays.length / 7,
      ScheduleType.interval => schedule.times.length / schedule.intervalDays,
      ScheduleType.asNeeded => 0.0,
    };
    if (perDay <= 0) return null;
    return stock ~/ perDay;
  }
}
