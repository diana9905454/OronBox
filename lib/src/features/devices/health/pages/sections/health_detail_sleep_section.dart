part of '../xiaomi_health_detail_page.dart';

extension _HealthDetailSleepSection on _XiaomiHealthDetailPageState {
  Widget _sleep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sleeps = args.data.sleep
        // Mi Fitness assigns a sleep segment to the day on which it ends.
        // Using interval overlap duplicates an overnight sleep on two days.
        .where((sleep) {
          final endedAt = sleep.endedAt.toLocal();
          return !endedAt.isBefore(_currentRange.start) &&
              endedAt.isBefore(_currentRange.end);
        })
        .toList(growable: false);
    if (sleeps.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoSleep));
    }
    final sortedSleeps = [...sleeps]
      ..sort((left, right) {
        final leftIsLong = left.isLongSleep;
        final rightIsLong = right.isLongSleep;
        if (leftIsLong != rightIsLong) return leftIsLong ? -1 : 1;
        return right.startedAt.compareTo(left.startedAt);
      });
    final stageLabels = <HealthSleepStageKind, String>{
      HealthSleepStageKind.awake: l10n.deviceHealthSleepAwake,
      HealthSleepStageKind.rem: l10n.deviceHealthSleepRem,
      HealthSleepStageKind.light: l10n.deviceHealthSleepLight,
      HealthSleepStageKind.deep: l10n.deviceHealthSleepDeep,
    };
    final detailedSleeps = sortedSleeps
        .where(
          (sleep) =>
              sleep.isLongSleep ||
              sleep.stages.isNotEmpty ||
              sleep.averageHrv != null ||
              sleep.hrvPoints.isNotEmpty ||
              sleep.averageHeartRate != null ||
              sleep.averageBloodOxygen != null ||
              sleep.heartRatePoints.isNotEmpty ||
              sleep.bloodOxygenPoints.isNotEmpty,
        )
        .toList();
    final naps =
        sortedSleeps.where((sleep) => !detailedSleeps.contains(sleep)).toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, sleep) in detailedSleeps.indexed) ...[
          _sleepLongCard(
            context,
            sleep,
            title: _sleepSegmentTitle(context, sleep),
            stageLabels: stageLabels,
          ),
          if (_sleepStructureValues(
            context,
            sleep,
            stageLabels,
          ).isNotEmpty) ...[
            const SizedBox(height: 8),
            _sleepStructureCard(context, sleep, stageLabels),
          ],
          if (sleep.averageHeartRate != null ||
              sleep.averageBloodOxygen != null ||
              sleep.heartRatePoints.isNotEmpty ||
              sleep.bloodOxygenPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sleepVitalsCard(context, sleep),
          ],
          if (sleep.averageHrv != null || sleep.hrvPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sleepHrvCard(context, sleep),
          ],
          if (index < detailedSleeps.length - 1) const SizedBox(height: 12),
        ],
        if (naps.isNotEmpty) ...[
          if (detailedSleeps.isNotEmpty) const SizedBox(height: 12),
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.deviceHealthNap,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final (index, nap) in naps.indexed) ...[
                  if (index > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_period == HealthChartPeriod.day ? '' : '${_date(nap.endedAt)} · '}'
                          '${_sleepClock(nap.startedAt)} – ${_sleepClock(nap.endedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        _sleepDuration(context, nap.durationSeconds),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _sleepSegmentTitle(BuildContext context, HealthSleepSummary sleep) {
    final l10n = AppLocalizations.of(context)!;
    final kind = sleep.isLongSleep
        ? l10n.deviceHealthLongSleep
        : AppLocalizations.of(context)!.deviceHealthNapSingular;
    return _period == HealthChartPeriod.day
        ? kind
        : '${_date(sleep.endedAt)} · $kind';
  }

  Widget _sleepLongCard(
    BuildContext context,
    HealthSleepSummary sleep, {
    required String title,
    required Map<HealthSleepStageKind, String> stageLabels,
  }) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _sleepDuration(context, sleep.durationSeconds),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_sleepClock(sleep.startedAt)} – ${_sleepClock(sleep.endedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sleep.stages.isNotEmpty) ...[
            const SizedBox(height: 16),
            HealthSleepTimeline(summary: sleep, stageLabels: stageLabels),
          ],
        ],
      ),
    );
  }

  Widget _sleepStructureCard(
    BuildContext context,
    HealthSleepSummary sleep,
    Map<HealthSleepStageKind, String> stageLabels,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final values = _sleepStructureValues(context, sleep, stageLabels);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceHealthSleepStructure,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          if (values.isEmpty)
            Text(l10n.deviceHealthSleepNoStages)
          else
            for (final (index, value) in values.indexed) ...[
              if (index > 0) const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: value.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(value.label)),
                  if (value.kind == HealthSleepStageKind.awake)
                    Text(
                      value.count != null
                          ? l10n.deviceHealthSleepWakeCount(value.count!)
                          : '—',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    Text('${value.percent}%'),
                  const SizedBox(width: 24),
                  Text(
                    _sleepDuration(context, value.seconds),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _sleepHrvCard(BuildContext context, HealthSleepSummary sleep) {
    final l10n = AppLocalizations.of(context)!;
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceHealthSleepHrv,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          HealthSleepHrvChart(summary: sleep),
        ],
      ),
    );
  }

  Widget _sleepVitalsCard(BuildContext context, HealthSleepSummary sleep) {
    final l10n = AppLocalizations.of(context)!;
    final heartRatePoints = [...sleep.heartRatePoints]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final bloodOxygenPoints = [...sleep.bloodOxygenPoints]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final hasHeartRate = heartRatePoints.isNotEmpty;
    final series = <_WorkoutChartSeries>[];
    if (hasHeartRate) {
      series.add(
        _WorkoutChartSeries(
          label: l10n.deviceHealthChartHeartRate,
          unit: 'bpm',
          color: Theme.of(context).colorScheme.error,
          axis: _WorkoutChartAxis.left,
          points: heartRatePoints
              .map((point) => (point.timestamp, point.value.toDouble()))
              .toList(growable: false),
        ),
      );
    }
    if (bloodOxygenPoints.isNotEmpty) {
      series.add(
        _WorkoutChartSeries(
          label: l10n.deviceHealthChartBloodOxygen,
          unit: '%',
          color: Theme.of(context).colorScheme.primary,
          axis: hasHeartRate ? _WorkoutChartAxis.right : _WorkoutChartAxis.left,
          points: bloodOxygenPoints
              .map((point) => (point.timestamp, point.value.toDouble()))
              .toList(growable: false),
        ),
      );
    }
    final points = series.expand((value) => value.points).toList()
      ..sort((left, right) => left.$1.compareTo(right.$1));
    final entries = <(String, String)>[];
    final averageHeartRate =
        sleep.averageHeartRate ?? _averageSleepVital(heartRatePoints);
    final averageBloodOxygen =
        sleep.averageBloodOxygen ?? _averageSleepVital(bloodOxygenPoints);
    if (averageHeartRate != null) {
      entries.add((
        l10n.deviceHealthSleepAverageHeartRate,
        '$averageHeartRate bpm',
      ));
    }
    if (averageBloodOxygen != null) {
      entries.add((
        l10n.deviceHealthSleepAverageBloodOxygen,
        '$averageBloodOxygen%',
      ));
    }
    final scheme = Theme.of(context).colorScheme;
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.deviceHealthSleepDetails,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (series.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final value in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: value.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${value.label} · ${value.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 206,
              child: _WorkoutFlChart(
                series: series,
                gridColor: scheme.outlineVariant,
                surfaceColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _clock(points.first.$1),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _clock(points.last.$1),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (entries.isNotEmpty) ...[
            SizedBox(height: series.isEmpty ? 12 : 14),
            _HealthSummaryStats(columns: 2, entries: entries),
          ],
        ],
      ),
    );
  }

  int? _averageSleepVital(List<HealthSleepVitalPoint> points) {
    if (points.isEmpty) return null;
    final sum = points.fold<int>(0, (total, point) => total + point.value);
    return (sum / points.length).round();
  }

  List<_SleepStructureValue> _sleepStructureValues(
    BuildContext context,
    HealthSleepSummary sleep,
    Map<HealthSleepStageKind, String> labels,
  ) {
    const orderedKinds = [
      HealthSleepStageKind.deep,
      HealthSleepStageKind.light,
      HealthSleepStageKind.rem,
      HealthSleepStageKind.awake,
    ];
    final semanticColors = context.appColors;
    final colors = <HealthSleepStageKind, Color>{
      HealthSleepStageKind.deep: semanticColors.sleepDeep,
      HealthSleepStageKind.light: semanticColors.sleepLight,
      HealthSleepStageKind.rem: semanticColors.sleepRem,
      HealthSleepStageKind.awake: semanticColors.sleepAwake,
    };
    final reportedSeconds = <HealthSleepStageKind, int?>{
      HealthSleepStageKind.deep: sleep.deepSleepDurationSeconds,
      HealthSleepStageKind.light: sleep.lightSleepDurationSeconds,
      HealthSleepStageKind.rem: sleep.remSleepDurationSeconds,
      HealthSleepStageKind.awake: sleep.awakeDurationSeconds,
    };
    final kinds = orderedKinds
        .where((kind) {
          final reported = reportedSeconds[kind];
          return (reported != null && reported > 0) ||
              sleep.stages.any((stage) => stage.kind == kind);
        })
        .toList(growable: false);
    final seconds = kinds
        .map((kind) {
          final reported = reportedSeconds[kind];
          return reported != null && reported > 0
              ? reported
              : _stageSeconds(sleep, kind);
        })
        .map((value) => value < 0 ? 0 : value)
        .toList(growable: false);

    // Deep, light, and REM percentages are relative to total asleep time
    // (excluding awake time), so that the 3 sleep stages sum to 100%,
    // matching Xiaomi / Mi Fitness standard.
    final asleepKinds =
        kinds.where((kind) => kind != HealthSleepStageKind.awake).toList();
    final asleepSeconds = [
      for (var i = 0; i < kinds.length; i++)
        if (kinds[i] != HealthSleepStageKind.awake) seconds[i],
    ];
    final asleepTotal = asleepSeconds.fold<int>(0, (sum, val) => sum + val);
    final asleepPercentages = _sleepPercentages(asleepSeconds, asleepTotal);

    final asleepPercentMap = <HealthSleepStageKind, int>{
      for (var i = 0; i < asleepKinds.length; i++)
        asleepKinds[i]: asleepPercentages[i],
    };

    final wakeCount =
        sleep.wakeCount ??
        (sleep.stages.where((s) => s.kind == HealthSleepStageKind.awake).length);

    return [
      for (var index = 0; index < kinds.length; index++)
        _SleepStructureValue(
          kind: kinds[index],
          label: labels[kinds[index]] ?? kinds[index].name,
          seconds: seconds[index],
          percent: asleepPercentMap[kinds[index]] ?? 0,
          color: colors[kinds[index]]!,
          count: kinds[index] == HealthSleepStageKind.awake ? wakeCount : null,
        ),
    ];
  }

  int _stageSeconds(HealthSleepSummary sleep, HealthSleepStageKind kind) =>
      sleep.stages
          .where((stage) => stage.kind == kind)
          .fold(
            0,
            (sum, stage) =>
                sum + (stage.durationSeconds < 0 ? 0 : stage.durationSeconds),
          );


}
