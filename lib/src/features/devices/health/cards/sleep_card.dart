part of '../health_cards.dart';

class HealthSleepCard extends StatelessWidget {
  const HealthSleepCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    this.totalDurationSeconds,
    required this.noDataLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final HealthSleepSummary? summary;
  final int? totalDurationSeconds;
  final String noDataLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sleep = summary;
    final stageStats = <(String, String)>[];
    final vitalStats = <(String, String)>[];
    if (sleep != null) {
      final deep = _sleepStageDuration(
        sleep,
        HealthSleepStageKind.deep,
        sleep.deepSleepDurationSeconds,
      );
      final light = _sleepStageDuration(
        sleep,
        HealthSleepStageKind.light,
        sleep.lightSleepDurationSeconds,
      );
      final rem = _sleepStageDuration(
        sleep,
        HealthSleepStageKind.rem,
        sleep.remSleepDurationSeconds,
      );
      if (deep != null) {
        stageStats.add((
          l10n.deviceHealthSleepDeep,
          _formatSleepSegmentDuration(deep),
        ));
      }
      if (light != null) {
        stageStats.add((
          l10n.deviceHealthSleepLight,
          _formatSleepSegmentDuration(light),
        ));
      }
      if (rem != null) {
        stageStats.add((
          l10n.deviceHealthSleepRem,
          _formatSleepSegmentDuration(rem),
        ));
      }
      final hrv = _averageSleepHrv(sleep);
      if (hrv != null) {
        vitalStats.add((l10n.deviceHealthSleepHrv, '$hrv ms'));
      }
      if (sleep.averageHeartRate != null) {
        vitalStats.add((
          l10n.deviceHealthSleepAverageHeartRate,
          '${sleep.averageHeartRate} bpm',
        ));
      }
      if (sleep.averageBloodOxygen != null) {
        vitalStats.add((
          l10n.deviceHealthSleepAverageBloodOxygen,
          '${sleep.averageBloodOxygen}%',
        ));
      }
    }
    return _HealthCard(
      height: null,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sleep == null
                ? '—'
                : _formatSleepDuration(
                    totalDurationSeconds ?? sleep.durationSeconds,
                  ),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            sleep == null
                ? noDataLabel
                : '${_formatSleepTime(sleep.startedAt)} – '
                      '${_formatSleepTime(sleep.endedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (stageStats.isNotEmpty || vitalStats.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (stageStats.isNotEmpty) _SleepCardStatsRow(entries: stageStats),
            if (vitalStats.isNotEmpty) ...[
              const SizedBox(height: 4),
              _SleepCardStatsRow(entries: vitalStats),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact vitality summary that follows the same hierarchy as the sleep
/// card: one prominent value followed by flat supporting facts. Vitality is a
/// daily score, not a 24-hour sampled signal, so a sparkline would imply a
/// precision the device does not provide.

class _SleepCardStatsRow extends StatelessWidget {
  const _SleepCardStatsRow({required this.entries});

  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, entry) in entries.indexed)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == entries.length - 1 ? 0 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.$1,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    entry.$2,
                    style: valueStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class HealthSleepTimeline extends StatelessWidget {
  const HealthSleepTimeline({
    required this.summary,
    required this.stageLabels,
    super.key,
  });

  final HealthSleepSummary summary;
  final Map<HealthSleepStageKind, String> stageLabels;

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.appColors;
    final colors = <HealthSleepStageKind, Color>{
      HealthSleepStageKind.awake: semanticColors.sleepAwake,
      HealthSleepStageKind.rem: semanticColors.sleepRem,
      HealthSleepStageKind.light: semanticColors.sleepLight,
      HealthSleepStageKind.deep: semanticColors.sleepDeep,
    };
    final visibleKinds = summary.stages
        .map((stage) => stage.kind)
        .where((kind) => kind != HealthSleepStageKind.unknown)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SleepStageLegend(
          stageLabels: stageLabels,
          colors: colors,
          visibleKinds: visibleKinds,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _SleepTimelinePainter(
              start: summary.startedAt,
              end: summary.endedAt,
              stages: summary.stages,
              colors: colors,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        _HealthXAxis(start: summary.startedAt, end: summary.endedAt),
      ],
    );
  }
}

class HealthSleepHrvChart extends StatelessWidget {
  const HealthSleepHrvChart({required this.summary, super.key});

  final HealthSleepSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final points = summary.hrvPoints.where((point) => point.value > 0).toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final pointValues = points.map((point) => point.value).toList();
    final average = (summary.averageHrv != null && summary.averageHrv! > 0)
        ? summary.averageHrv
        : _average(pointValues);
    final minimum = (summary.hrvMin != null && summary.hrvMin! > 0)
        ? summary.hrvMin
        : _minimum(pointValues);
    final maximum = (summary.hrvMax != null && summary.hrvMax! > 0)
        ? summary.hrvMax
        : _maximum(pointValues);
    final bounds = _sleepHrvBounds(
      minimum: minimum,
      maximum: maximum,
      values: pointValues,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SleepHrvStat(
                label: l10n.deviceHealthAverage,
                value: _formatHrv(average),
              ),
            ),
            Expanded(
              child: _SleepHrvStat(
                label: l10n.deviceHealthRange,
                value: minimum == null || maximum == null
                    ? '—'
                    : '${_formatHrvNumber(minimum)}–'
                          '${_formatHrvNumber(maximum)}',
              ),
            ),
          ],
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _SleepHrvPainter(
                start: summary.startedAt,
                end: summary.endedAt,
                points: points,
                bounds: bounds,
                color: theme.colorScheme.tertiary,
                gridColor: theme.colorScheme.outlineVariant,
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          _HealthXAxis(
            start: summary.startedAt,
            end: summary.endedAt,
            leadingWidth: _sleepHrvYAxisWidth,
          ),
        ],
      ],
    );
  }

  int? _average(List<int> values) {
    if (values.isEmpty) return null;
    return (values.reduce((left, right) => left + right) / values.length)
        .round();
  }

  int? _minimum(List<int> values) =>
      values.isEmpty ? null : values.reduce(math.min);

  int? _maximum(List<int> values) =>
      values.isEmpty ? null : values.reduce(math.max);

  String _formatHrv(int? value) =>
      value == null ? '—' : '${_formatHrvNumber(value)} ms';

  String _formatHrvNumber(int value) => value.toString();
}

class _SleepStageLegend extends StatelessWidget {
  const _SleepStageLegend({
    required this.stageLabels,
    required this.colors,
    required this.visibleKinds,
  });

  final Map<HealthSleepStageKind, String> stageLabels;
  final Map<HealthSleepStageKind, Color> colors;
  final Set<HealthSleepStageKind> visibleKinds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kinds = <HealthSleepStageKind>[
      HealthSleepStageKind.deep,
      HealthSleepStageKind.light,
      HealthSleepStageKind.rem,
      HealthSleepStageKind.awake,
    ].where(visibleKinds.contains);
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        for (final kind in kinds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: colors[kind],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                stageLabels[kind] ?? kind.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SleepTimelinePainter extends CustomPainter {
  _SleepTimelinePainter({
    required this.start,
    required this.end,
    required this.stages,
    required this.colors,
  });

  final DateTime start;
  final DateTime end;
  final List<HealthSleepStageSegment> stages;
  final Map<HealthSleepStageKind, Color> colors;

  static const _kinds = [
    HealthSleepStageKind.awake,
    HealthSleepStageKind.rem,
    HealthSleepStageKind.light,
    HealthSleepStageKind.deep,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const plotTop = 12.0;
    const plotBottom = 12.0;
    final plotWidth = math.max(1.0, size.width);
    final plotHeight = math.max(1.0, size.height - plotTop - plotBottom);
    final segments = _normalizedSleepStages(
      start: start,
      end: end,
      stages: stages,
    );
    final visibleKinds = _kinds
        .where((kind) => segments.any((stage) => stage.kind == kind))
        .toList(growable: false);
    if (visibleKinds.isEmpty) return;

    // Mi Fitness lays out entries next to each other using their real
    // durations.  Keep that same rule here instead of quantizing the report
    // into slots.  A sleep report can contain tiny gaps between packets; those
    // gaps are not rendered as white holes in the official chart, so the
    // visual widths are normalized from the stage durations and fill the plot.
    final laneHeight = plotHeight / visibleKinds.length;
    final stageThickness = math.min(34.0, math.max(24.0, laneHeight * .66));
    final cornerRadius = math.min(8.0, stageThickness / 2);
    final joinWidth = math.min(10.0, math.max(5.0, plotWidth * .012));

    double yFor(HealthSleepStageKind kind) {
      final index = visibleKinds.indexOf(kind);
      return plotTop + laneHeight * (index + .5);
    }

    final durations = segments
        .map(
          (stage) => math.max(
            1.0,
            stage.endedAt.difference(stage.startedAt).inMilliseconds.toDouble(),
          ),
        )
        .toList(growable: false);
    final totalDuration = durations.fold<double>(
      0,
      (total, duration) => total + duration,
    );
    if (totalDuration <= 0) return;

    final bands =
        <({HealthSleepStageSegment stage, double left, double right})>[];
    var elapsed = 0.0;
    for (var index = 0; index < segments.length; index++) {
      final left = plotWidth * elapsed / totalDuration;
      elapsed += durations[index];
      final right = index == segments.length - 1
          ? plotWidth
          : math.max(left + 1.0, plotWidth * elapsed / totalDuration);
      bands.add((stage: segments[index], left: left, right: right));
    }

    final bandPaint = Paint()..isAntiAlias = true;
    for (var index = 0; index < bands.length; index++) {
      final band = bands[index];
      final color = colors[band.stage.kind];
      if (color == null) continue;
      final centerY = yFor(band.stage.kind);
      final rect = Rect.fromLTRB(
        band.left,
        centerY - stageThickness / 2,
        band.right,
        centerY + stageThickness / 2,
      );
      bandPaint.color = color;
      canvas.drawPath(
        _sleepBandPath(
          rect,
          radius: cornerRadius,
          roundLeft: index == 0,
          roundRight: index == bands.length - 1,
        ),
        bandPaint,
      );
    }

    // The official renderer closes each stage with a shared transition path.
    // Draw that path over the flat-ended bands so the chart is one continuous
    // staircase ribbon: no rounded inner caps and no white gaps. The narrow
    // orthogonal transition is also where Mi Fitness blends the stage colors.
    for (var index = 1; index < bands.length; index++) {
      final previous = bands[index - 1];
      final current = bands[index];
      if (previous.stage.kind == current.stage.kind) continue;
      final previousColor = colors[previous.stage.kind];
      final currentColor = colors[current.stage.kind];
      if (previousColor == null || currentColor == null) continue;
      final previousY = yFor(previous.stage.kind);
      final currentY = yFor(current.stage.kind);
      final transitionPath = _sleepTransitionPath(
        x: current.left,
        fromY: previousY,
        toY: currentY,
        halfHeight: stageThickness / 2,
        width: joinWidth,
      );
      final top = math.min(previousY, currentY) - stageThickness / 2;
      final bottom = math.max(previousY, currentY) + stageThickness / 2;
      final topColor = previousY <= currentY ? previousColor : currentColor;
      final bottomColor = previousY <= currentY ? currentColor : previousColor;
      final transitionPaint = Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(Rect.fromLTRB(0, top, 1, bottom));
      canvas.drawPath(transitionPath, transitionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepTimelinePainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.stages != stages ||
      oldDelegate.colors != colors;
}

Path _sleepBandPath(
  Rect rect, {
  required double radius,
  required bool roundLeft,
  required bool roundRight,
}) {
  final corner = math.min(radius, math.min(rect.width, rect.height) / 2);
  final path = Path();
  path.moveTo(rect.left + (roundLeft ? corner : 0), rect.top);
  path.lineTo(rect.right - (roundRight ? corner : 0), rect.top);
  if (roundRight) {
    path.quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + corner);
  }
  path.lineTo(rect.right, rect.bottom - (roundRight ? corner : 0));
  if (roundRight) {
    path.quadraticBezierTo(
      rect.right,
      rect.bottom,
      rect.right - corner,
      rect.bottom,
    );
  }
  path.lineTo(rect.left + (roundLeft ? corner : 0), rect.bottom);
  if (roundLeft) {
    path.quadraticBezierTo(
      rect.left,
      rect.bottom,
      rect.left,
      rect.bottom - corner,
    );
  }
  path.lineTo(rect.left, rect.top + (roundLeft ? corner : 0));
  if (roundLeft) {
    path.quadraticBezierTo(rect.left, rect.top, rect.left + corner, rect.top);
  }
  path.close();
  return path;
}

Path _sleepTransitionPath({
  required double x,
  required double fromY,
  required double toY,
  required double halfHeight,
  required double width,
}) {
  final rect = Rect.fromLTRB(
    x - width / 2,
    math.min(fromY, toY) - halfHeight,
    x + width / 2,
    math.max(fromY, toY) + halfHeight,
  );
  return Path()..addRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(math.min(3.0, width / 2))),
  );
}

List<HealthSleepStageSegment> _normalizedSleepStages({
  required DateTime start,
  required DateTime end,
  required Iterable<HealthSleepStageSegment> stages,
}) {
  final sorted = [...stages]
    ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
  final normalized = <HealthSleepStageSegment>[];
  for (final stage in sorted) {
    if (stage.kind == HealthSleepStageKind.unknown) continue;
    final clippedStart = stage.startedAt.isBefore(start)
        ? start
        : stage.startedAt;
    final clippedEnd = stage.endedAt.isAfter(end) ? end : stage.endedAt;
    if (!clippedEnd.isAfter(clippedStart)) continue;
    final clipped = HealthSleepStageSegment(
      startedAt: clippedStart,
      endedAt: clippedEnd,
      kind: stage.kind,
    );
    if (normalized.isNotEmpty &&
        normalized.last.kind == clipped.kind &&
        clipped.startedAt.difference(normalized.last.endedAt).inMilliseconds <=
            1000) {
      final previous = normalized.last;
      normalized[normalized.length - 1] = HealthSleepStageSegment(
        startedAt: previous.startedAt,
        endedAt: clipped.endedAt.isAfter(previous.endedAt)
            ? clipped.endedAt
            : previous.endedAt,
        kind: previous.kind,
      );
    } else {
      normalized.add(clipped);
    }
  }
  return normalized;
}

class _SleepHrvStat extends StatelessWidget {
  const _SleepHrvStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _SleepHrvPainter extends CustomPainter {
  _SleepHrvPainter({
    required this.start,
    required this.end,
    required this.points,
    required this.bounds,
    required this.color,
    required this.gridColor,
    required this.labelStyle,
  });

  final DateTime start;
  final DateTime end;
  final List<HealthSleepHrvPoint> points;
  final ({double lower, double upper}) bounds;
  final Color color;
  final Color gridColor;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plottedPoints = _downsampleSleepHrvPoints(points);
    if (plottedPoints.isEmpty) return;
    final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    if (span <= 0) return;

    const plotTop = 6.0;
    const plotBottom = 6.0;
    final plotLeft = _sleepHrvYAxisWidth;
    final plotWidth = math.max(1.0, size.width - plotLeft);
    final plotHeight = math.max(1.0, size.height - plotTop - plotBottom);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final fraction = index / 2;
      final y = plotTop + plotHeight * fraction;
      canvas.drawLine(Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      final value = bounds.upper - (bounds.upper - bounds.lower) * fraction;
      final label = TextPainter(
        text: TextSpan(text: value.round().toString(), style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: plotLeft - _healthYAxisGap);
      label.paint(
        canvas,
        Offset(plotLeft - _healthYAxisGap - label.width, y - label.height / 2),
      );
    }

    double x(DateTime timestamp) {
      final elapsed =
          timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      return plotLeft + plotWidth * (elapsed / span).clamp(0.0, 1.0);
    }

    double y(int value) {
      final normalized =
          ((value - bounds.lower) / (bounds.upper - bounds.lower)).clamp(
            0.0,
            1.0,
          );
      return plotTop + plotHeight * (1 - normalized);
    }

    final path = Path();
    for (var index = 0; index < plottedPoints.length; index++) {
      final point = plottedPoints[index];
      final position = Offset(x(point.timestamp), y(point.value));
      final gap = index == 0
          ? Duration.zero
          : point.timestamp.difference(plottedPoints[index - 1].timestamp);
      if (index == 0 || gap > const Duration(hours: 2)) {
        path.moveTo(position.dx, position.dy);
      } else {
        path.lineTo(position.dx, position.dy);
      }
    }
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    final pointPaint = Paint()..color = color;
    for (final point in plottedPoints) {
      canvas.drawCircle(
        Offset(x(point.timestamp), y(point.value)),
        2.5,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SleepHrvPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.points != points ||
      oldDelegate.bounds != bounds ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelStyle != labelStyle;
}

({double lower, double upper}) _sleepHrvBounds({
  required int? minimum,
  required int? maximum,
  required Iterable<int> values,
}) {
  final valueList = values.where((v) => v > 0).toList(growable: false);
  final fallbackMinimum = valueList.isEmpty
      ? (maximum ?? 0)
      : valueList.reduce(_minInt);
  final fallbackMaximum = valueList.isEmpty
      ? (minimum ?? 0)
      : valueList.reduce(_maxInt);
  var lower = (minimum ?? fallbackMinimum).toDouble();
  var upper = (maximum ?? fallbackMaximum).toDouble();
  if (upper <= lower) {
    lower -= 1;
    upper += 1;
  }
  lower = lower.floorToDouble();
  upper = upper.ceilToDouble();
  if ((upper - lower).round().isOdd) upper += 1;
  return (lower: lower, upper: upper);
}

List<HealthSleepHrvPoint> _downsampleSleepHrvPoints(
  Iterable<HealthSleepHrvPoint> input,
) {
  final sorted = [...input]
    ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
  if (sorted.length <= 1) return sorted;

  const bucket = Duration(minutes: 10);
  final result = <HealthSleepHrvPoint>[sorted.first];
  var lastSelected = sorted.first.timestamp;
  for (final point in sorted.skip(1)) {
    if (point.timestamp.difference(lastSelected) >= bucket) {
      result.add(point);
      lastSelected = point.timestamp;
    }
  }

  final minimum = sorted.reduce(
    (left, right) => left.value <= right.value ? left : right,
  );
  final maximum = sorted.reduce(
    (left, right) => left.value >= right.value ? left : right,
  );
  for (final extreme in [minimum, maximum]) {
    if (!result.any((point) => point.timestamp == extreme.timestamp)) {
      result.add(extreme);
    }
  }
  result.sort((left, right) => left.timestamp.compareTo(right.timestamp));
  return result;
}

int _minInt(int left, int right) => left < right ? left : right;

int _maxInt(int left, int right) => left > right ? left : right;
