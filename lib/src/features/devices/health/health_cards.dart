import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

part 'cards/activity_cards.dart';
part 'cards/sleep_card.dart';
part 'cards/health_chart_components.dart';

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
                      Expanded(
                        child: _HealthHomeTimelineChart(
                          metric: metric,
                          samples: samples,
                          color: color,
                          gridColor: theme.colorScheme.outlineVariant,
                          start: chartStart,
                          end: chartEnd,
                          showGrid: false,
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
              Icon(
                Icons.warning_amber_outlined,
                color: context.appColors.healthHeartRate,
              ),
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
    this.color,
    super.key,
  });

  final String title;
  final List<HealthAbnormalHealthRecord> records;
  final String Function(HealthAbnormalHealthRecord record) labelFor;
  final String Function(HealthAbnormalHealthRecord record) valueFor;
  final String recordLabel;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? context.appColors.healthHeartRate;
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
              Icon(icon, color: indicatorColor),
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

class HealthVitalityCard extends StatelessWidget {
  const HealthVitalityCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.noDataLabel,
    required this.onPressed,
    this.sevenDayTotal,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final HealthDailySummary? summary;
  final String noDataLabel;
  final VoidCallback onPressed;

  /// Local calendar-window total that keeps zero days explicit. Prefer it over
  /// the device's embedded 7-day field, which can skip zero days.
  final int? sevenDayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final day = summary;
    final score =
        sevenDayTotal ?? day?.vitalityLast7Days ?? day?.vitalityCurrent;
    final entries = <(String, String)>[
      if (day?.vitalityIncreaseLight != null)
        (l10n.deviceHealthLightIntensity, '+${day!.vitalityIncreaseLight}'),
      if (day?.vitalityIncreaseModerate != null ||
          day?.vitalityIncreaseHigh != null)
        (
          l10n.deviceHealthModerateHighIntensity,
          '+${(day!.vitalityIncreaseModerate ?? 0) + (day.vitalityIncreaseHigh ?? 0)}',
        ),
      if (day?.vitalityNextTargetMinutes != null)
        (
          _localizedVitality(context, '下一目标', 'Next target'),
          _localizedVitality(
            context,
            '${day!.vitalityNextTargetMinutes} 分钟',
            '${day.vitalityNextTargetMinutes} min',
          ),
        ),
    ];
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
            score == null ? '—' : '$score',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            day == null
                ? noDataLabel
                : _localizedVitality(context, '近 7 日累计', '7-day total'),
            style: theme.textTheme.bodySmall,
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SleepCardStatsRow(entries: entries.take(3).toList()),
          ],
        ],
      ),
    );
  }
}

String _localizedVitality(BuildContext context, String zh, String fallback) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : fallback;

class HealthWorkoutCard extends StatelessWidget {
  const HealthWorkoutCard({
    required this.workouts,
    required this.onPressed,
    super.key,
  });

  final List<HealthWorkoutSummary> workouts;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final workout = workouts.isEmpty
        ? null
        : workouts.reduce(
            (latest, candidate) =>
                candidate.endedAt.isAfter(latest.endedAt) ? candidate : latest,
          );
    final iconColor = healthWorkoutVisualColor(context);
    final stats = <(String, String)>[];
    if (workout?.distanceMeters != null) {
      stats.add((
        l10n.deviceHealthDistance,
        _formatWorkoutDistance(workout!.distanceMeters!),
      ));
    }
    if (workout?.calories != null) {
      stats.add((l10n.deviceHealthCalories, '${workout!.calories} kcal'));
    }
    if (workout?.effectiveAverageHeartRate != null) {
      stats.add((
        l10n.deviceHealthHeartRate,
        '${workout!.effectiveAverageHeartRate} bpm',
      ));
    }
    if (workout != null && healthWorkoutSupportsPace(workout)) {
      stats.add((
        l10n.deviceHealthAveragePace,
        _formatWorkoutPace(workout.averagePaceSecondsPerKilometer!),
      ));
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
              Icon(Icons.directions_run_outlined, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.deviceHealthWorkoutGeneric,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            workout == null ? '—' : _workoutCardName(context, workout),
            style: theme.textTheme.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            workout == null
                ? l10n.deviceHealthNoData
                : '${_formatHealthDate(workout.startedAt)} '
                      '${_formatHealthTime(workout.startedAt)} · '
                      '${_formatWorkoutDuration(workout.endedAt.difference(workout.startedAt))}',
            style: theme.textTheme.bodySmall,
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SleepCardStatsRow(entries: stats.take(4).toList()),
          ],
        ],
      ),
    );
  }
}

Color healthWorkoutVisualColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

List<Color> healthHeartRateZoneColors(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.appColors;
  return [
    scheme.onSurfaceVariant,
    semantic.info,
    semantic.success,
    semantic.warning,
    semantic.healthHeartRate,
  ];
}
