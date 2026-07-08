import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:intl/intl.dart';

/// "8:00 AM"
String formatTime(DateTime time) => DateFormat.jm().format(time);

/// "8:00 AM" for a time-of-day without a date.
String formatDoseTime(DoseTime time) =>
    formatTime(DateTime(2000, 1, 1, time.hour, time.minute));

/// "Mon, Jun 29" or "Today" / "Yesterday" relative to [now].
String formatDay(DateTime day, {DateTime? now}) {
  if (now != null) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
  }
  return DateFormat.MMMEd().format(day);
}

/// "Jun 29, 2026"
String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

const List<String> _weekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// Human-readable one-line schedule summary, e.g.
/// "8:00 AM & 8:00 PM · Mon, Wed, Fri" or "Every 3 days at 9:00 AM".
String describeSchedule(Schedule schedule) {
  final times = schedule.sortedTimes.map(formatDoseTime).join(' & ');
  switch (schedule.type) {
    case ScheduleType.weekly:
      final days = schedule.weekdays.length == 7
          ? 'every day'
          : (schedule.weekdays.toList()..sort())
              .map((d) => _weekdayShort[d - 1])
              .join(', ');
      return '$times · $days';
    case ScheduleType.interval:
      final every = schedule.intervalDays == 1
          ? 'Every day'
          : 'Every ${schedule.intervalDays} days';
      return '$every at $times';
    case ScheduleType.asNeeded:
      return 'As needed';
  }
}
