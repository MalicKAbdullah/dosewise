/// When during the day a dose is due. A pure-Dart, JSON-friendly
/// alternative to Flutter's [TimeOfDay] so the schedule engine and its
/// tests never import Flutter.
final class DoseTime implements Comparable<DoseTime> {
  const DoseTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24, 'hour must be 0-23'),
        assert(minute >= 0 && minute < 60, 'minute must be 0-59');

  /// Parses `"HH:mm"`.
  factory DoseTime.fromJson(String json) {
    final parts = json.split(':');
    return DoseTime(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  String toJson() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// The concrete [DateTime] for this time on [day] (local time).
  DateTime onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  int compareTo(DoseTime other) => minutesOfDay - other.minutesOfDay;

  @override
  bool operator ==(Object other) =>
      other is DoseTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toJson();
}

enum ScheduleType {
  /// Fixed times of day on selected weekdays.
  weekly,

  /// Fixed times of day, every N days anchored to the medication start date.
  interval,

  /// No schedule; the user logs doses manually.
  asNeeded,
}

/// Describes when a medication should be taken. Immutable and pure Dart.
final class Schedule {
  const Schedule.weekly({
    required this.times,
    required this.weekdays,
  })  : type = ScheduleType.weekly,
        intervalDays = 1;

  const Schedule.interval({
    required this.times,
    required int everyDays,
  })  : assert(everyDays >= 1, 'interval must be at least 1 day'),
        type = ScheduleType.interval,
        intervalDays = everyDays,
        weekdays = const {};

  const Schedule.asNeeded()
      : type = ScheduleType.asNeeded,
        times = const [],
        weekdays = const {},
        intervalDays = 1;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final type = ScheduleType.values.byName(json['type'] as String);
    final times = (json['times'] as List<dynamic>? ?? const [])
        .map((t) => DoseTime.fromJson(t as String))
        .toList();
    return switch (type) {
      ScheduleType.weekly => Schedule.weekly(
          times: times,
          weekdays: (json['weekdays'] as List<dynamic>? ?? const [])
              .map((d) => d as int)
              .toSet(),
        ),
      ScheduleType.interval => Schedule.interval(
          times: times,
          everyDays: json['intervalDays'] as int? ?? 1,
        ),
      ScheduleType.asNeeded => const Schedule.asNeeded(),
    };
  }

  final ScheduleType type;

  /// Times of day, used by [ScheduleType.weekly] and [ScheduleType.interval].
  final List<DoseTime> times;

  /// Selected weekdays ([DateTime.monday]..[DateTime.sunday]), weekly only.
  final Set<int> weekdays;

  /// Interval length in days, interval only.
  final int intervalDays;

  /// Whether any dose falls on the calendar day [day], given the schedule
  /// [anchor] date (the medication start date). Ignores active date range —
  /// callers are responsible for clamping to it.
  bool occursOn(DateTime day, DateTime anchor) {
    switch (type) {
      case ScheduleType.weekly:
        return weekdays.contains(day.weekday);
      case ScheduleType.interval:
        // Compare via UTC dates so day counts stay exact across DST shifts.
        final daysSinceAnchor = DateTime.utc(day.year, day.month, day.day)
            .difference(DateTime.utc(anchor.year, anchor.month, anchor.day))
            .inDays;
        return daysSinceAnchor >= 0 && daysSinceAnchor % intervalDays == 0;
      case ScheduleType.asNeeded:
        return false;
    }
  }

  /// Times of day in chronological order.
  List<DoseTime> get sortedTimes => [...times]..sort();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'times': sortedTimes.map((t) => t.toJson()).toList(),
        if (type == ScheduleType.weekly)
          'weekdays': (weekdays.toList()..sort()),
        if (type == ScheduleType.interval) 'intervalDays': intervalDays,
      };
}
