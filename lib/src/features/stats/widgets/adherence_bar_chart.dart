import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/features/stats/services/adherence_calculator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reused across rebuilds/paints: constructing a [DateFormat] parses its
/// skeleton, wasteful to repeat for every axis label.
final DateFormat _weekdayFormat = DateFormat.E();

/// Bar chart of daily adherence (%). Works for the weekly Stats chart
/// (7 bars, weekday initials) and the medication-detail mini chart
/// (14 bars, sparser labels).
final class AdherenceBarChart extends StatelessWidget {
  const AdherenceBarChart({
    required this.days,
    this.height = 180,
    this.barColor,
    super.key,
  });

  final List<DayAdherence> days;
  final double height;

  /// Defaults to the theme accent.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = barColor ?? theme.colorScheme.primary;
    final trackColor = SuiteColors.of(context).surfaceAlt;
    final dense = days.length > 7;
    // With many bars, label every other day to avoid crowding.
    final labelStep = dense ? 2 : 1;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: 100,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final day = days[group.x];
                return BarTooltipItem(
                  day.scheduled == 0
                      ? 'No doses'
                      : '${day.taken}/${day.scheduled} taken',
                  theme.textTheme.labelSmall ?? const TextStyle(),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= days.length ||
                      index % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      dense
                          ? '${days[index].day.day}'
                          : _weekdayFormat
                              .format(days[index].day)
                              .substring(0, 1),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: ((days[i].rate ?? 0) * 100).clamp(0, 100),
                    width: dense ? 10 : 18,
                    borderRadius: BorderRadius.circular(dense ? 4 : 6),
                    color: days[i].scheduled == 0 ? Colors.transparent : color,
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: trackColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
