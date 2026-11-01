part of '../xiaomi_health_detail_page.dart';

class _HealthTrendSection extends StatelessWidget {
  const _HealthTrendSection({
    required this.data,
    required this.metric,
    required this.color,
    required this.period,
    required this.anchorDate,
  });

  final XiaomiHealthData data;
  final XiaomiHealthMetric metric;
  final Color color;
  final HealthChartPeriod period;
  final DateTime anchorDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final range = _range;
    final days = _daysInRange(range);
    final samples = _samplesInRange(range);
    final stats = _stats(days, samples);
    final unit = _metricUnit(metric);
    final hasData = stats.average != null || stats.latest != null;
    final headline = samples.isNotEmpty ? stats.latest : stats.average;
    final headlineLabel = samples.isNotEmpty
        ? switch (metric) {
            XiaomiHealthMetric.heartRate => l10n.deviceHealthLatestHeartRate,
            XiaomiHealthMetric.bloodOxygen =>
              l10n.deviceHealthLatestBloodOxygen,
            XiaomiHealthMetric.stress => l10n.deviceHealthLatestStress,
            _ => '${l10n.deviceHealthLatest} · ${_title(l10n, metric)}',
          }
        : '${l10n.deviceHealthAverage} · ${_title(l10n, metric)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasData) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headlineLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMetric(headline, unit),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasData)
                HealthOfficialRangeChart(
                  metric: metric,
                  period: period,
                  samples: samples,
                  days: days,
                  color: color,
                  start: range.start,
                  end: range.end,
                  height: 196,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(l10n.deviceHealthNoSamples)),
                ),
            ],
          ),
        ),
        // Heart rate, SpO2 and stress render a dedicated 平均/最低/最高 vitals
        // card from the detail page instead of this latest/average/range block,
        // so keep a single consistent summary per metric.
        if (metric != XiaomiHealthMetric.heartRate &&
            metric != XiaomiHealthMetric.bloodOxygen &&
            metric != XiaomiHealthMetric.stress) ...[
          const SizedBox(height: 12),
          _DetailCard(
            child: _HealthSummaryStats(
              columns: 3,
              entries: [
                (l10n.deviceHealthLatest, _formatMetric(stats.latest, '')),
                (l10n.deviceHealthAverage, _formatMetric(stats.average, '')),
                (
                  l10n.deviceHealthRange,
                  stats.minimum == null || stats.maximum == null
                      ? '—'
                      : '${_formatMetric(stats.minimum, '')}–'
                            '${_formatMetric(stats.maximum, '')}',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  _HealthDateRange get _range {
    return _healthPeriodRange(period, anchorDate);
  }

  List<HealthDailySummary> _daysInRange(_HealthDateRange range) {
    final existing = <String, HealthDailySummary>{};
    for (final day in data.daily) {
      final date = _dateOnly(day.date);
      if (date.isBefore(range.start) || !date.isBefore(range.end)) {
        continue;
      }
      if (healthMetricDailyValues(day, metric).hasValue) {
        existing[_dateKey(date)] = day;
      }
    }
    return [
      for (
        var offset = 0;
        offset < healthCalendarDaysBetween(range.start, range.end);
        offset++
      )
        existing[_dateKey(healthAddCalendarDays(range.start, offset))] ??
            HealthDailySummary(
              date: healthAddCalendarDays(range.start, offset),
            ),
    ];
  }

  List<HealthSample> _samplesInRange(_HealthDateRange range) =>
      data.samplesFor(metric).where((sample) {
          final timestamp = sample.timestamp.toLocal();
          return sample.isUsable &&
              !timestamp.isBefore(range.start) &&
              timestamp.isBefore(range.end);
        }).toList()
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

  _HealthMetricStats _stats(
    List<HealthDailySummary> days,
    List<HealthSample> samples,
  ) {
    final values = <double>[];
    final minimums = <double>[];
    final maximums = <double>[];
    for (final day in days) {
      final daily = healthMetricDailyValues(day, metric);
      if (daily.average != null) {
        values.add(daily.average!);
      } else if (daily.minimum != null && daily.maximum != null) {
        values.add((daily.minimum! + daily.maximum!) / 2);
      }
      if (daily.minimum != null) minimums.add(daily.minimum!);
      if (daily.maximum != null) maximums.add(daily.maximum!);
    }
    if (period == HealthChartPeriod.day && samples.isNotEmpty) {
      values
        ..clear()
        ..addAll(samples.map((sample) => sample.value));
      minimums
        ..clear()
        ..add(values.reduce((left, right) => left < right ? left : right));
      maximums
        ..clear()
        ..add(values.reduce((left, right) => left > right ? left : right));
    }
    HealthDailySummary? latestDay;
    for (final day in days.reversed) {
      if (healthMetricDailyValues(day, metric).hasValue) {
        latestDay = day;
        break;
      }
    }
    final latestDaily = latestDay == null
        ? null
        : healthMetricDailyValues(latestDay, metric);
    final latest = samples.isNotEmpty
        ? samples.last.value
        : latestDaily?.average ?? latestDaily?.minimum ?? latestDaily?.maximum;
    final average = values.isEmpty
        ? null
        : values.reduce((left, right) => left + right) / values.length;
    return _HealthMetricStats(
      latest: latest,
      average: average,
      minimum: minimums.isEmpty
          ? null
          : minimums.reduce((left, right) => left < right ? left : right),
      maximum: maximums.isEmpty
          ? null
          : maximums.reduce((left, right) => left > right ? left : right),
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _HealthDateRange {
  const _HealthDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _HealthPeriodHeader extends StatelessWidget {
  const _HealthPeriodHeader({
    required this.period,
    required this.anchorDate,
    required this.canGoForward,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final HealthChartPeriod period;
  final DateTime anchorDate;
  final bool canGoForward;
  final ValueChanged<HealthChartPeriod> onPeriodChanged;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<HealthChartPeriod>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HealthChartPeriod.day,
              label: Text(l10n.deviceHealthDayView),
            ),
            ButtonSegment(
              value: HealthChartPeriod.week,
              label: Text(l10n.deviceHealthWeekView),
            ),
            ButtonSegment(
              value: HealthChartPeriod.month,
              label: Text(l10n.deviceHealthMonthView),
            ),
          ],
          selected: {period},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) onPeriodChanged(values.first);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).previousPageTooltip,
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _healthPeriodLabel(context, period, anchorDate),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
              onPressed: canGoForward ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

_HealthDateRange _healthPeriodRange(HealthChartPeriod period, DateTime anchor) {
  final date = _dateOnly(anchor);
  return switch (period) {
    HealthChartPeriod.day => _HealthDateRange(
      start: date,
      end: healthAddCalendarDays(date, 1),
    ),
    HealthChartPeriod.week => _HealthDateRange(
      start: _weekStart(date),
      end: healthAddCalendarDays(_weekStart(date), 7),
    ),
    HealthChartPeriod.month => _HealthDateRange(
      start: DateTime(date.year, date.month),
      end: DateTime(date.year, date.month + 1),
    ),
  };
}

DateTime _weekStart(DateTime date) =>
    healthAddCalendarDays(date, 1 - date.weekday);

DateTime _initialAnchorDate(XiaomiHealthData data, XiaomiHealthMetric metric) {
  final candidates = <DateTime?>[
    data.latestSample(metric)?.timestamp,
    switch (metric) {
      XiaomiHealthMetric.sleep => data.latestSleep?.endedAt,
      XiaomiHealthMetric.workout =>
        data.workouts.isEmpty
            ? null
            : data.workouts
                  .reduce(
                    (left, right) =>
                        left.startedAt.isAfter(right.startedAt) ? left : right,
                  )
                  .startedAt,
      _ => data.latestDay?.date,
    },
    if (metric == XiaomiHealthMetric.activity ||
        metric == XiaomiHealthMetric.activeCalories)
      data.activitySummary?.date,
  ];
  DateTime? latest;
  for (final candidate in candidates) {
    if (candidate == null || (latest != null && !candidate.isAfter(latest))) {
      continue;
    }
    latest = candidate;
  }
  return _dateOnly(latest ?? DateTime.now());
}

String _healthPeriodLabel(
  BuildContext context,
  HealthChartPeriod period,
  DateTime anchor,
) {
  final range = _healthPeriodRange(period, anchor);
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'zh') {
    return switch (period) {
      HealthChartPeriod.day =>
        '${range.start.year}年${range.start.month}月${range.start.day}日',
      HealthChartPeriod.week =>
        '${_isoWeekYear(range.start)}年${_isoWeekNumber(range.start)}周',
      HealthChartPeriod.month => '${range.start.year}年${range.start.month}月',
    };
  }
  return switch (period) {
    HealthChartPeriod.day =>
      '${range.start.year}/${range.start.month}/${range.start.day}',
    HealthChartPeriod.week =>
      'W${_isoWeekNumber(range.start)}, ${_isoWeekYear(range.start)}',
    HealthChartPeriod.month => '${range.start.year}/${range.start.month}',
  };
}

int _isoWeekYear(DateTime date) =>
    healthAddCalendarDays(date, 4 - date.weekday).year;

int _isoWeekNumber(DateTime date) {
  final thursday = healthAddCalendarDays(date, 4 - date.weekday);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstMonday = healthAddCalendarDays(
    firstThursday,
    1 - firstThursday.weekday,
  );
  return (healthCalendarDaysBetween(firstMonday, thursday) ~/ 7) + 1;
}

bool _sameDate(DateTime left, DateTime right) {
  final a = left.toLocal();
  final b = right.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ActivityDayValues {
  const _ActivityDayValues({
    required this.date,
    this.steps,
    this.activeCalories,
    this.standingHours,
  });

  final DateTime date;
  final int? steps;
  final int? activeCalories;
  final int? standingHours;

  bool get hasValue =>
      steps != null || activeCalories != null || standingHours != null;
}

class _ActivityPeriodValues {
  const _ActivityPeriodValues({
    this.steps,
    this.activeCalories,
    this.standingHours,
  });

  final int? steps;
  final int? activeCalories;
  final int? standingHours;
}

class _HealthMetricStats {
  const _HealthMetricStats({
    this.latest,
    this.average,
    this.minimum,
    this.maximum,
  });

  final double? latest;
  final double? average;
  final double? minimum;
  final double? maximum;
}

String _metricUnit(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate || XiaomiHealthMetric.restingHeartRate => 'bpm',
  XiaomiHealthMetric.bloodOxygen => '%',
  _ => '',
};

String _formatMetric(double? value, String unit) {
  if (value == null) return '—';
  final number = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$number $unit'.trim();
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

typedef _DetailCard = HealthDetailCard;
typedef _ActivityMetricCard = ActivityMetricCard;
typedef _HealthSummaryStats = HealthSummaryStats;
typedef _WorkoutChartAxis = HealthChartAxis;
typedef _WorkoutChartSeries = HealthChartSeries;
typedef _WorkoutFlChart = HealthFlChart;
typedef _WorkoutDetailPage = WorkoutDetailPage;

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = values.length <= 3
            ? values.length
            : constraints.maxWidth >= 640
            ? 3
            : 2;
        return _HealthSummaryStats(entries: values, columns: columns);
      },
    );
  }
}

String _title(AppLocalizations l10n, XiaomiHealthMetric metric) =>
    switch (metric) {
      XiaomiHealthMetric.activity => l10n.deviceHealthActivityOverview,
      XiaomiHealthMetric.activeCalories => l10n.deviceHealthActivityOverview,
      XiaomiHealthMetric.heartRate => l10n.deviceHealthHeartRate,
      XiaomiHealthMetric.restingHeartRate => l10n.deviceHealthRestingHeartRate,
      XiaomiHealthMetric.bloodOxygen => l10n.deviceHealthBloodOxygen,
      XiaomiHealthMetric.stress => l10n.deviceHealthStress,
      XiaomiHealthMetric.vitality => l10n.deviceHealthVitality,
      XiaomiHealthMetric.sleep => l10n.deviceHealthSleep,
      XiaomiHealthMetric.workout => l10n.deviceHealthWorkout,
    };

Color _color(BuildContext context, XiaomiHealthMetric metric) =>
    switch (metric) {
      XiaomiHealthMetric.heartRate => context.appColors.healthHeartRate,
      XiaomiHealthMetric.restingHeartRate =>
        context.appColors.healthRestingHeartRate,
      XiaomiHealthMetric.bloodOxygen => context.appColors.healthBloodOxygen,
      XiaomiHealthMetric.stress => context.appColors.healthStress,
      XiaomiHealthMetric.vitality => context.appColors.healthVitality,
      _ => context.appColors.info,
    };

String _number(num? value) => value == null ? '—' : value.round().toString();
String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

String _clock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _sleepClock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _sleepDuration(BuildContext context, int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  if (Localizations.localeOf(context).languageCode == 'zh') {
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours小时';
    return '$hours小时$minutes分';
  }
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class _SleepStructureValue {
  const _SleepStructureValue({
    required this.kind,
    required this.label,
    required this.seconds,
    required this.percent,
    required this.color,
    this.count,
  });

  final HealthSleepStageKind kind;
  final String label;
  final int seconds;
  final int percent;
  final Color color;
  final int? count;
}

List<int> _sleepPercentages(List<int> values, int total) {
  if (total <= 0) return List<int>.filled(values.length, 0);
  final exact = values.map((value) => value * 100 / total).toList();
  final result = exact.map((value) => value.floor()).toList();
  final remaining = 100 - result.fold<int>(0, (sum, value) => sum + value);
  final indices = [for (var index = 0; index < values.length; index++) index]
    ..sort(
      (left, right) =>
          (exact[right] - result[right]).compareTo(exact[left] - result[left]),
    );
  for (var index = 0; index < remaining && indices.isNotEmpty; index++) {
    result[indices[index % indices.length]]++;
  }
  return result;
}
