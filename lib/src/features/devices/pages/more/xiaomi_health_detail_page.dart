import 'package:flutter/material.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

class XiaomiHealthDetailArgs {
  const XiaomiHealthDetailArgs({required this.metric, required this.data});

  final XiaomiHealthMetric metric;
  final XiaomiHealthData data;
}

class XiaomiHealthDetailPage extends StatefulWidget {
  const XiaomiHealthDetailPage({super.key, required this.args});

  final XiaomiHealthDetailArgs args;

  @override
  State<XiaomiHealthDetailPage> createState() => _XiaomiHealthDetailPageState();
}

class _XiaomiHealthDetailPageState extends State<XiaomiHealthDetailPage> {
  late HealthChartPeriod _period;
  late DateTime _anchorDate;

  XiaomiHealthDetailArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    _period = HealthChartPeriod.day;
    _anchorDate = _initialAnchorDate(args.data, args.metric);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(_title(l10n, args.metric)),
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
        sections: _sections(context),
      ),
    );
  }

  List<AbstractSegmentedSection> _sections(BuildContext context) {
    final content = switch (args.metric) {
      XiaomiHealthMetric.activity => _activity(context),
      XiaomiHealthMetric.activeCalories => _activity(context),
      XiaomiHealthMetric.heartRate => _heartRate(context),
      XiaomiHealthMetric.restingHeartRate => _restingHeartRate(context),
      XiaomiHealthMetric.bloodOxygen => _seriesWithAbnormal(
        context,
        HealthAbnormalHealthKind.lowBloodOxygen,
      ),
      XiaomiHealthMetric.stress => _seriesWithAbnormal(
        context,
        HealthAbnormalHealthKind.highStress,
      ),
      XiaomiHealthMetric.vitality => _vitality(context),
      XiaomiHealthMetric.sleep => _sleep(context),
      XiaomiHealthMetric.workout => _workouts(context),
    };
    return [
      CustomSegmentedSection(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              _HealthPeriodHeader(
                period: _period,
                anchorDate: _anchorDate,
                canGoForward: _canGoForward,
                onPeriodChanged: (period) => setState(() => _period = period),
                onPrevious: () => _shiftPeriod(-1),
                onNext: _canGoForward ? () => _shiftPeriod(1) : null,
              ),
              const SizedBox(height: 20),
              content,
            ],
          ),
        ),
      ),
    ];
  }

  _HealthDateRange get _currentRange =>
      _healthPeriodRange(_period, _anchorDate);

  bool get _canGoForward {
    final current = _healthPeriodRange(
      _period,
      _dateOnly(DateTime.now()),
    ).start;
    return _currentRange.start.isBefore(current);
  }

  void _shiftPeriod(int amount) {
    final next = switch (_period) {
      HealthChartPeriod.day => _anchorDate.add(Duration(days: amount)),
      HealthChartPeriod.week => _anchorDate.add(Duration(days: amount * 7)),
      HealthChartPeriod.month => DateTime(
        _anchorDate.year,
        _anchorDate.month + amount,
        1,
      ),
    };
    final normalized = _dateOnly(next);
    if (amount > 0 &&
        _healthPeriodRange(_period, normalized).start.isAfter(
          _healthPeriodRange(_period, _dateOnly(DateTime.now())).start,
        )) {
      return;
    }
    setState(() => _anchorDate = normalized);
  }

  Widget _heartRate(BuildContext context) {
    final content = <Widget>[_series(context)];
    const kinds = [
      HealthAbnormalHealthKind.highHeartRate,
      HealthAbnormalHealthKind.lowHeartRate,
      HealthAbnormalHealthKind.irregularHeartbeat,
    ];
    final availableKinds = kinds
        .where((kind) => _abnormalRecords({kind}).isNotEmpty)
        .toList(growable: false);
    if (availableKinds.isNotEmpty) {
      content
        ..add(const SizedBox(height: 16))
        ..add(_heartHealthMonitoring(context, availableKinds));
    }
    return Column(children: content);
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
    return Column(children: content);
  }

  Widget _restingHeartRate(BuildContext context) {
    return _HealthTrendSection(
      data: args.data,
      metric: XiaomiHealthMetric.restingHeartRate,
      color: _color(XiaomiHealthMetric.restingHeartRate),
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
              Icon(_abnormalIcon(kind), color: _abnormalColor(kind)),
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
            if (index > 0) const Divider(height: 18),
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

  Color _abnormalColor(HealthAbnormalHealthKind kind) => switch (kind) {
    HealthAbnormalHealthKind.highHeartRate ||
    HealthAbnormalHealthKind.lowHeartRate ||
    HealthAbnormalHealthKind.irregularHeartbeat => Colors.redAccent,
    HealthAbnormalHealthKind.lowBloodOxygen => Colors.indigo,
    HealthAbnormalHealthKind.highStress => Colors.orange,
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

  Widget _activity(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final range = _currentRange;
    final values = _activityValues(range);
    final days = _activityDaysInRange(range);
    final periodDays = range.end.difference(range.start).inDays;
    final showDailyBreakdown = days.length > 1;
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActivityRingsChart(
                activeCalories: values.activeCalories,
                steps: values.steps,
                standingHours: values.standingHours,
                activeCaloriesTarget: 500 * periodDays,
                stepsTarget: 10000 * periodDays,
                standingTarget: 12 * periodDays,
                height: 196,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Stat(
                    label: l10n.deviceHealthActiveCalories,
                    value: _withUnit(values.activeCalories, 'kcal'),
                  ),
                  _Stat(
                    label: l10n.deviceHealthSteps,
                    value: _number(values.steps),
                  ),
                  _Stat(
                    label: l10n.deviceHealthStanding,
                    value: _withUnit(values.standingHours, 'h'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDailyBreakdown) ...[
          const SizedBox(height: 16),
          for (final day in days.reversed) ...[
            _DetailCard(
              child: Row(
                children: [
                  Expanded(child: Text(_date(day.date))),
                  Text(
                    day.steps == null
                        ? '—'
                        : l10n.deviceHealthStepValue(_number(day.steps)),
                  ),
                  const SizedBox(width: 16),
                  Text(_withUnit(day.activeCalories, 'kcal')),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _series(BuildContext context) {
    return _HealthTrendSection(
      data: args.data,
      metric: args.metric,
      color: _color(args.metric),
      period: _period,
      anchorDate: _anchorDate,
    );
  }

  Widget _vitality(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final days = _dailyDaysInRange(_currentRange)
        .where(
          (day) =>
              day.vitalityCurrent != null ||
              day.vitalityIncreaseLight != null ||
              day.vitalityIncreaseModerate != null ||
              day.vitalityIncreaseHigh != null,
        )
        .toList(growable: false);
    final day = days.isEmpty ? null : days.last;
    final light = days.isEmpty
        ? day?.vitalityIncreaseLight
        : _sum(days.map((value) => value.vitalityIncreaseLight));
    final moderateHigh = days.isEmpty
        ? (day?.vitalityIncreaseModerate ?? 0) +
              (day?.vitalityIncreaseHigh ?? 0)
        : _sum(
            days.map(
              (value) =>
                  (value.vitalityIncreaseModerate ?? 0) +
                  (value.vitalityIncreaseHigh ?? 0),
            ),
          );
    return _DetailCard(
      child: Row(
        children: [
          _Stat(
            label: l10n.deviceHealthCurrentVitality,
            value: _number(day?.vitalityCurrent),
          ),
          _Stat(label: l10n.deviceHealthLightIntensity, value: _number(light)),
          _Stat(
            label: l10n.deviceHealthModerateHighIntensity,
            value: _number(moderateHigh),
          ),
        ],
      ),
    );
  }

  Widget _sleep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sleeps = args.data.sleep
        .where(
          (sleep) => _overlaps(_currentRange, sleep.startedAt, sleep.endedAt),
        )
        .toList(growable: false);
    if (sleeps.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoSleep));
    }
    final sortedSleeps = [...sleeps]
      ..sort((left, right) {
        final endComparison = right.endedAt.compareTo(left.endedAt);
        if (endComparison != 0) return endComparison;
        return right.startedAt.compareTo(left.startedAt);
      });
    final visibleSleeps = _period == HealthChartPeriod.day
        ? sortedSleeps.take(1).toList(growable: false)
        : sortedSleeps;
    final stageLabels = <HealthSleepStageKind, String>{
      HealthSleepStageKind.awake: l10n.deviceHealthSleepAwake,
      HealthSleepStageKind.rem: l10n.deviceHealthSleepRem,
      HealthSleepStageKind.light: l10n.deviceHealthSleepLight,
      HealthSleepStageKind.deep: l10n.deviceHealthSleepDeep,
    };
    return Column(
      children: [
        for (final (index, sleep) in visibleSleeps.indexed) ...[
          _sleepLongCard(
            context,
            sleep,
            title: index == 0
                ? l10n.deviceHealthLongSleep
                : _date(sleep.startedAt),
            stageLabels: stageLabels,
          ),
          const SizedBox(height: 8),
          _sleepStructureCard(context, sleep, stageLabels),
          if (sleep.averageHrv != null || sleep.hrvPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sleepHrvCard(context, sleep),
          ],
          if (sleep.averageHeartRate != null ||
              sleep.averageBloodOxygen != null) ...[
            const SizedBox(height: 8),
            _sleepVitalsCard(context, sleep),
          ],
          if (index < visibleSleeps.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _sleepLongCard(
    BuildContext context,
    HealthSleepSummary sleep, {
    required String title,
    required Map<HealthSleepStageKind, String> stageLabels,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
          const SizedBox(height: 16),
          if (sleep.stages.isEmpty)
            Text(l10n.deviceHealthSleepNoStages)
          else
            HealthSleepTimeline(summary: sleep, stageLabels: stageLabels),
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
    final values = _sleepStructureValues(sleep, stageLabels);
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
    final rows = <Widget>[];
    if (sleep.averageHeartRate != null) {
      rows.add(
        _sleepVitalRow(
          context,
          label: l10n.deviceHealthSleepAverageHeartRate,
          value: '${sleep.averageHeartRate} bpm',
        ),
      );
    }
    if (sleep.averageBloodOxygen != null) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 16));
      rows.add(
        _sleepVitalRow(
          context,
          label: l10n.deviceHealthSleepAverageBloodOxygen,
          value: '${sleep.averageBloodOxygen}%',
        ),
      );
    }
    return _DetailCard(child: Column(children: rows));
  }

  Widget _sleepVitalRow(
    BuildContext context, {
    required String label,
    required String value,
  }) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );

  List<_SleepStructureValue> _sleepStructureValues(
    HealthSleepSummary sleep,
    Map<HealthSleepStageKind, String> labels,
  ) {
    const orderedKinds = [
      HealthSleepStageKind.deep,
      HealthSleepStageKind.light,
      HealthSleepStageKind.rem,
    ];
    const colors = <HealthSleepStageKind, Color>{
      HealthSleepStageKind.deep: Color(0xFF2231B6),
      HealthSleepStageKind.light: Color(0xFF3986F6),
      HealthSleepStageKind.rem: Color(0xFF47BEFF),
    };
    final reportedSeconds = <HealthSleepStageKind, int?>{
      HealthSleepStageKind.deep: sleep.deepSleepDurationSeconds,
      HealthSleepStageKind.light: sleep.lightSleepDurationSeconds,
      HealthSleepStageKind.rem: sleep.remSleepDurationSeconds,
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
    final total = seconds.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return const [];
    final percentages = _sleepPercentages(seconds, total);
    return [
      for (var index = 0; index < kinds.length; index++)
        _SleepStructureValue(
          label: labels[kinds[index]] ?? kinds[index].name,
          seconds: seconds[index],
          percent: percentages[index],
          color: colors[kinds[index]]!,
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

  Widget _workouts(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workouts = [...args.data.workouts]
        .where(
          (workout) =>
              _overlaps(_currentRange, workout.startedAt, workout.endedAt),
        )
        .toList();
    if (workouts.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoWorkouts));
    }
    workouts.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return Column(
      children: [
        for (final workout in workouts) ...[
          _DetailCard(
            child: Row(
              children: [
                const Icon(Icons.directions_run_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(_date(workout.startedAt))),
                Text(
                  _duration(
                    workout.endedAt.difference(workout.startedAt).inSeconds,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<_ActivityDayValues> _activityDaysInRange(_HealthDateRange range) => [
    for (
      var offset = 0;
      offset < range.end.difference(range.start).inDays;
      offset++
    )
      _activityDayValues(range.start.add(Duration(days: offset))),
  ].where((day) => day.hasValue).toList(growable: false);

  List<HealthDailySummary> _dailyDaysInRange(_HealthDateRange range) =>
      args.data.daily.where((day) {
        final date = _dateOnly(day.date);
        return !date.isBefore(range.start) && date.isBefore(range.end);
      }).toList()..sort((left, right) => left.date.compareTo(right.date));

  _ActivityPeriodValues _activityValues(_HealthDateRange range) {
    final days = _activityDaysInRange(range);
    return _ActivityPeriodValues(
      steps: _sum(days.map((day) => day.steps)),
      activeCalories: _sum(days.map((day) => day.activeCalories)),
      standingHours: _sum(days.map((day) => day.standingHours)),
    );
  }

  _ActivityDayValues _activityDayValues(DateTime date) {
    final normalized = _dateOnly(date);
    HealthDailySummary? summary;
    for (final day in args.data.daily) {
      if (_sameDate(day.date, normalized)) summary = day;
    }
    final activitySummary = args.data.activitySummary;
    if (activitySummary != null &&
        _sameDate(activitySummary.date, normalized)) {
      summary ??= activitySummary;
    }
    final activitySamples = args.data.samples.where(
      (sample) =>
          (sample.metric == XiaomiHealthMetric.activity ||
              sample.metric == XiaomiHealthMetric.activeCalories) &&
          sample.isUsable &&
          _sameDate(sample.timestamp, normalized),
    );
    int? sum(XiaomiHealthMetric metric) {
      final values = activitySamples
          .where((sample) => sample.metric == metric)
          .map((sample) => sample.value)
          .toList(growable: false);
      if (values.isEmpty) return null;
      return values.fold<double>(0, (total, value) => total + value).round();
    }

    final standingHours =
        summary?.standingHours ??
        activitySamples
            .where((sample) => sample.metric == XiaomiHealthMetric.activity)
            .map((sample) => sample.timestamp.toLocal().hour)
            .toSet()
            .length;
    final result = _ActivityDayValues(
      date: normalized,
      steps: summary?.steps ?? sum(XiaomiHealthMetric.activity),
      activeCalories:
          summary?.activeCalories ??
          summary?.calories ??
          sum(XiaomiHealthMetric.activeCalories),
      standingHours: summary == null && activitySamples.isEmpty
          ? null
          : standingHours,
    );
    return result;
  }

  int? _sum(Iterable<int?> values) {
    final present = values.whereType<int>().toList(growable: false);
    if (present.isEmpty) return null;
    return present.reduce((left, right) => left + right);
  }

  String _withUnit(int? value, String unit) =>
      value == null ? '—' : '$value $unit'.trim();

  bool _overlaps(_HealthDateRange range, DateTime start, DateTime end) {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    return localStart.isBefore(range.end) && !localEnd.isBefore(range.start);
  }
}

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
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatMetric(stats.latest, unit),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              if (hasData)
                HealthOfficialRangeChart(
                  metric: metric,
                  period: period,
                  samples: samples,
                  days: days,
                  color: color,
                  start: range.start,
                  end: range.end,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56),
                  child: Center(child: Text(l10n.deviceHealthNoSamples)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailCard(
          child: Row(
            children: [
              _Stat(
                label: l10n.deviceHealthLatest,
                value: _formatMetric(stats.latest, ''),
              ),
              _Stat(
                label: l10n.deviceHealthAverage,
                value: _formatMetric(stats.average, ''),
              ),
              _Stat(
                label: l10n.deviceHealthRange,
                value: stats.minimum == null || stats.maximum == null
                    ? '—'
                    : '${_formatMetric(stats.minimum, '')}–'
                          '${_formatMetric(stats.maximum, '')}',
              ),
            ],
          ),
        ),
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
        offset < range.end.difference(range.start).inDays;
        offset++
      )
        existing[_dateKey(range.start.add(Duration(days: offset)))] ??
            HealthDailySummary(date: range.start.add(Duration(days: offset))),
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
      end: date.add(const Duration(days: 1)),
    ),
    HealthChartPeriod.week => _HealthDateRange(
      start: date.subtract(Duration(days: date.weekday - 1)),
      end: date
          .subtract(Duration(days: date.weekday - 1))
          .add(const Duration(days: 7)),
    ),
    HealthChartPeriod.month => _HealthDateRange(
      start: DateTime(date.year, date.month),
      end: DateTime(date.year, date.month + 1),
    ),
  };
}

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
    date.add(Duration(days: 4 - date.weekday)).year;

int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstMonday = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  return (thursday.difference(firstMonday).inDays ~/ 7) + 1;
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
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

Color _color(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate => Colors.redAccent,
  XiaomiHealthMetric.restingHeartRate => Colors.pinkAccent,
  XiaomiHealthMetric.bloodOxygen => Colors.indigo,
  XiaomiHealthMetric.stress => Colors.orange,
  _ => Colors.teal,
};

String _number(num? value) => value == null ? '—' : value.round().toString();
String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

String _sleepDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';

String _durationBetween(DateTime start, DateTime end) {
  final seconds = end.difference(start).inSeconds;
  return _duration(seconds < 0 ? 0 : seconds);
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
    required this.label,
    required this.seconds,
    required this.percent,
    required this.color,
  });

  final String label;
  final int seconds;
  final int percent;
  final Color color;
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
