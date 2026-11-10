part of '../health_cards.dart';

class AdaptiveHealthCardWrap extends StatelessWidget {
  const AdaptiveHealthCardWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        const minCardWidth = 260.0;
        final width = constraints.maxWidth;
        final columnCount = ((width + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, 4);
        final cardWidth = (width - (columnCount - 1) * gap) / columnCount;
        final fullWidthActivity = width < 600 && columnCount > 1;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, child) in children.indexed)
              SizedBox(
                width: index == 0 && fullWidthActivity ? width : cardWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class ActivityOverviewCard extends StatelessWidget {
  const ActivityOverviewCard({
    required this.summary,
    required this.onPressed,
    super.key,
  });

  final HealthDailySummary? summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;
    final value = summary;
    final steps = value?.steps;
    // `totalCalories` is basal + active energy. It must not be presented as
    // the activity-calorie ring when the report omits active calories.
    final calories = value?.activeCalories;
    final standing = value?.standingHours;
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceHealthActivityOverview,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _ActivityRingsPainter(
                trackColor: colors.outlineVariant,
                colors: [colors.primary, colors.tertiary, colors.secondary],
                progress: [
                  _progress(calories, 500),
                  _progress(steps, 10000),
                  _progress(standing, 12),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActivityValue(
                label: l10n.deviceHealthActiveCalories,
                value: calories == null ? '—' : '$calories kcal',
                color: colors.primary,
              ),
              _ActivityValue(
                label: l10n.deviceHealthSteps,
                value: steps == null ? '—' : '$steps',
                color: colors.tertiary,
              ),
              _ActivityValue(
                label: l10n.deviceHealthStanding,
                value: standing == null ? '—' : '$standing h',
                color: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _progress(int? value, int target) =>
      value == null ? 0 : (value / target).clamp(0.0, 1.0);
}

/// A single-metric activity timeline. Xiaomi activity records are increments,
/// so the day view groups them into the same 24 hourly columns as the home
/// activity card instead of connecting sparse records into a false trace.
class ActivityTimelineChart extends StatelessWidget {
  const ActivityTimelineChart({
    required this.samples,
    required this.start,
    required this.end,
    required this.useCalories,
    this.height = 220,
    super.key,
  });

  final List<HealthActivitySample> samples;
  final DateTime start;
  final DateTime end;
  final bool useCalories;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActivityHourlyChart(
      values: _activityHourlyValues(
        samples,
        start: start,
        end: end,
        useCalories: useCalories,
      ),
      start: start,
      end: end,
      color: useCalories ? colors.primary : colors.tertiary,
      gridColor: colors.outlineVariant,
      height: height,
    );
  }
}

/// Renders one full-day activity series as twenty-four hourly columns
/// together with the same four time anchors used by the health cards.
class ActivityHourlyChart extends StatelessWidget {
  const ActivityHourlyChart({
    required this.values,
    required this.start,
    required this.end,
    required this.color,
    required this.gridColor,
    this.showYAxis = true,
    this.height = 188,
    super.key,
  });

  final List<double> values;
  final DateTime start;
  final DateTime end;
  final Color color;
  final Color gridColor;
  final bool showYAxis;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maximum = _evenAxisMaximum(
                  values.fold<double>(0, math.max) * 1.15,
                );
                final slotWidth = constraints.maxWidth / values.length;
                final barWidth = (slotWidth * .58).clamp(4.0, 14.0).toDouble();
                return BarChart(
                  _activityHourlyChartData(
                    hourly: values,
                    maximum: maximum,
                    barWidth: barWidth,
                    color: color,
                    gridColor: gridColor,
                    labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    showYAxis: showYAxis,
                  ),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.linear,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          _ActivityHourlyXAxis(
            start: start,
            end: end,
            leadingWidth: showYAxis ? _healthCompactYAxisWidth : 0,
          ),
        ],
      ),
    );
  }
}

BarChartData _activityHourlyChartData({
  required List<double> hourly,
  required double maximum,
  required double barWidth,
  required Color color,
  required Color gridColor,
  required Color labelColor,
  required bool showYAxis,
}) {
  final track = gridColor.withValues(alpha: .18);
  return BarChartData(
    barGroups: [
      for (final (index, value) in hourly.indexed)
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              fromY: 0,
              width: barWidth,
              color: value > 0 ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(barWidth / 2),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                fromY: 0,
                toY: maximum,
                color: track,
              ),
            ),
          ],
        ),
    ],
    alignment: BarChartAlignment.spaceEvenly,
    minY: 0,
    maxY: maximum,
    gridData: FlGridData(
      show: showYAxis,
      drawVerticalLine: false,
      horizontalInterval: maximum / 2,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: gridColor.withValues(alpha: .35), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showYAxis,
          reservedSize: showYAxis ? _healthCompactYAxisWidth : 0,
          interval: maximum / 2,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            space: _healthYAxisGap,
            child: Text(
              value.round().toString(),
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

List<double> _activityHourlyValues(
  List<HealthActivitySample> samples, {
  required DateTime start,
  required DateTime end,
  required bool useCalories,
}) {
  const slots = 24;
  final values = List<double>.filled(slots, 0);
  final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  if (span <= 0) return values;
  for (final sample in samples) {
    final timestamp = sample.timestamp.millisecondsSinceEpoch;
    if (timestamp < start.millisecondsSinceEpoch ||
        timestamp >= end.millisecondsSinceEpoch) {
      continue;
    }
    final value = useCalories ? sample.activeCalories : sample.steps;
    if (value == null || value < 0) continue;
    final slot = ((timestamp - start.millisecondsSinceEpoch) * slots ~/ span)
        .clamp(0, slots - 1);
    values[slot] += value;
  }
  return values;
}

double _evenAxisMaximum(double value) {
  var maximum = math.max(1, value).ceilToDouble();
  if (maximum.round().isOdd) maximum += 1;
  return maximum;
}

class _ActivityHourlyXAxis extends StatelessWidget {
  const _ActivityHourlyXAxis({
    required this.start,
    required this.end,
    this.leadingWidth = 0,
  });

  final DateTime start;
  final DateTime end;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final labels = [
      _activityAxisTime(start, 0, end),
      _activityAxisTime(start, 6, end),
      _activityAxisTime(start, 12, end),
      _activityAxisTime(start, 18, end),
      _activityAxisTime(start, 24, end),
    ];
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
}

String _activityAxisTime(DateTime start, int hours, DateTime end) {
  final value = start.add(Duration(hours: hours));
  if (value == end && hours == 24) return '24:00';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:00';
}

class _ActivityValue extends StatelessWidget {
  const _ActivityValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: textTheme.labelLarge),
      ],
    );
  }
}

class _ActivityRingsPainter extends CustomPainter {
  _ActivityRingsPainter({
    required this.trackColor,
    required this.colors,
    required this.progress,
  });

  final Color trackColor;
  final List<Color> colors;
  final List<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width * .42, (size.height - 8) * .80);
    final center = Offset(size.width / 2, size.height - 8);
    for (var index = 0; index < 3; index++) {
      final currentRadius = math.max(1.0, radius - index * 14.0);
      final track = Paint()
        ..color = trackColor.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9;
      final value = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9;
      final rect = Rect.fromCircle(center: center, radius: currentRadius);
      canvas.drawArc(rect, math.pi, math.pi, false, track);
      canvas.drawArc(rect, math.pi, math.pi * progress[index], false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}
