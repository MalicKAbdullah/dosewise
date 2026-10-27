import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:flutter/material.dart';

/// Month calendar colored by daily adherence: no doses → neutral,
/// 0–100% taken → accent ramp. Tap a day for its dose breakdown.
final class AdherenceHeatmap extends StatelessWidget {
  const AdherenceHeatmap({
    required this.days,
    required this.today,
    this.onDayTap,
    super.key,
  });

  /// One entry per day of the month, in day order.
  final List<DayAdherence> days;
  final DateTime today;
  final ValueChanged<DayAdherence>? onDayTap;

  static const List<String> _weekdayLabels = [
    'M', 'T', 'W', 'T', 'F', 'S', 'S', //
  ];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Monday-first calendar: pad the first week with blanks.
    final leading = days.first.day.weekday - DateTime.monday;
    final cells = <DayAdherence?>[
      ...List<DayAdherence?>.filled(leading, null),
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var week = 0; week < cells.length ~/ 7; week++)
          Padding(
            padding: EdgeInsets.only(top: week == 0 ? 0 : AppSpacing.xs),
            child: Row(
              children: [
                for (var i = week * 7; i < week * 7 + 7; i++)
                  Expanded(
                    child: _DayCell(
                      day: cells[i],
                      today: today,
                      onTap: onDayTap,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const _Legend(),
      ],
    );
  }
}

final class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.today, this.onTap});

  final DayAdherence? day;
  final DateTime today;
  final ValueChanged<DayAdherence>? onTap;

  @override
  Widget build(BuildContext context) {
    final data = day;
    if (data == null) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final rate = data.rate;
    final isFuture = data.day.isAfter(today);
    final isToday = data.day.year == today.year &&
        data.day.month == today.month &&
        data.day.day == today.day;

    final background = rate == null
        ? theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: isFuture ? 0.35 : 0.8)
        : accent.withValues(alpha: 0.15 + 0.85 * rate);
    // The fill is translucent accent over the card, so its lightness depends
    // on both the rate and the mode; the day number takes whichever ink
    // contrasts more with the colour actually shown.
    final c = SuiteColors.of(context);
    final shown = Color.alphaBlend(background, c.surface);
    final foreground = rate == null
        ? theme.colorScheme.onSurfaceVariant
        : _contrast(c.onAccent, shown) > _contrast(c.textPrimary, shown)
            ? c.onAccent
            : c.textPrimary;

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: InkWell(
            onTap: onTap == null || isFuture ? null : () => onTap!(data),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Container(
              decoration: isToday
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: accent, width: 1.6),
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                '${data.day.day}',
                style: AppTextStyles.numberSmall.copyWith(
                  color: isFuture
                      ? theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.45)
                      : foreground,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: theme.textTheme.labelSmall),
        const SizedBox(width: AppSpacing.sm),
        for (final alpha in const [0.15, 0.36, 0.57, 0.79, 1.0])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text('More', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}
