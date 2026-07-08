/// A concrete dose occurrence produced by the schedule engine: one
/// medication due at one specific moment.
final class ScheduledDose implements Comparable<ScheduledDose> {
  const ScheduledDose({required this.medicationId, required this.time});

  final String medicationId;
  final DateTime time;

  /// Stable identity used to match dose records to scheduled doses.
  String get key => doseKey(medicationId, time);

  static String doseKey(String medicationId, DateTime time) =>
      '$medicationId|${time.toIso8601String()}';

  @override
  int compareTo(ScheduledDose other) {
    final byTime = time.compareTo(other.time);
    return byTime != 0 ? byTime : medicationId.compareTo(other.medicationId);
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduledDose &&
      other.medicationId == medicationId &&
      other.time == time;

  @override
  int get hashCode => Object.hash(medicationId, time);

  @override
  String toString() => 'ScheduledDose($key)';
}
