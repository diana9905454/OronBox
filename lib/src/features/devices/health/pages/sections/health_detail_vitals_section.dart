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
    final l10n = AppLocalizations.of(context)!;
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
            _abnormalLabelForKind(l10n, kind),
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
    final episodes = _groupAbnormalEpisodes(records, kind);
    if (episodes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final indicatorColor = _abnormalColor(context, kind);

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                l10n.deviceHealthSleepWakeCount(episodes.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (index, episode) in episodes.indexed) ...[
            if (index > 0)
              Divider(
                height: 16,
                thickness: 0.5,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatEpisodeValue(episode, l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                    ),
                  ),
                  Text(
                    _formatEpisodeTime(episode),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_AbnormalHealthEpisode> _groupAbnormalEpisodes(
    List<HealthAbnormalHealthRecord> records,
    HealthAbnormalHealthKind kind,
  ) {
    if (records.isEmpty) return const [];
    // Sort chronological first so segment boundaries and point-clustering
    // follow the true event order, aligning with Mi Fitness AbnormalRecord
    // segmentation and time-window separation.
    final sorted = [...records]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final groups = <List<HealthAbnormalHealthRecord>>[];
    for (final record in sorted) {
      if (groups.isEmpty) {
        groups.add([record]);
        continue;
      }
      final currentGroup = groups.last;
      final prev = currentGroup.last;

      final prevHasSegment =
          prev.startedAt != null &&
          prev.endedAt != null &&
          !prev.startedAt!.isAtSameMomentAs(prev.endedAt!);
      final currHasSegment =
          record.startedAt != null &&
          record.endedAt != null &&
          !record.startedAt!.isAtSameMomentAs(record.endedAt!);

      if (prevHasSegment && currHasSegment) {
        // Both declare explicit segment ranges: check if they belong to the same episode
        final sameSegment =
            prev.startedAt!.isAtSameMomentAs(record.startedAt!) &&
            prev.endedAt!.isAtSameMomentAs(record.endedAt!) &&
            prev.threshold == record.threshold;
        if (sameSegment) {
          currentGroup.add(record);
        } else {
          groups.add([record]);
        }
      } else {
        // Either record lacks segment markers: partition by temporal proximity (<= 5 minutes gap)
        // and identical threshold, matching Mi Fitness's event-clustering convention.
        final diff = record.timestamp.difference(prev.timestamp).abs();
        final sameThreshold = prev.threshold == record.threshold;
        if (diff <= const Duration(minutes: 5) && sameThreshold) {
          currentGroup.add(record);
        } else {
          groups.add([record]);
        }
      }
    }

    final episodes = <_AbnormalHealthEpisode>[];
    for (final group in groups) {
      final first = group.first;
      final last = group.last;
      final start = first.startedAt ?? first.timestamp;
      final end = first.endedAt ?? last.timestamp;
      episodes.add(
        _AbnormalHealthEpisode(
          kind: kind,
          startedAt: start,
          endedAt: end.isBefore(start) ? start : end,
          threshold: first.threshold,
          records: group,
        ),
      );
    }
    episodes.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return episodes;
  }

  String _formatEpisodeValue(
    _AbnormalHealthEpisode episode,
    AppLocalizations l10n,
  ) {
    if (episode.kind == HealthAbnormalHealthKind.irregularHeartbeat) {
      return l10n.deviceHealthDetected;
    }
    final peak = episode.peakValue;
    if (peak == null) return '—';
    final unit = switch (episode.kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.lowHeartRate => ' bpm',
      HealthAbnormalHealthKind.lowBloodOxygen => '%',
      HealthAbnormalHealthKind.highStress => '',
      HealthAbnormalHealthKind.irregularHeartbeat => '',
    };
    final min = episode.minValue;
    final max = episode.maxValue;
    if (min != null && max != null && min != max) {
      return '$min - $max$unit';
    }
    return '$peak$unit';
  }

  String _formatEpisodeTime(_AbnormalHealthEpisode episode) {
    final start = episode.startedAt.toLocal();
    final end = episode.endedAt.toLocal();
    final isDay = _period == HealthChartPeriod.day;
    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String mmddHhmm(DateTime dt) =>
        '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${hhmm(dt)}';

    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      if (hhmm(start) == hhmm(end)) {
        return isDay ? hhmm(start) : mmddHhmm(start);
      }
      return isDay
          ? '${hhmm(start)} – ${hhmm(end)}'
          : '${mmddHhmm(start)} – ${hhmm(end)}';
    }
    return '${mmddHhmm(start)} – ${mmddHhmm(end)}';
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
    HealthAbnormalHealthKind.irregularHeartbeat =>
      l10n.deviceHealthIrregularHeartbeat,
    HealthAbnormalHealthKind.lowBloodOxygen => l10n.deviceHealthLowBloodOxygen,
    HealthAbnormalHealthKind.highStress => l10n.deviceHealthHighStress,
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
}

class _AbnormalHealthEpisode {
  const _AbnormalHealthEpisode({
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.threshold,
    required this.records,
  });

  final HealthAbnormalHealthKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? threshold;
  final List<HealthAbnormalHealthRecord> records;

  int? get peakValue {
    final values = records.map((r) => r.value).whereType<int>();
    if (values.isEmpty) return null;
    return switch (kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.highStress => values.reduce(math.max),
      HealthAbnormalHealthKind.lowHeartRate ||
      HealthAbnormalHealthKind.lowBloodOxygen => values.reduce(math.min),
      HealthAbnormalHealthKind.irregularHeartbeat => null,
    };
  }

  int? get minValue {
    final values = records.map((r) => r.value).whereType<int>();
    return values.isEmpty ? null : values.reduce(math.min);
  }

  int? get maxValue {
    final values = records.map((r) => r.value).whereType<int>();
    return values.isEmpty ? null : values.reduce(math.max);
  }

  Duration get duration => endedAt.difference(startedAt);


}
