part of '../xiaomi_health_detail_page.dart';

extension _HealthDetailVitalsSection on _XiaomiHealthDetailPageState {
  Widget _heartRate(BuildContext context) {
    final content = <Widget>[_series(context)];
    final summary = _periodVitalsCard(context, XiaomiHealthMetric.heartRate);
    if (summary != null) {
      content
        ..add(const SizedBox(height: 16))
        ..add(summary);
    }
    const kinds = [
      HealthAbnormalHealthKind.highHeartRate,
      HealthAbnormalHealthKind.lowHeartRate,
      HealthAbnormalHealthKind.irregularHeartbeat,
    ];
    final availableKinds = kinds
        .where((kind) => _abnormalRecords({kind}).isNotEmpty)
        .toList();
    if (availableKinds.isNotEmpty) {
      content
        ..add(const SizedBox(height: 16))
        ..add(_heartHealthMonitoring(context, availableKinds));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
  }

  Widget _heartHealthMonitoring(
    BuildContext context,
    List<HealthAbnormalHealthKind> kinds,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (final (index, kind) in kinds.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          _abnormalEventSection(
            context,
            _abnormalRecords({kind}),
            _abnormalLabelForKind(l10n, kind),
            kind,
          ),
        ],
      ],
    );
  }

  Widget _seriesWithAbnormal(
    BuildContext context,
    HealthAbnormalHealthKind kind,
  ) {
    final records = _abnormalRecords({kind});
    final content = <Widget>[_series(context)];
    final summary = _periodVitalsCard(context, args.metric);
    if (summary != null) {
      content
        ..add(const SizedBox(height: 16))
        ..add(summary);
    }
    if (records.isNotEmpty) {
      content
        ..add(const SizedBox(height: 16))
        ..add(
          _abnormalEventSection(
            context,
            records,
            _abnormalLabelForKind(AppLocalizations.of(context)!, kind),
            kind,
          ),
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
  }

  Widget? _periodVitalsCard(BuildContext context, XiaomiHealthMetric metric) {
    final range = _currentRange;
    final days = _dailyDaysInRange(range)
        .where((day) => _hasDailyVitals(day, metric))
        .toList(growable: false);
    final samples =
        args.data
            .samplesFor(metric)
            .where((sample) {
              final timestamp = sample.timestamp.toLocal();
              return sample.isUsable &&
                  !timestamp.isBefore(range.start) &&
                  timestamp.isBefore(range.end);
            })
            .toList(growable: false)
          // The store keeps samples newest-first. The "latest" summary values below
          // must read the newest sample, so restore chronological order to match
          // the trend chart instead of reporting the oldest point.
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    if (days.isEmpty && samples.isEmpty) return null;

    final isDay = _period == HealthChartPeriod.day;
    final values = switch (metric) {
      XiaomiHealthMetric.heartRate => _heartRateOverviewValues(
        context,
        days,
        samples,
        isDay,
      ),
      XiaomiHealthMetric.stress => _stressOverviewValues(
        context,
        days,
        samples,
        isDay,
      ),
      _ => _bloodOxygenOverviewValues(context, days, samples, isDay),
    };
    if (values.isEmpty) return null;
    return _DetailCard(
      child: _HealthSummaryStats(entries: values, columns: values.length),
    );
  }

  bool _hasDailyVitals(HealthDailySummary day, XiaomiHealthMetric metric) =>
      switch (metric) {
        XiaomiHealthMetric.heartRate =>
          day.restingHeartRate != null ||
              day.minHeartRate != null ||
              day.maxHeartRate != null ||
              day.averageHeartRate != null,
        XiaomiHealthMetric.bloodOxygen =>
          day.currentBloodOxygen != null ||
              day.averageBloodOxygen != null ||
              day.minBloodOxygen != null ||
              day.maxBloodOxygen != null,
        XiaomiHealthMetric.stress =>
          day.averageStress != null ||
              day.minStress != null ||
              day.maxStress != null,
        _ => false,
      };

  List<(String, String)> _heartRateOverviewValues(
    BuildContext context,
    List<HealthDailySummary> days,
    List<HealthSample> samples,
    bool isDay,
  ) {
    if (isDay) {
      final day = days.lastOrNull;
      final minimum = day?.minHeartRate ?? _minimumSampleValue(samples);
      final maximum = day?.maxHeartRate ?? _maximumSampleValue(samples);
      return [
        (
          AppLocalizations.of(context)!.deviceHealthAverage,
          _withUnit(
            day?.averageHeartRate ?? _averageSampleValue(samples),
            'bpm',
          ),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthResting,
          _withUnit(day?.restingHeartRate, 'bpm'),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMinimum,
          _withUnit(minimum, 'bpm'),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMaximum,
          _withUnit(maximum, 'bpm'),
        ),
      ];
    }
    final dailyAverages = days.map((day) => day.averageHeartRate);
    final average = _averageInt(dailyAverages) ?? _averageSampleValue(samples);
    final resting = _averageInt(days.map((day) => day.restingHeartRate));
    return [
      (
        AppLocalizations.of(context)!.deviceHealthAverage,
        _withUnit(average, 'bpm'),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthResting,
        _withUnit(resting, 'bpm'),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMinimum,
        _withUnit(
          _minimumInt(days.map((day) => day.minHeartRate)) ??
              _minimumSampleValue(samples),
          'bpm',
        ),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMaximum,
        _withUnit(
          _maximumInt(days.map((day) => day.maxHeartRate)) ??
              _maximumSampleValue(samples),
          'bpm',
        ),
      ),
    ];
  }

  List<(String, String)> _bloodOxygenOverviewValues(
    BuildContext context,
    List<HealthDailySummary> days,
    List<HealthSample> samples,
    bool isDay,
  ) {
    if (isDay) {
      final day = days.lastOrNull;
      return [
        (
          AppLocalizations.of(context)!.deviceHealthAverage,
          _withUnit(
            day?.averageBloodOxygen ?? _averageSampleValue(samples),
            '%',
          ),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMinimum,
          _withUnit(day?.minBloodOxygen ?? _minimumSampleValue(samples), '%'),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMaximum,
          _withUnit(day?.maxBloodOxygen ?? _maximumSampleValue(samples), '%'),
        ),
      ];
    }
    return [
      (
        AppLocalizations.of(context)!.deviceHealthAverage,
        _withUnit(
          _averageInt(days.map((day) => day.averageBloodOxygen)) ??
              _averageSampleValue(samples),
          '%',
        ),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMinimum,
        _withUnit(
          _minimumInt(days.map((day) => day.minBloodOxygen)) ??
              _minimumSampleValue(samples),
          '%',
        ),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMaximum,
        _withUnit(
          _maximumInt(days.map((day) => day.maxBloodOxygen)) ??
              _maximumSampleValue(samples),
          '%',
        ),
      ),
    ];
  }

  List<(String, String)> _stressOverviewValues(
    BuildContext context,
    List<HealthDailySummary> days,
    List<HealthSample> samples,
    bool isDay,
  ) {
    if (isDay) {
      final day = days.lastOrNull;
      return [
        (
          AppLocalizations.of(context)!.deviceHealthAverage,
          _withUnit(day?.averageStress ?? _averageSampleValue(samples), ''),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMinimum,
          _withUnit(day?.minStress ?? _minimumSampleValue(samples), ''),
        ),
        (
          AppLocalizations.of(context)!.deviceHealthMaximum,
          _withUnit(day?.maxStress ?? _maximumSampleValue(samples), ''),
        ),
      ];
    }
    return [
      (
        AppLocalizations.of(context)!.deviceHealthAverage,
        _withUnit(
          _averageInt(days.map((day) => day.averageStress)) ??
              _averageSampleValue(samples),
          '',
        ),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMinimum,
        _withUnit(
          _minimumInt(days.map((day) => day.minStress)) ??
              _minimumSampleValue(samples),
          '',
        ),
      ),
      (
        AppLocalizations.of(context)!.deviceHealthMaximum,
        _withUnit(
          _maximumInt(days.map((day) => day.maxStress)) ??
              _maximumSampleValue(samples),
          '',
        ),
      ),
    ];
  }

  int? _averageInt(Iterable<int?> values) {
    final present = values.whereType<int>().toList(growable: false);
    if (present.isEmpty) return null;
    return (present.reduce((left, right) => left + right) / present.length)
        .round();
  }

  int? _minimumInt(Iterable<int?> values) {
    final present = values.whereType<int>();
    return present.isEmpty ? null : present.reduce(math.min);
  }

  int? _maximumInt(Iterable<int?> values) {
    final present = values.whereType<int>();
    return present.isEmpty ? null : present.reduce(math.max);
  }

  int? _averageSampleValue(List<HealthSample> samples) {
    if (samples.isEmpty) return null;
    return (samples.map((sample) => sample.value).reduce((a, b) => a + b) /
            samples.length)
        .round();
  }

  int? _minimumSampleValue(List<HealthSample> samples) => samples.isEmpty
      ? null
      : samples.map((sample) => sample.value.round()).reduce(math.min);

  int? _maximumSampleValue(List<HealthSample> samples) => samples.isEmpty
      ? null
      : samples.map((sample) => sample.value.round()).reduce(math.max);

  Widget _restingHeartRate(BuildContext context) {
    return _HealthTrendSection(
      data: args.data,
      metric: XiaomiHealthMetric.restingHeartRate,
      color: _color(context, XiaomiHealthMetric.restingHeartRate),
      period: _period,
      anchorDate: _anchorDate,
    );
  }

  Widget _abnormalEventSection(
    BuildContext context,
    List<HealthAbnormalHealthRecord> records,
    String title,
    HealthAbnormalHealthKind kind,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...records]
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_abnormalIcon(kind), color: _abnormalColor(context, kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${sorted.length} ${l10n.deviceHealthRecordCount}'),
            ],
          ),
          const SizedBox(height: 12),
          for (final (index, record) in sorted.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _abnormalValue(record, l10n),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _abnormalDetails(record),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<HealthAbnormalHealthRecord> _abnormalRecords(
    Set<HealthAbnormalHealthKind> kinds,
  ) => args.data.abnormalHealthRecords
      .where((record) => kinds.contains(record.kind))
      .where((record) {
        final start = record.startedAt ?? record.timestamp;
        final end = record.endedAt ?? start;
        return _overlaps(_currentRange, start, end);
      })
      .toList(growable: false);

  String _abnormalLabelForKind(
    AppLocalizations l10n,
    HealthAbnormalHealthKind kind,
  ) => switch (kind) {
    HealthAbnormalHealthKind.highHeartRate => l10n.deviceHealthHeartRateHigh,
    HealthAbnormalHealthKind.lowHeartRate => l10n.deviceHealthHeartRateLow,
    HealthAbnormalHealthKind.lowBloodOxygen => l10n.deviceHealthLowBloodOxygen,
    HealthAbnormalHealthKind.highStress => l10n.deviceHealthHighStress,
    HealthAbnormalHealthKind.irregularHeartbeat =>
      l10n.deviceHealthIrregularHeartbeat,
  };

  IconData _abnormalIcon(HealthAbnormalHealthKind kind) => switch (kind) {
    HealthAbnormalHealthKind.highHeartRate ||
    HealthAbnormalHealthKind.highStress => Icons.trending_up,
    HealthAbnormalHealthKind.lowHeartRate ||
    HealthAbnormalHealthKind.lowBloodOxygen => Icons.trending_down,
    HealthAbnormalHealthKind.irregularHeartbeat => Icons.favorite_outline,
  };

  Color _abnormalColor(BuildContext context, HealthAbnormalHealthKind kind) =>
      switch (kind) {
        HealthAbnormalHealthKind.highHeartRate ||
        HealthAbnormalHealthKind.lowHeartRate ||
        HealthAbnormalHealthKind.irregularHeartbeat =>
          context.appColors.healthHeartRate,
        HealthAbnormalHealthKind.lowBloodOxygen =>
          context.appColors.healthBloodOxygen,
        HealthAbnormalHealthKind.highStress => context.appColors.healthStress,
      };

  String _abnormalValue(
    HealthAbnormalHealthRecord record,
    AppLocalizations l10n,
  ) {
    final value = record.value;
    if (record.kind == HealthAbnormalHealthKind.irregularHeartbeat) {
      final start = record.startedAt ?? record.timestamp;
      final end = record.endedAt;
      return end == null
          ? l10n.deviceHealthDetected
          : _durationBetween(start, end);
    }
    if (value == null) return '—';
    return switch (record.kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.lowHeartRate => '$value bpm',
      HealthAbnormalHealthKind.lowBloodOxygen => '$value%',
      HealthAbnormalHealthKind.highStress => '$value',
      HealthAbnormalHealthKind.irregularHeartbeat => l10n.deviceHealthDetected,
    };
  }

  String _abnormalDetails(HealthAbnormalHealthRecord record) {
    final start = record.startedAt ?? record.timestamp;
    final end = record.endedAt;
    final time = end == null
        ? _sleepDateTime(start)
        : '${_sleepDateTime(start)} – ${_sleepDateTime(end)}';
    if (record.kind == HealthAbnormalHealthKind.irregularHeartbeat) {
      return end == null ? time : '$time · ${_durationBetween(start, end)}';
    }
    final threshold = record.threshold;
    if (threshold == null) return time;
    final unit = switch (record.kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.lowHeartRate => 'bpm',
      HealthAbnormalHealthKind.lowBloodOxygen => '%',
      HealthAbnormalHealthKind.highStress => '',
      HealthAbnormalHealthKind.irregularHeartbeat => '',
    };
    final operator = switch (record.kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.highStress => '≥',
      HealthAbnormalHealthKind.lowHeartRate ||
      HealthAbnormalHealthKind.lowBloodOxygen => '≤',
      HealthAbnormalHealthKind.irregularHeartbeat => '',
    };
    return '$time · $operator $threshold$unit';
  }


}
