import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HealthDetailCard extends StatelessWidget {
  const HealthDetailCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

class ActivityMetricCard extends StatelessWidget {
  const ActivityMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.chart,
  });

  final String title;
  final String value;
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HealthDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
          if (chart != null) ...[const SizedBox(height: 8), chart!],
        ],
      ),
    );
  }
}

/// Flat label/value facts used for secondary health information. Keeping this
/// in the same visual grammar as the homepage sleep card avoids turning every
/// metric into another nested tile.
class HealthSummaryStats extends StatelessWidget {
  const HealthSummaryStats({super.key, required this.entries, this.columns});

  final List<(String, String)> entries;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (columns ?? entries.length).clamp(1, entries.length);
        const gap = 16.0;
        final width = (constraints.maxWidth - (count - 1) * gap) / count;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

enum HealthChartAxis { left, right }

const _chartYAxisReservedSize = 28.0;
const _chartYAxisTitleGap = 4.0;

class HealthChartSeries {
  const HealthChartSeries({
    required this.label,
    required this.unit,
    required this.color,
    required this.axis,
    required this.points,
  });

  final String label;
  final String unit;
  final Color color;
  final HealthChartAxis axis;
  final List<(DateTime, double)> points;
}

class HealthFlChart extends StatelessWidget {
  const HealthFlChart({
    super.key,
    required this.series,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<HealthChartSeries> series;
  final Color gridColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final points = series.expand((value) => value.points).toList();
    if (points.isEmpty) return const SizedBox.shrink();
    final first = points
        .map((value) => value.$1.millisecondsSinceEpoch)
        .reduce(math.min);
    final last = points
        .map((value) => value.$1.millisecondsSinceEpoch)
        .reduce(math.max);
    final span = math.max(1, last - first).toDouble();
    final bounds = <HealthChartAxis, (double, double)>{};
    for (final axis in HealthChartAxis.values) {
      final values = series
          .where((value) => value.axis == axis)
          .expand((value) => value.points.map((point) => point.$2))
          .where((value) => value.isFinite)
          .toList(growable: false);
      if (values.isEmpty) continue;
      final minimum = values.reduce(math.min);
      final maximum = values.reduce(math.max);
      final spread = math.max(1.0, maximum - minimum);
      final floor = minimum - spread * .08;
      var lower = (minimum >= 0 ? math.max(0.0, floor) : floor).floorToDouble();
      var upper = (maximum + spread * .08).ceilToDouble();
      if ((upper - lower).round().isOdd) upper += 1;
      if (lower >= upper) upper = lower + 2;
      bounds[axis] = (lower, upper);
    }
    final chartPoints = [
      for (final value in series) _buildChartPoints(value, first, span, bounds),
    ];
    final bars = [
      for (final (index, value) in series.indexed)
        LineChartBarData(
          spots: chartPoints[index].spots,
          color: value.color,
          barWidth: 2,
          isCurved: false,
          isStrokeCapRound: true,
          isStrokeJoinRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                value.color.withValues(alpha: .28),
                value.color.withValues(alpha: .025),
              ],
            ),
          ),
        ),
    ];
    final axisLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 10,
    );
    AxisTitles axisTitles(HealthChartAxis axis) {
      final range = bounds[axis];
      if (range == null) {
        return const AxisTitles(sideTitles: SideTitles(showTitles: false));
      }
      return AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _chartYAxisReservedSize,
          interval: .5,
          getTitlesWidget: (value, meta) {
            final actual = range.$1 + (range.$2 - range.$1) * value;
            return SideTitleWidget(
              meta: meta,
              space: _chartYAxisTitleGap,
              child: Text(
                _formatAxisLabel(actual),
                style: axisLabelStyle,
                textAlign: axis == HealthChartAxis.left
                    ? TextAlign.right
                    : TextAlign.left,
              ),
            );
          },
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        lineBarsData: bars,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: .5,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor.withValues(alpha: .35), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: axisTitles(HealthChartAxis.left),
          rightTitles: axisTitles(HealthChartAxis.right),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          getTouchedSpotIndicator: (_, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: gridColor.withValues(alpha: .48), strokeWidth: 1),
                const FlDotData(show: false),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => surfaceColor,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                _buildTooltipItem(
                  spot,
                  series: series,
                  chartPoints: chartPoints,
                ),
            ],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
    );
  }
}

class HealthChartPoints {
  const HealthChartPoints({required this.spots, required this.sourceIndexes});

  final List<FlSpot> spots;
  final List<int?> sourceIndexes;
}

HealthChartPoints _buildChartPoints(
  HealthChartSeries series,
  int first,
  double span,
  Map<HealthChartAxis, (double, double)> bounds,
) {
  final spots = <FlSpot>[];
  final sourceIndexes = <int?>[];
  DateTime? previous;
  for (final (index, point) in series.points.indexed) {
    if (previous != null &&
        point.$1.difference(previous).inMinutes > 15 &&
        spots.isNotEmpty &&
        spots.last != FlSpot.nullSpot) {
      spots.add(FlSpot.nullSpot);
      sourceIndexes.add(null);
    }
    spots.add(
      FlSpot(
        (point.$1.millisecondsSinceEpoch - first) / span,
        _normalizeValue(point.$2, bounds[series.axis]),
      ),
    );
    sourceIndexes.add(index);
    previous = point.$1;
  }
  return HealthChartPoints(spots: spots, sourceIndexes: sourceIndexes);
}

double _normalizeValue(double value, (double, double)? bounds) {
  if (bounds == null) return 0;
  final span = math.max(bounds.$2 - bounds.$1, 1e-9);
  return ((value - bounds.$1) / span).clamp(0.0, 1.0).toDouble();
}

LineTooltipItem? _buildTooltipItem(
  LineBarSpot spot, {
  required List<HealthChartSeries> series,
  required List<HealthChartPoints> chartPoints,
}) {
  if (spot.barIndex < 0 || spot.barIndex >= series.length) return null;
  final points = chartPoints[spot.barIndex].sourceIndexes;
  if (spot.spotIndex < 0 || spot.spotIndex >= points.length) return null;
  final sourceIndex = points[spot.spotIndex];
  if (sourceIndex == null ||
      sourceIndex >= series[spot.barIndex].points.length) {
    return null;
  }
  final sourcePoint = series[spot.barIndex].points[sourceIndex];
  final local = sourcePoint.$1.toLocal();
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final numStr = sourcePoint.$2.toStringAsFixed(
    sourcePoint.$2 == sourcePoint.$2.roundToDouble() ? 0 : 1,
  );
  return LineTooltipItem(
    '$clock · $numStr ${series[spot.barIndex].unit}',
    TextStyle(color: spot.bar.color, fontWeight: FontWeight.w600),
  );
}

String _formatAxisLabel(double value) {
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}
