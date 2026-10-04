part of '../health_cards.dart';

class HealthDailyLineChart extends StatelessWidget {
  const HealthDailyLineChart({
    required this.days,
    required this.valueFor,
    required this.color,
    this.height = 220,
    this.showXAxis = true,
    this.compact = false,
    super.key,
  });

  final List<HealthDailySummary> days;
  final int? Function(HealthDailySummary day) valueFor;
  final Color color;
  final double height;
  final bool showXAxis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...days]
      ..sort((left, right) => left.date.compareTo(right.date));
    final visible = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _HealthDailyLinePainter(
              days: visible,
              valueFor: valueFor,
              color: color,
              gridColor: theme.colorScheme.outlineVariant,
              labelColor:
                  theme.textTheme.bodySmall?.color ??
                  theme.colorScheme.onSurfaceVariant,
              compact: compact,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (showXAxis && visible.isNotEmpty) ...[
          const SizedBox(height: 6),
          _HealthDailyXAxis(
            days: visible,
            compact: compact,
            leadingWidth: compact
                ? _healthCompactYAxisWidth
                : _healthYAxisWidth,
          ),
        ],
      ],
    );
  }
}



class HealthLineChart extends StatelessWidget {
  const HealthLineChart({
    required this.metric,
    required this.samples,
    required this.color,
    this.height = 220,
    this.start,
    this.end,
    super.key,
  });

  final List<HealthSample> samples;
  final XiaomiHealthMetric metric;
  final Color color;
  final double height;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: _HealthExactLineChart(
            metric: metric,
            samples: samples,
            color: color,
            gridColor: theme.colorScheme.outlineVariant,
            start: start,
            end: end,
          ),
        ),
        const SizedBox(height: 6),
        _HealthXAxis(start: start, end: end, leadingWidth: _healthYAxisWidth),
      ],
    );
  }
}

/// The same three time scales used by Mi Fitness' day/week/month health
/// pages. Detail charts keep the source points and render them through the
/// shared fl_chart line/area component; missing intervals remain gaps.
enum HealthChartPeriod { day, week, month }

class HealthOfficialRangeChart extends StatelessWidget {
  const HealthOfficialRangeChart({
    required this.metric,
    required this.period,
    required this.samples,
    required this.days,
    required this.color,
    this.start,
    this.end,
    this.height = 196,
    super.key,
  });

  final XiaomiHealthMetric metric;
  final HealthChartPeriod period;
  final List<HealthSample> samples;
  final List<HealthDailySummary> days;
  final Color color;
  final DateTime? start;
  final DateTime? end;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedStart = _resolvedStart();
    final resolvedEnd = _resolvedEnd(resolvedStart);
    final bars = _bars(resolvedStart, resolvedEnd);
    final axis = _adaptiveHealthAxis(
      metric,
      bars.whereType<_HealthRangeBar>().map((bar) => bar.average),
    );
    return Column(
      children: [
        SizedBox(
          height: height,
          child: _HealthRangeLineChart(
            metric: metric,
            period: period,
            bars: bars,
            color: color,
            gridColor: theme.colorScheme.outlineVariant,
            start: resolvedStart,
            end: resolvedEnd,
            axis: axis,
          ),
        ),
        const SizedBox(height: 6),
        _HealthOfficialXAxis(
          period: period,
          start: resolvedStart,
          end: resolvedEnd,
          days: days,
          leadingWidth: _healthYAxisWidth,
        ),
      ],
    );
  }

  DateTime _resolvedStart() {
    if (start != null) return start!;
    final latest = samples.isEmpty
        ? null
        : samples.reduce(
            (left, right) =>
                left.timestamp.isAfter(right.timestamp) ? left : right,
          );
    final anchor =
        latest?.timestamp ??
        (days.isEmpty ? null : days.last.date) ??
        DateTime.now();
    final local = anchor.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _resolvedEnd(DateTime resolvedStart) {
    if (end != null) return end!;
    return switch (period) {
      HealthChartPeriod.day => healthAddCalendarDays(resolvedStart, 1),
      HealthChartPeriod.week => healthAddCalendarDays(resolvedStart, 7),
      HealthChartPeriod.month => healthAddCalendarDays(resolvedStart, 31),
    };
  }

  List<_HealthRangeBar?> _bars(DateTime resolvedStart, DateTime resolvedEnd) {
    if (period == HealthChartPeriod.day) {
      final daySamples = [...samples]
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
      if (daySamples.isNotEmpty) {
        // Keep the source cadence. A sample at 08:03 must remain at 08:03;
        // placing it into one of 24/48 artificial slots loses the detail that
        // the official daily page exposes through its point-bars.
        return daySamples
            .map(
              (sample) => _HealthRangeBar(
                label: sample.timestamp,
                minimum: sample.value,
                maximum: sample.value,
                average: sample.value,
              ),
            )
            .toList(growable: false);
      }
      // The summary only carries min/max for the whole day with no timestamp,
      // so there is no honest x position to draw it at. Returning no bar keeps
      // the chart from inventing a point at noon; the 平均/最低/最高 summary
      // below the chart already communicates these values.
      return const <_HealthRangeBar?>[];
    }

    final sampleValuesByDay = <String, List<double>>{};
    for (final sample in samples) {
      final local = sample.timestamp.toLocal();
      final key = '${local.year}-${local.month}-${local.day}';
      sampleValuesByDay.putIfAbsent(key, () => <double>[]).add(sample.value);
    }
    return days
        .map((day) {
          final summary = healthMetricDailyValues(day, metric);
          final local = day.date.toLocal();
          final sampleValues =
              sampleValuesByDay['${local.year}-${local.month}-${local.day}'] ??
              const <double>[];
          final average = summary.average ?? _averageDouble(sampleValues);
          final minimum = summary.minimum ?? _minimumDouble(sampleValues);
          final maximum = summary.maximum ?? _maximumDouble(sampleValues);
          if (minimum == null && maximum == null && average == null) {
            return null;
          }
          // A day can legitimately carry only one edge (for example a single
          // minimum without an average), so every fallback chain must tolerate
          // the other two being null independently.
          final fallback = average ?? minimum ?? maximum!;
          return _HealthRangeBar(
            label: day.date,
            minimum: minimum ?? fallback,
            maximum: maximum ?? fallback,
            average:
                average ?? ((minimum ?? fallback) + (maximum ?? fallback)) / 2,
          );
        })
        .toList(growable: false);
  }
}

/// The compact home chart keeps the HEAD visual grammar: forty-eight rounded
/// half-hour slots, with each measured slot rendered as a coloured range.
/// This is deliberately a slot/range chart rather than a line chart: the
/// homepage communicates coverage and value spread at a glance, while the
/// detail page owns the precise time-series view.
class _HealthHomeTimelineChart extends StatelessWidget {
  const _HealthHomeTimelineChart({
    required this.metric,
    required this.samples,
    required this.color,
    required this.gridColor,
    required this.showGrid,
    this.start,
    this.end,
  });

  final XiaomiHealthMetric metric;
  final List<HealthSample> samples;
  final Color color;
  final Color gridColor;
  final bool showGrid;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final chartStart = start ?? healthDayStart(DateTime.now());
    final chartEnd = end ?? healthAddCalendarDays(chartStart, 1);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => BarChart(
        _healthHomeBarChartData(
          metric: metric,
          samples: samples,
          start: chartStart,
          end: chartEnd,
          color: color,
          gridColor: gridColor,
          showGrid: showGrid,
          chartWidth: constraints.maxWidth,
          labelColor: theme.colorScheme.onSurfaceVariant,
        ),
        duration: const Duration(milliseconds: 180),
        curve: Curves.linear,
      ),
    );
  }
}

BarChartData _healthHomeBarChartData({
  required XiaomiHealthMetric metric,
  required List<HealthSample> samples,
  required DateTime start,
  required DateTime end,
  required Color color,
  required Color gridColor,
  required bool showGrid,
  required double chartWidth,
  required Color labelColor,
}) {
  final axis = _healthAxis(metric);
  const slots = 48;
  final ranges = aggregateHealthRanges(
    samples,
    start: start,
    end: end,
    slots: slots,
  );
  final axisSpan = axis.maximum - axis.minimum;
  final slotWidth = chartWidth.isFinite ? chartWidth / slots : 6.0;
  final trackWidth = (slotWidth * .64)
      .clamp(2.0, showGrid ? 10.0 : 7.0)
      .toDouble();
  final minimumRange = axisSpan * (showGrid ? .045 : .04);
  final trackColor = gridColor.withValues(alpha: showGrid ? .30 : .18);
  final groups = <BarChartGroupData>[];
  for (var index = 0; index < slots; index++) {
    final range = ranges[index];
    final backDraw = BackgroundBarChartRodData(
      show: true,
      fromY: axis.minimum,
      toY: axis.maximum,
      color: trackColor,
    );
    if (range == null) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: axis.minimum,
              fromY: axis.minimum,
              width: trackWidth,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(trackWidth / 2),
              backDrawRodData: backDraw,
            ),
          ],
        ),
      );
      continue;
    }

    var minimum = range.minimum.clamp(axis.minimum, axis.maximum).toDouble();
    var maximum = range.maximum.clamp(axis.minimum, axis.maximum).toDouble();
    if (maximum - minimum < minimumRange) {
      // Keep a measured high value at its actual height. Centering a narrow
      // range and then filling the minimum visual height after clamping used
      // to move readings such as 218 bpm all the way to the 220 bpm ceiling.
      if (axis.maximum - maximum < minimumRange) {
        minimum = math.max(axis.minimum, maximum - minimumRange);
      } else {
        maximum = math.min(axis.maximum, minimum + minimumRange);
      }
    }
    groups.add(
      BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            fromY: minimum,
            toY: maximum,
            width: trackWidth,
            color: color,
            borderRadius: BorderRadius.circular(trackWidth / 2),
            backDrawRodData: backDraw,
          ),
        ],
      ),
    );
  }

  return BarChartData(
    barGroups: groups,
    alignment: BarChartAlignment.spaceEvenly,
    minY: axis.minimum,
    maxY: axis.maximum,
    baselineY: axis.minimum,
    gridData: FlGridData(
      show: showGrid,
      drawVerticalLine: false,
      horizontalInterval: axisSpan / 2,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: gridColor.withValues(alpha: .35), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _healthCompactYAxisWidth,
          interval: axisSpan / 2,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            space: _healthYAxisGap,
            child: Text(
              axis.format(value, includeUnit: false),
              maxLines: 1,
              style: TextStyle(color: labelColor, fontSize: 9),
            ),
          ),
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    barTouchData: const BarTouchData(enabled: false),
  );
}

class _HealthExactLineChart extends StatelessWidget {
  const _HealthExactLineChart({
    required this.metric,
    required this.samples,
    required this.color,
    required this.gridColor,
    required this.start,
    required this.end,
  });

  final XiaomiHealthMetric metric;
  final List<HealthSample> samples;
  final Color color;
  final Color gridColor;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final resolvedStart = start ?? healthDayStart(DateTime.now());
    final resolvedEnd = end ?? healthAddCalendarDays(resolvedStart, 1);
    final bars = [...samples]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return LineChart(
      _healthRangeChartData(
        metric: metric,
        period: HealthChartPeriod.day,
        bars: [
          for (final sample in bars)
            _HealthRangeBar(
              label: sample.timestamp,
              minimum: sample.value,
              maximum: sample.value,
              average: sample.value,
            ),
        ],
        color: color,
        gridColor: gridColor,
        start: resolvedStart,
        end: resolvedEnd,
        axis: _adaptiveHealthAxis(metric, bars.map((sample) => sample.value)),
        context: context,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
    );
  }
}

class _HealthRangeLineChart extends StatelessWidget {
  const _HealthRangeLineChart({
    required this.metric,
    required this.period,
    required this.bars,
    required this.color,
    required this.gridColor,
    required this.start,
    required this.end,
    required this.axis,
  });

  final XiaomiHealthMetric metric;
  final HealthChartPeriod period;
  final List<_HealthRangeBar?> bars;
  final Color color;
  final Color gridColor;
  final DateTime start;
  final DateTime end;
  final _HealthAxis axis;

  @override
  Widget build(BuildContext context) => LineChart(
    _healthRangeChartData(
      metric: metric,
      period: period,
      bars: bars,
      color: color,
      gridColor: gridColor,
      start: start,
      end: end,
      axis: axis,
      context: context,
    ),
    duration: const Duration(milliseconds: 180),
    curve: Curves.linear,
  );
}

LineChartData _healthRangeChartData({
  required XiaomiHealthMetric metric,
  required HealthChartPeriod period,
  required List<_HealthRangeBar?> bars,
  required Color color,
  required Color gridColor,
  required DateTime start,
  required DateTime end,
  required _HealthAxis axis,
  required BuildContext context,
}) {
  final daySpan = math.max(1, end.difference(start).inMilliseconds).toDouble();
  final spots = <FlSpot>[];
  final sourceBySpot = <_HealthRangeBar?>[];
  DateTime? previous;
  for (var index = 0; index < bars.length; index++) {
    final bar = bars[index];
    if (bar == null) {
      if (spots.isNotEmpty && spots.last != FlSpot.nullSpot) {
        spots.add(FlSpot.nullSpot);
        sourceBySpot.add(null);
      }
      previous = null;
      continue;
    }
    if (period == HealthChartPeriod.day &&
        previous != null &&
        bar.label.difference(previous).inMinutes > 15) {
      spots.add(FlSpot.nullSpot);
      sourceBySpot.add(null);
    }
    final x = period == HealthChartPeriod.day
        ? bar.label.difference(start).inMilliseconds /
              Duration.millisecondsPerHour
        : index + .5;
    spots.add(FlSpot(x, bar.average.clamp(axis.minimum, axis.maximum)));
    sourceBySpot.add(bar);
    previous = bar.label;
  }
  while (spots.isNotEmpty && spots.last == FlSpot.nullSpot) {
    spots.removeLast();
    sourceBySpot.removeLast();
  }
  final maxX = period == HealthChartPeriod.day
      ? daySpan / Duration.millisecondsPerHour
      : math.max(1, bars.length).toDouble();
  final line = LineChartBarData(
    spots: spots,
    color: color,
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
        colors: [color.withValues(alpha: .28), color.withValues(alpha: .025)],
      ),
    ),
  );
  final axisInterval = (axis.maximum - axis.minimum) / 2;
  final axisLabelStyle = Theme.of(context).textTheme.labelSmall
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
  return LineChartData(
    minX: 0,
    maxX: maxX,
    minY: axis.minimum,
    maxY: axis.maximum,
    baselineY: axis.minimum,
    lineBarsData: spots.isEmpty ? const [] : [line],
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: axisInterval,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: gridColor.withValues(alpha: .35), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _healthYAxisWidth,
          interval: axisInterval,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            space: _healthYAxisGap,
            child: Text(
              axis.format(value, includeUnit: false),
              maxLines: 1,
              style: axisLabelStyle,
            ),
          ),
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    lineTouchData: LineTouchData(
      enabled: spots.isNotEmpty,
      getTouchedSpotIndicator: (_, indexes) => [
        for (final _ in indexes)
          TouchedSpotIndicatorData(
            FlLine(color: color.withValues(alpha: .48), strokeWidth: 1),
            const FlDotData(show: false),
          ),
      ],
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) =>
            Theme.of(context).colorScheme.surfaceContainerHighest,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (touchedSpots) => [
          for (final touched in touchedSpots)
            if (touched.spotIndex >= 0 &&
                touched.spotIndex < sourceBySpot.length &&
                sourceBySpot[touched.spotIndex] != null)
              LineTooltipItem(
                _healthChartTooltipLabel(
                  sourceBySpot[touched.spotIndex]!,
                  metric,
                  period,
                  axis,
                ),
                TextStyle(color: color, fontWeight: FontWeight.w600),
              )
            else
              null,
        ],
      ),
    ),
  );
}

String _healthChartTooltipLabel(
  _HealthRangeBar bar,
  XiaomiHealthMetric metric,
  HealthChartPeriod period,
  _HealthAxis axis,
) {
  final label = period == HealthChartPeriod.day
      ? _formatHealthTime(bar.label)
      : _formatHealthDate(bar.label);
  return '$label · ${axis.format(bar.average)}';
}

class _HealthRangeBar {
  const _HealthRangeBar({
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.average,
  });

  final DateTime label;
  final double minimum;
  final double maximum;
  final double average;
}

class HealthMetricDailyValues {
  const HealthMetricDailyValues({this.average, this.minimum, this.maximum});

  final double? average;
  final double? minimum;
  final double? maximum;

  bool get hasValue => average != null || minimum != null || maximum != null;
}

HealthMetricDailyValues healthMetricDailyValues(
  HealthDailySummary day,
  XiaomiHealthMetric metric,
) => switch (metric) {
  XiaomiHealthMetric.heartRate => HealthMetricDailyValues(
    average: day.averageHeartRate?.toDouble(),
    minimum: day.minHeartRate?.toDouble(),
    maximum: day.maxHeartRate?.toDouble(),
  ),
  XiaomiHealthMetric.restingHeartRate => HealthMetricDailyValues(
    average: day.restingHeartRate?.toDouble(),
    minimum: day.restingHeartRate?.toDouble(),
    maximum: day.restingHeartRate?.toDouble(),
  ),
  XiaomiHealthMetric.bloodOxygen => HealthMetricDailyValues(
    average: day.averageBloodOxygen?.toDouble(),
    minimum: day.minBloodOxygen?.toDouble(),
    maximum: day.maxBloodOxygen?.toDouble(),
  ),
  XiaomiHealthMetric.stress => HealthMetricDailyValues(
    average: day.averageStress?.toDouble(),
    minimum: day.minStress?.toDouble(),
    maximum: day.maxStress?.toDouble(),
  ),
  XiaomiHealthMetric.vitality => HealthMetricDailyValues(
    average: (day.vitalityLast7Days ?? day.vitalityCurrent)?.toDouble(),
    minimum: (day.vitalityLast7Days ?? day.vitalityCurrent)?.toDouble(),
    maximum: (day.vitalityLast7Days ?? day.vitalityCurrent)?.toDouble(),
  ),
  XiaomiHealthMetric.activity => HealthMetricDailyValues(
    average: day.steps?.toDouble(),
    minimum: day.steps?.toDouble(),
    maximum: day.steps?.toDouble(),
  ),
  XiaomiHealthMetric.activeCalories => HealthMetricDailyValues(
    average: day.activeCalories?.toDouble(),
    minimum: day.activeCalories?.toDouble(),
    maximum: day.activeCalories?.toDouble(),
  ),
  XiaomiHealthMetric.sleep ||
  XiaomiHealthMetric.workout => const HealthMetricDailyValues(),
};

/// Calendar-day addition on wall-clock fields. [DateTime.add] with a fixed
/// 24-hour [Duration] shifts the result by an hour when the interval crosses
/// a daylight-saving boundary, which silently moves weekly/monthly windows.
DateTime healthAddCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days between two dates, independent of host timezone
/// offset changes (see [healthAddCalendarDays]).
int healthCalendarDaysBetween(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

double? _averageDouble(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left + right) / values.length;
}

double? _minimumDouble(List<double> values) =>
    values.isEmpty ? null : values.reduce(math.min);

double? _maximumDouble(List<double> values) =>
    values.isEmpty ? null : values.reduce(math.max);

class _HealthOfficialXAxis extends StatelessWidget {
  const _HealthOfficialXAxis({
    required this.period,
    required this.start,
    required this.end,
    required this.days,
    this.leadingWidth = 0,
  });

  final HealthChartPeriod period;
  final DateTime start;
  final DateTime end;
  final List<HealthDailySummary> days;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labels = switch (period) {
      HealthChartPeriod.day => [
        _formatChartTime(start),
        _formatChartTime(start.add(const Duration(hours: 6))),
        _formatChartTime(start.add(const Duration(hours: 12))),
        _formatChartTime(start.add(const Duration(hours: 18))),
        _formatChartEndTime(start, end),
      ],
      HealthChartPeriod.week || HealthChartPeriod.month => _periodDateLabels(),
    };
    return Row(
      children: [
        SizedBox(width: leadingWidth),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final label in labels) Text(label, style: style)],
          ),
        ),
      ],
    );
  }

  List<String> _periodDateLabels() {
    if (days.isEmpty) {
      return [_formatHealthDate(start), _formatHealthDate(end)];
    }
    final indices = period == HealthChartPeriod.week
        ? [0, days.length ~/ 2, days.length - 1]
        : [0, days.length ~/ 3, (days.length * 2) ~/ 3, days.length - 1];
    final result = <String>[];
    for (final index in indices) {
      if (index < 0 || index >= days.length) continue;
      final label = _formatHealthDate(days[index].date);
      if (!result.contains(label)) result.add(label);
    }
    return result;
  }
}

class _HealthXAxis extends StatelessWidget {
  const _HealthXAxis({
    required this.start,
    required this.end,
    this.compact = false,
    this.leadingWidth = 0,
  });

  final DateTime? start;
  final DateTime? end;
  final bool compact;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedStart = start ?? healthDayStart(DateTime.now());
    final resolvedEnd = end ?? healthAddCalendarDays(resolvedStart, 1);
    final middle = resolvedStart.add(
      Duration(
        milliseconds:
            (resolvedEnd.millisecondsSinceEpoch -
                resolvedStart.millisecondsSinceEpoch) ~/
            2,
      ),
    );
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 9 : null,
            );
    return Row(
      children: [
        SizedBox(width: leadingWidth),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatChartTime(resolvedStart), style: style),
              Text(_formatChartTime(middle), style: style),
              Text(
                _formatChartEndTime(resolvedStart, resolvedEnd),
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthDailyXAxis extends StatelessWidget {
  const _HealthDailyXAxis({
    required this.days,
    required this.compact,
    this.leadingWidth = 0,
  });

  final List<HealthDailySummary> days;
  final bool compact;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 9 : null,
            );
    return Row(
      children: [
        SizedBox(width: leadingWidth),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatHealthDate(days.first.date), style: style),
              if (days.length > 1)
                Text(
                  _formatHealthDate(days[days.length ~/ 2].date),
                  style: style,
                ),
              Text(_formatHealthDate(days.last.date), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthAxis {
  const _HealthAxis({
    required this.minimum,
    required this.maximum,
    this.unit = '',
  });

  final double minimum;
  final double maximum;
  final String unit;

  double get middle => (minimum + maximum) / 2;

  String format(double value, {bool includeUnit = true}) {
    final number = value.round().toString();
    return !includeUnit || unit.isEmpty ? number : '$number $unit';
  }
}

// Keep the axis column narrow enough that the plot owns most of the card. The
// gap is independent from the column width so labels do not touch the plot
// when the column is tightened.
const _healthYAxisWidth = 32.0;
const _healthCompactYAxisWidth = 26.0;
const _healthYAxisGap = 4.0;
const _sleepHrvYAxisWidth = 30.0;

class _HealthDailyLinePainter extends CustomPainter {
  _HealthDailyLinePainter({
    required this.days,
    required this.valueFor,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.compact,
  });

  final List<HealthDailySummary> days;
  final int? Function(HealthDailySummary day) valueFor;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final points = days
        .map((day) => (day: day, value: valueFor(day)))
        .where((point) => point.value != null)
        .toList(growable: false);
    if (points.isEmpty) return;

    final values = points.map((point) => point.value!).toList();
    final dataMinimum = values.reduce(math.min);
    final dataMaximum = values.reduce(math.max);
    final spread = dataMaximum - dataMinimum;
    final padding = math.max(1.0, spread * .15);
    final lower = dataMinimum - padding;
    final upper = dataMaximum + padding;
    final first = points.first.day.date;
    final last = points.last.day.date;
    final span = last.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
    final plotLeft = compact ? _healthCompactYAxisWidth : _healthYAxisWidth;
    final axisLabelWidth = plotLeft - _healthYAxisGap;
    final plotTop = compact ? 2.0 : 6.0;
    final plotBottom = compact ? 2.0 : 6.0;
    final plotWidth = math.max(1.0, size.width - plotLeft);
    final plotHeight = math.max(1.0, size.height - plotTop - plotBottom);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: compact ? .22 : .32)
      ..strokeWidth = 1;
    final textStyle = TextStyle(color: labelColor, fontSize: compact ? 9 : 10);

    for (var index = 0; index <= 2; index++) {
      final fraction = index / 2;
      final y = plotTop + plotHeight * fraction;
      canvas.drawLine(Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      final value = upper - (upper - lower) * fraction;
      final painter = TextPainter(
        text: TextSpan(text: value.round().toString(), style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: axisLabelWidth);
      painter.paint(
        canvas,
        Offset(
          plotLeft - _healthYAxisGap - painter.width,
          y - painter.height / 2,
        ),
      );
    }

    double x(DateTime date) {
      if (span <= 0) return plotLeft + plotWidth / 2;
      final elapsed =
          date.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
      return plotLeft + plotWidth * (elapsed / span).clamp(0.0, 1.0);
    }

    double y(int value) {
      final normalized = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
      return plotTop + plotHeight * (1 - normalized);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final position = Offset(x(point.day.date), y(point.value!));
      final gap = index == 0
          ? Duration.zero
          : point.day.date.difference(points[index - 1].day.date);
      if (index == 0 || gap > const Duration(days: 2)) {
        path.moveTo(position.dx, position.dy);
      } else {
        path.lineTo(position.dx, position.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = color;
    final radius = compact ? 2.4 : 3.2;
    for (final point in points) {
      canvas.drawCircle(
        Offset(x(point.day.date), y(point.value!)),
        radius,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthDailyLinePainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.valueFor != valueFor ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.compact != compact;
}



class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.child,
    required this.onPressed,
    this.height = 214,
  });

  final Widget child;
  final VoidCallback onPressed;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: height,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.all(constraints.maxWidth < 190 ? 12 : 18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}



class HealthRangeBucket {
  const HealthRangeBucket({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;
}

/// Divides a time interval into [slots] equal buckets and returns each
/// bucket's measured minimum and maximum.
List<HealthRangeBucket?> aggregateHealthRanges(
  Iterable<HealthSample> samples, {
  required DateTime start,
  required DateTime end,
  required int slots,
}) {
  if (slots <= 0) return const <HealthRangeBucket?>[];
  final buckets = List<List<double>>.generate(slots, (_) => <double>[]);
  final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  if (span <= 0) return List<HealthRangeBucket?>.filled(slots, null);
  for (final sample in samples) {
    if (!sample.isUsable ||
        sample.timestamp.isBefore(start) ||
        !sample.timestamp.isBefore(end)) {
      continue;
    }
    final elapsed =
        sample.timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    final index = (elapsed * slots ~/ span).clamp(0, slots - 1);
    buckets[index].add(sample.value);
  }
  return buckets
      .map((values) {
        if (values.isEmpty) return null;
        return HealthRangeBucket(
          minimum: values.reduce(math.min),
          maximum: values.reduce(math.max),
        );
      })
      .toList(growable: false);
}

_HealthAxis _healthAxis(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate || XiaomiHealthMetric.restingHeartRate =>
    const _HealthAxis(minimum: 30, maximum: 220, unit: 'bpm'),
  XiaomiHealthMetric.bloodOxygen => const _HealthAxis(
    minimum: 50,
    maximum: 100,
    unit: '%',
  ),
  XiaomiHealthMetric.stress => const _HealthAxis(minimum: 0, maximum: 100),
  XiaomiHealthMetric.vitality => const _HealthAxis(minimum: 0, maximum: 100),
  XiaomiHealthMetric.activity => const _HealthAxis(
    minimum: 0,
    maximum: 1000,
    unit: 'steps',
  ),
  XiaomiHealthMetric.activeCalories => const _HealthAxis(
    minimum: 0,
    maximum: 100,
    unit: 'kcal',
  ),
  XiaomiHealthMetric.sleep ||
  XiaomiHealthMetric.workout => const _HealthAxis(minimum: 0, maximum: 100),
};

/// Tightens the metric's natural axis to the visible data so a day with a
/// single 91 bpm reading no longer stretches from 30 to 220 with an empty
/// chart. Bounds are snapped to readable steps and kept inside the metric's
/// physical limits.
_HealthAxis _adaptiveHealthAxis(
  XiaomiHealthMetric metric,
  Iterable<double> values,
) {
  final base = _healthAxis(metric);
  final present = values
      .where((value) => value.isFinite)
      .toList(growable: false);
  if (present.isEmpty) return base;
  final dataMinimum = present.reduce(math.min);
  final dataMaximum = present.reduce(math.max);
  final span = dataMaximum - dataMinimum;

  final (double floor, double ceiling, double step) = switch (metric) {
    XiaomiHealthMetric.heartRate ||
    XiaomiHealthMetric.restingHeartRate => (30.0, 220.0, 10.0),
    XiaomiHealthMetric.bloodOxygen => (50.0, 100.0, 5.0),
    XiaomiHealthMetric.stress => (0.0, 100.0, 10.0),
    XiaomiHealthMetric.vitality => (0.0, 100.0, 10.0),
    XiaomiHealthMetric.activity => (0.0, double.infinity, 500.0),
    XiaomiHealthMetric.activeCalories => (0.0, double.infinity, 50.0),
    _ => (base.minimum, base.maximum, 0.0),
  };

  // A metric with no natural step (sleep/workout) keeps its base bounds.
  if (step <= 0) return base;

  var lower = dataMinimum;
  var upper = dataMaximum;
  // Give at least one readable step of headroom so a single value sits in the
  // middle rather than hugging an edge.
  final padding = math.max(step, span * .12);
  lower -= padding;
  upper += padding;
  lower = (lower / step).floorToDouble() * step;
  upper = (upper / step).ceilToDouble() * step;
  if (upper - lower < step * 2) {
    final middle = (lower + upper) / 2;
    lower = middle - step;
    upper = middle + step;
  }
  lower = lower.clamp(floor, ceiling);
  upper = upper.clamp(floor, ceiling);
  if (upper - lower < step) {
    if (lower <= floor) {
      upper = math.min(ceiling, floor + step);
    } else {
      lower = math.max(floor, upper - step);
    }
  }
  if (lower >= upper) return base;
  return _HealthAxis(minimum: lower, maximum: upper, unit: base.unit);
}

DateTime healthDayStart(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _formatSleepTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatChartTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatChartEndTime(DateTime start, DateTime end) {
  final localStart = start.toLocal();
  final localEnd = end.toLocal();
  if (localStart.hour == 0 &&
      localStart.minute == 0 &&
      localEnd.hour == 0 &&
      localEnd.minute == 0 &&
      localEnd.difference(localStart).inDays == 1) {
    return '24:00';
  }
  return _formatChartTime(end);
}

String _formatHealthDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}';
}

String _formatHealthTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _workoutCardName(BuildContext context, HealthWorkoutSummary workout) {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  String name(String chinese, String fallback) => zh ? chinese : fallback;
  if (workout.activityType == 22) {
    return switch (workout.subSportType) {
      2 || 207 => name('户外健走', 'Outdoor walking'),
      4 => name('登山', 'Mountaineering'),
      5 => name('越野跑', 'Trail running'),
      15 => name('徒步', 'Hiking'),
      _ => name('户外跑步', 'Outdoor running'),
    };
  }
  return switch (workout.activityType) {
    1 => name('户外跑步', 'Outdoor running'),
    2 => name('户外健走', 'Outdoor walking'),
    3 => name('室内跑步', 'Indoor running'),
    4 => name('登山', 'Mountaineering'),
    5 => name('越野跑', 'Trail running'),
    6 || 23 => name('户外骑行', 'Outdoor cycling'),
    7 => name('室内骑行', 'Indoor cycling'),
    8 => name('自由训练', 'Free training'),
    9 || 10 => name('游泳', 'Swimming'),
    11 => name('椭圆机', 'Elliptical'),
    13 => name('划船机', 'Rowing'),
    14 => name('跳绳', 'Jump rope'),
    15 => name('徒步', 'Hiking'),
    _ => name('运动', 'Workout'),
  };
}

String _formatSleepDuration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';

String _formatSleepSegmentDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatWorkoutDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _formatWorkoutDistance(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';

String _formatWorkoutPace(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return "$minutes'$remainder\"";
}

int? _sleepStageDuration(
  HealthSleepSummary summary,
  HealthSleepStageKind kind,
  int? reportedSeconds,
) {
  if (reportedSeconds != null && reportedSeconds > 0) {
    return reportedSeconds;
  }
  final seconds = summary.stages
      .where((stage) => stage.kind == kind)
      .fold<int>(0, (total, stage) => total + stage.durationSeconds);
  return seconds > 0 ? seconds : null;
}

int? _averageSleepHrv(HealthSleepSummary summary) {
  final average = summary.averageHrv;
  if (average != null) return average;
  final values = summary.hrvPoints.map((point) => point.value).toList();
  if (values.isEmpty) return null;
  return (values.reduce((left, right) => left + right) / values.length).round();
}

