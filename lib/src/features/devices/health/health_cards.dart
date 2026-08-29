import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

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
    final calories = value?.activeCalories ?? value?.calories;
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

/// The large activity graphic used on the activity detail page.
///
/// The values are optional so the graphic can still show the three tracks when
/// a period has no synchronized data. When [summary] is supplied, its daily
/// values are used unless an explicit value is provided.
class ActivityRingsChart extends StatelessWidget {
  const ActivityRingsChart({
    this.summary,
    this.steps,
    this.activeCalories,
    this.standingHours,
    this.stepsTarget = 10000,
    this.activeCaloriesTarget = 500,
    this.standingTarget = 12,
    this.height = 220,
    super.key,
  });

  final HealthDailySummary? summary;
  final int? steps;
  final int? activeCalories;
  final int? standingHours;
  final int stepsTarget;
  final int activeCaloriesTarget;
  final int standingTarget;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedSteps = steps ?? summary?.steps;
    final resolvedCalories =
        activeCalories ?? summary?.activeCalories ?? summary?.calories;
    final resolvedStanding = standingHours ?? summary?.standingHours;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ActivityRingsPainter(
          trackColor: colors.outlineVariant,
          colors: [colors.primary, colors.tertiary, colors.secondary],
          progress: [
            _progress(resolvedCalories, activeCaloriesTarget),
            _progress(resolvedSteps, stepsTarget),
            _progress(resolvedStanding, standingTarget),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  double _progress(int? value, int target) =>
      value == null ? 0 : (value / target).clamp(0.0, 1.0);
}

class HealthMetricCard extends StatelessWidget {
  const HealthMetricCard({
    required this.metric,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.detail,
    required this.samples,
    required this.onPressed,
    this.chartStart,
    this.chartEnd,
    super.key,
  });

  final XiaomiHealthMetric metric;
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String detail;
  final List<HealthSample> samples;
  final VoidCallback onPressed;
  final DateTime? chartStart;
  final DateTime? chartEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
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
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(detail, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HealthYAxis(metric: metric, compact: true),
                      Expanded(
                        child: CustomPaint(
                          painter: _HealthSparklinePainter(
                            metric: metric,
                            samples: samples,
                            color: color,
                            gridColor: theme.colorScheme.outlineVariant,
                            start: chartStart,
                            end: chartEnd,
                            showGrid: false,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _HealthXAxis(
                  start: chartStart,
                  end: chartEnd,
                  compact: true,
                  leadingWidth: _healthCompactYAxisWidth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HealthDailyMetricCard extends StatelessWidget {
  const HealthDailyMetricCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.detail,
    required this.days,
    required this.valueFor,
    required this.onPressed,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String detail;
  final List<HealthDailySummary> days;
  final int? Function(HealthDailySummary day) valueFor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
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
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(detail, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Expanded(
            child: HealthDailyLineChart(
              days: days,
              valueFor: valueFor,
              color: color,
              height: 72,
              showXAxis: false,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class HealthAbnormalHeartRateCard extends StatelessWidget {
  const HealthAbnormalHeartRateCard({
    required this.title,
    required this.records,
    required this.highLabel,
    required this.lowLabel,
    required this.recordLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final List<HealthAbnormalHeartRateRecord> records;
  final String highLabel;
  final String lowLabel;
  final String recordLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...records]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final latest = sorted.isEmpty ? null : sorted.last;
    final kind = latest == null
        ? ''
        : switch (latest.kind) {
            HealthAbnormalHeartRateKind.high => highLabel,
            HealthAbnormalHeartRateKind.low => lowLabel,
            HealthAbnormalHeartRateKind.unknown => '',
          };
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
          const Spacer(),
          Text(
            latest == null ? '—' : '${latest.value} bpm',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            latest == null
                ? recordLabel
                : '$kind · ${records.length} $recordLabel',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class HealthAbnormalHealthCard extends StatelessWidget {
  const HealthAbnormalHealthCard({
    required this.title,
    required this.records,
    required this.labelFor,
    required this.valueFor,
    required this.recordLabel,
    required this.onPressed,
    this.icon = Icons.warning_amber_outlined,
    this.color = Colors.red,
    super.key,
  });

  final String title;
  final List<HealthAbnormalHealthRecord> records;
  final String Function(HealthAbnormalHealthRecord record) labelFor;
  final String Function(HealthAbnormalHealthRecord record) valueFor;
  final String recordLabel;
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...records]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final latest = sorted.isEmpty ? null : sorted.last;
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
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
          const Spacer(),
          Text(
            latest == null ? '—' : valueFor(latest),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            latest == null
                ? recordLabel
                : '${labelFor(latest)} · ${records.length} $recordLabel',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

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
          _HealthDailyXAxis(days: visible, compact: compact),
        ],
      ],
    );
  }
}

class HealthSleepCard extends StatelessWidget {
  const HealthSleepCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.noDataLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final HealthSleepSummary? summary;
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
      onPressed: onPressed,
      child: Column(
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
            sleep == null ? '—' : _formatSleepDuration(sleep.durationSeconds),
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
    final colors = <HealthSleepStageKind, Color>{
      // Mi Fitness SleepStageStyle's default palette.
      HealthSleepStageKind.awake: const Color(0xFFB8C1D5),
      HealthSleepStageKind.rem: const Color(0xFF47BEFF),
      HealthSleepStageKind.light: const Color(0xFF3986F6),
      HealthSleepStageKind.deep: const Color(0xFF2231B6),
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
    final points = [...summary.hrvPoints]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final pointValues = points.map((point) => point.value).toList();
    final average = summary.averageHrv ?? _average(pointValues);
    final minimum = summary.hrvMin ?? _minimum(pointValues);
    final maximum = summary.hrvMax ?? _maximum(pointValues);
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SleepHrvYAxis(lower: bounds.lower, upper: bounds.upper),
                Expanded(
                  child: CustomPaint(
                    painter: _SleepHrvPainter(
                      start: summary.startedAt,
                      end: summary.endedAt,
                      points: points,
                      bounds: bounds,
                      color: theme.colorScheme.tertiary,
                      gridColor: theme.colorScheme.outlineVariant,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
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

class _SleepHrvYAxis extends StatelessWidget {
  const _SleepHrvYAxis({required this.lower, required this.upper});

  final double lower;
  final double upper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final middle = (lower + upper) / 2;
    String format(double value) => value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return SizedBox(
      width: _sleepHrvYAxisWidth,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 6,
          right: _healthYAxisGap,
          bottom: 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(format(upper), maxLines: 1, style: style),
            Text(format(middle), maxLines: 1, style: style),
            Text(format(lower), maxLines: 1, style: style),
          ],
        ),
      ),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HealthYAxis(metric: metric),
              Expanded(
                child: CustomPaint(
                  painter: _HealthSparklinePainter(
                    metric: metric,
                    samples: samples,
                    color: color,
                    gridColor: theme.colorScheme.outlineVariant,
                    start: start,
                    end: end,
                    showGrid: true,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _HealthXAxis(start: start, end: end, leadingWidth: _healthYAxisWidth),
      ],
    );
  }
}

/// The same three time scales used by Mi Fitness' day/week/month health
/// pages. The official heart-rate chart is a range-bar chart rather than a
/// smoothed line chart, so the detail pages use [HealthOfficialRangeChart].
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
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HealthYAxis(metric: metric),
              Expanded(
                child: CustomPaint(
                  painter: _HealthOfficialRangePainter(
                    bars: bars,
                    axis: _healthAxis(metric),
                    color: color,
                    gridColor: theme.colorScheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
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
      HealthChartPeriod.day => resolvedStart.add(const Duration(days: 1)),
      HealthChartPeriod.week => resolvedStart.add(const Duration(days: 7)),
      HealthChartPeriod.month => resolvedStart.add(const Duration(days: 31)),
    };
  }

  List<_HealthRangeBar?> _bars(DateTime resolvedStart, DateTime resolvedEnd) {
    if (period == HealthChartPeriod.day) {
      const slotCount = 48;
      final ranges = aggregateHealthRanges(
        samples,
        start: resolvedStart,
        end: resolvedEnd,
        slots: slotCount,
      );
      HealthHourRange? dailyFallback;
      for (final day in days) {
        if (!_sameHealthDate(day.date, resolvedStart)) {
          continue;
        }
        final summary = healthMetricDailyValues(day, metric);
        final minimum = summary.minimum ?? summary.average;
        final maximum = summary.maximum ?? summary.average;
        if (minimum != null && maximum != null) {
          dailyFallback = HealthHourRange(minimum: minimum, maximum: maximum);
          break;
        }
      }
      final span = resolvedEnd.difference(resolvedStart);
      return List<_HealthRangeBar?>.generate(slotCount, (index) {
        final range =
            ranges[index] ?? (index == slotCount ~/ 2 ? dailyFallback : null);
        return range == null
            ? null
            : _HealthRangeBar(
                label: resolvedStart.add(
                  Duration(
                    milliseconds: span.inMilliseconds * index ~/ slotCount,
                  ),
                ),
                minimum: range.minimum,
                maximum: range.maximum,
                average: (range.minimum + range.maximum) / 2,
              );
      }, growable: false);
    }

    return days
        .map((day) {
          final summary = healthMetricDailyValues(day, metric);
          final daySamples = samples.where(
            (sample) => _sameHealthDate(sample.timestamp, day.date),
          );
          final sampleValues = daySamples
              .map((sample) => sample.value)
              .toList();
          final average = summary.average ?? _averageDouble(sampleValues);
          final minimum = summary.minimum ?? _minimumDouble(sampleValues);
          final maximum = summary.maximum ?? _maximumDouble(sampleValues);
          if (minimum == null && maximum == null && average == null) {
            return null;
          }
          return _HealthRangeBar(
            label: day.date,
            minimum: minimum ?? average!,
            maximum: maximum ?? average!,
            average: average ?? ((minimum! + maximum!) / 2),
          );
        })
        .toList(growable: false);
  }
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
    average: day.vitalityCurrent?.toDouble(),
    minimum: day.vitalityCurrent?.toDouble(),
    maximum: day.vitalityCurrent?.toDouble(),
  ),
  XiaomiHealthMetric.activity => HealthMetricDailyValues(
    average: day.steps?.toDouble(),
    minimum: day.steps?.toDouble(),
    maximum: day.steps?.toDouble(),
  ),
  XiaomiHealthMetric.activeCalories => HealthMetricDailyValues(
    average: (day.activeCalories ?? day.calories)?.toDouble(),
    minimum: (day.activeCalories ?? day.calories)?.toDouble(),
    maximum: (day.activeCalories ?? day.calories)?.toDouble(),
  ),
  XiaomiHealthMetric.sleep ||
  XiaomiHealthMetric.workout => const HealthMetricDailyValues(),
};

bool _sameHealthDate(DateTime left, DateTime right) {
  final localLeft = left.toLocal();
  final localRight = right.toLocal();
  return localLeft.year == localRight.year &&
      localLeft.month == localRight.month &&
      localLeft.day == localRight.day;
}

double? _averageDouble(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left + right) / values.length;
}

double? _minimumDouble(List<double> values) =>
    values.isEmpty ? null : values.reduce(math.min);

double? _maximumDouble(List<double> values) =>
    values.isEmpty ? null : values.reduce(math.max);

class _HealthOfficialRangePainter extends CustomPainter {
  _HealthOfficialRangePainter({
    required this.bars,
    required this.axis,
    required this.color,
    required this.gridColor,
  });

  final List<_HealthRangeBar?> bars;
  final _HealthAxis axis;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const plotTop = 8.0;
    const plotBottom = 8.0;
    final plotHeight = math.max(1.0, size.height - plotTop - plotBottom);
    final slotWidth = size.width / math.max(1, bars.length);
    final barWidth = math.min(12.0, math.max(4.0, slotWidth * .5));
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .34)
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final y = plotTop + plotHeight * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double y(double value) {
      final normalized =
          ((value - axis.minimum) / (axis.maximum - axis.minimum)).clamp(
            0.0,
            1.0,
          );
      return plotTop + plotHeight * (1 - normalized);
    }

    final trackPaint = Paint()
      ..color = gridColor.withValues(alpha: .16)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < bars.length; index++) {
      final x = slotWidth * (index + .5);
      canvas.drawLine(
        Offset(x, plotTop + 2),
        Offset(x, size.height - plotBottom - 2),
        trackPaint,
      );
      final bar = bars[index];
      if (bar == null) continue;
      var top = y(bar.maximum);
      var bottom = y(bar.minimum);
      final minimumHeight = math.max(6.0, barWidth);
      if (bottom - top < minimumHeight) {
        final center = (top + bottom) / 2;
        top = center - minimumHeight / 2;
        bottom = center + minimumHeight / 2;
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), valuePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthOfficialRangePainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.axis != axis ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}

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
        _formatChartTime(end),
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

class _HealthYAxis extends StatelessWidget {
  const _HealthYAxis({required this.metric, this.compact = false});

  final XiaomiHealthMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axis = _healthAxis(metric);
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 9 : null,
            );
    return SizedBox(
      width: compact ? _healthCompactYAxisWidth : _healthYAxisWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: _healthYAxisGap),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              axis.format(axis.maximum, includeUnit: false),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: style,
            ),
            Text(
              axis.format(axis.middle, includeUnit: false),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: style,
            ),
            Text(
              axis.format(axis.minimum, includeUnit: false),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: style,
            ),
          ],
        ),
      ),
    );
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
    final resolvedEnd = end ?? _nextHour(DateTime.now());
    final resolvedStart =
        start ?? resolvedEnd.subtract(const Duration(hours: 24));
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
              Text(_formatChartTime(resolvedEnd), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthDailyXAxis extends StatelessWidget {
  const _HealthDailyXAxis({required this.days, required this.compact});

  final List<HealthDailySummary> days;
  final bool compact;

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_formatHealthDate(days.first.date), style: style),
        if (days.length > 1)
          Text(_formatHealthDate(days[days.length ~/ 2].date), style: style),
        Text(_formatHealthDate(days.last.date), style: style),
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
    final number = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return !includeUnit || unit.isEmpty ? number : '$number $unit';
  }
}

const _healthYAxisWidth = 36.0;
const _healthCompactYAxisWidth = 28.0;
const _healthYAxisGap = 6.0;
const _sleepHrvYAxisWidth = 38.0;

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
    const plotLeft = 0.0;
    final axisLabelWidth = compact ? 28.0 : 36.0;
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
      )..layout(maxWidth: axisLabelWidth);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    double x(DateTime date) {
      if (span <= 0) return plotLeft + plotWidth / 2;
      final elapsed =
          date.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
      return plotWidth * (elapsed / span).clamp(0.0, 1.0);
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
  const _HealthCard({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 214,
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
  });

  final DateTime start;
  final DateTime end;
  final List<HealthSleepHrvPoint> points;
  final ({double lower, double upper}) bounds;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plottedPoints = _downsampleSleepHrvPoints(points);
    if (plottedPoints.isEmpty) return;
    final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    if (span <= 0) return;

    const plotTop = 6.0;
    const plotBottom = 6.0;
    final plotWidth = math.max(1.0, size.width);
    final plotHeight = math.max(1.0, size.height - plotTop - plotBottom);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final fraction = index / 2;
      final y = plotTop + plotHeight * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double x(DateTime timestamp) {
      final elapsed =
          timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      return plotWidth * (elapsed / span).clamp(0.0, 1.0);
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
      oldDelegate.gridColor != gridColor;
}

({double lower, double upper}) _sleepHrvBounds({
  required int? minimum,
  required int? maximum,
  required Iterable<int> values,
}) {
  final valueList = values.toList(growable: false);
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

class _HealthSparklinePainter extends CustomPainter {
  _HealthSparklinePainter({
    required this.metric,
    required this.samples,
    required this.color,
    required this.gridColor,
    required this.showGrid,
    this.start,
    this.end,
  });

  final List<HealthSample> samples;
  final XiaomiHealthMetric metric;
  final Color color;
  final Color gridColor;
  final bool showGrid;
  final DateTime? start;
  final DateTime? end;

  @override
  void paint(Canvas canvas, Size size) {
    final chartEnd = end ?? _nextHour(DateTime.now());
    final chartStart = start ?? chartEnd.subtract(const Duration(hours: 24));
    final ranges = aggregateHealthHourlyRanges(
      samples,
      start: chartStart,
      end: chartEnd,
    );
    if (showGrid) {
      final grid = Paint()
        ..color = gridColor.withValues(alpha: .45)
        ..strokeWidth = 1;
      for (final fraction in const [0.0, .5, 1.0]) {
        final y = size.height * fraction;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
    final axis = _healthAxis(metric);
    final plotHeight = math.max(1.0, size.height - 8);
    final trackPaint = Paint()
      ..color = gridColor.withValues(alpha: showGrid ? .3 : .18)
      ..strokeWidth = showGrid ? 10 : 7
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = showGrid ? 10 : 7
      ..strokeCap = StrokeCap.round;
    final slotWidth = size.width / 24;
    for (var index = 0; index < 24; index++) {
      final x = slotWidth * (index + .5);
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), trackPaint);
      final range = ranges[index];
      if (range == null) continue;
      double y(double value) {
        final normalized =
            ((value - axis.minimum) / (axis.maximum - axis.minimum)).clamp(
              0.0,
              1.0,
            );
        return 4 + plotHeight * (1 - normalized);
      }

      var top = y(range.maximum);
      var bottom = y(range.minimum);
      final minimumLength = showGrid ? 10.0 : 8.0;
      if (bottom - top < minimumLength) {
        final center = (top + bottom) / 2;
        top = center - minimumLength / 2;
        bottom = center + minimumLength / 2;
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), valuePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthSparklinePainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.metric != metric ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}

class HealthHourRange {
  const HealthHourRange({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;
}

List<HealthHourRange?> aggregateHealthHourlyRanges(
  Iterable<HealthSample> samples, {
  required DateTime start,
  required DateTime end,
}) => aggregateHealthRanges(samples, start: start, end: end, slots: 24);

List<HealthHourRange?> aggregateHealthRanges(
  Iterable<HealthSample> samples, {
  required DateTime start,
  required DateTime end,
  required int slots,
}) {
  if (slots <= 0) return const <HealthHourRange?>[];
  final buckets = List<List<double>>.generate(slots, (_) => <double>[]);
  final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  if (span <= 0) return List<HealthHourRange?>.filled(slots, null);
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
        return HealthHourRange(
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

DateTime healthHourStart(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day, local.hour);
}

DateTime _nextHour(DateTime value) =>
    healthHourStart(value).add(const Duration(hours: 1));

String _formatSleepTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatChartTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatHealthDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}';
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
