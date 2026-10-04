import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/pages/health_detail_components.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_workout_page.dart';

part 'sections/health_detail_trend_widgets.dart';
part 'sections/health_detail_sleep_section.dart';
part 'sections/health_detail_vitals_section.dart';

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
    if (args.metric == XiaomiHealthMetric.workout) {
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  reverseDuration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<Object>(
                      '${args.metric.name}:${_period.name}:'
                      '${_currentRange.start.millisecondsSinceEpoch}',
                    ),
                    child: _workouts(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }
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
      XiaomiHealthMetric.workout => throw StateError('Handled above'),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                reverseDuration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(.035, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<Object>(
                    '${args.metric.name}:${_period.name}:'
                    '${_currentRange.start.millisecondsSinceEpoch}',
                  ),
                  child: content,
                ),
              ),
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
      HealthChartPeriod.day => healthAddCalendarDays(_anchorDate, amount),
      HealthChartPeriod.week => healthAddCalendarDays(_anchorDate, amount * 7),
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


  Widget _activity(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final range = _currentRange;
    final values = _activityValues(range);
    if (_period == HealthChartPeriod.day) {
      final samples = _activitySamplesForDay(range.start);
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActivityMetricCard(
            title: l10n.deviceHealthActiveCalories,
            value: _withUnit(values.activeCalories, 'kcal'),
            chart: ActivityHourlyChart(
              values: _activityHourlySeries(
                samples,
                (sample) => sample.activeCalories,
                XiaomiHealthMetric.activeCalories,
              ),
              start: range.start,
              end: range.end,
              color: colors.primary,
              gridColor: colors.outlineVariant,
            ),
          ),
          const SizedBox(height: 12),
          _ActivityMetricCard(
            title: l10n.deviceHealthSteps,
            value: _number(values.steps),
            chart: ActivityHourlyChart(
              values: _activityHourlySeries(
                samples,
                (sample) => sample.steps,
                XiaomiHealthMetric.activity,
              ),
              start: range.start,
              end: range.end,
              color: colors.tertiary,
              gridColor: colors.outlineVariant,
            ),
          ),
          const SizedBox(height: 12),
          _ActivityMetricCard(
            title: l10n.deviceHealthStanding,
            value: _withUnit(values.standingHours, 'h'),
            chart: ActivityHourlyChart(
              values: _standingHourlySeries(range.start, samples),
              start: range.start,
              end: range.end,
              color: colors.secondary,
              gridColor: colors.outlineVariant,
              showYAxis: false,
            ),
          ),
        ],
      );
    }
    final chartDays = _activityChartDaysInRange(range);
    final activitySamples = args.data.activitySamples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(range.start) &&
              sample.timestamp.isBefore(range.end),
        )
        .toList();
    final chartMetric = args.metric == XiaomiHealthMetric.activeCalories
        ? XiaomiHealthMetric.activeCalories
        : XiaomiHealthMetric.activity;
    final activityColors = Theme.of(context).colorScheme;
    final chartColor = chartMetric == XiaomiHealthMetric.activeCalories
        ? activityColors.primary
        : activityColors.tertiary;
    final hasTrend = _period == HealthChartPeriod.day
        ? activitySamples.isNotEmpty
        : chartDays.any(
            (day) =>
                (chartMetric == XiaomiHealthMetric.activity
                    ? day.steps
                    : day.activeCalories) !=
                null,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveHealthCardWrap(
          children: [
            _ActivityMetricCard(
              title: l10n.deviceHealthActiveCalories,
              value: _withUnit(values.activeCalories, 'kcal'),
            ),
            _ActivityMetricCard(
              title: l10n.deviceHealthSteps,
              value: _number(values.steps),
            ),
            _ActivityMetricCard(
              title: l10n.deviceHealthStanding,
              value: _withUnit(values.standingHours, 'h'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chartMetric == XiaomiHealthMetric.activity
                    ? l10n.deviceHealthSteps
                    : l10n.deviceHealthActiveCalories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (!hasTrend)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(l10n.deviceHealthNoSamples)),
                )
              else if (_period == HealthChartPeriod.day)
                ActivityTimelineChart(
                  samples: activitySamples,
                  start: range.start,
                  end: range.end,
                  useCalories: chartMetric == XiaomiHealthMetric.activeCalories,
                  height: 188,
                )
              else
                HealthOfficialRangeChart(
                  metric: chartMetric,
                  period: _period,
                  samples: const [],
                  days: chartDays,
                  color: chartColor,
                  start: range.start,
                  end: range.end,
                  height: 188,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _series(BuildContext context) {
    return _HealthTrendSection(
      data: args.data,
      metric: args.metric,
      color: _color(context, args.metric),
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
              day.vitalityIncreaseHigh != null ||
              day.vitalityLast7Days != null ||
              day.trainingLoadToday != null ||
              day.trainingLoadLast7Days != null,
        )
        .toList(growable: false);
    final day = days.isEmpty ? null : days.last;
    final light = _sum(days.map((value) => value.vitalityIncreaseLight));
    final moderate = _sum(days.map((value) => value.vitalityIncreaseModerate));
    final high = _sum(days.map((value) => value.vitalityIncreaseHigh));
    if (day == null) {
      return _DetailCard(child: Text(l10n.deviceHealthNoData));
    }
    // The device's embedded 7-day field is not reliable when a day is zero
    // (it is sometimes calculated over the last seven non-zero days). Build
    // the calendar-window total locally and retain explicit zeroes.
    final vitalityScore = _vitalitySevenDayTotal(day);
    final trainingValues = <(String, String)>[
      if (day.remainingRecoveryHours != null)
        (
          AppLocalizations.of(context)!.deviceHealthRecoveryTime,
          '${day.remainingRecoveryHours} h',
        ),
      if (day.trainingLoadToday != null)
        (
          AppLocalizations.of(context)!.deviceHealthTodayLoad,
          '${day.trainingLoadToday}',
        ),
      if (day.trainingLoadLast7Days != null)
        (
          AppLocalizations.of(context)!.deviceHealthSevenDayLoad,
          '${day.trainingLoadLast7Days}',
        ),
      if (day.trainingLoadLevel != null)
        (
          AppLocalizations.of(context)!.deviceHealthLoadLevel,
          '${day.trainingLoadLevel}',
        ),
      if (day.fitnessBalance != null)
        (
          AppLocalizations.of(context)!.deviceHealthFitnessBalance,
          '${day.fitnessBalance}',
        ),
      if (day.fitnessLevel != null)
        (
          AppLocalizations.of(context)!.deviceHealthFitnessLevel,
          '${day.fitnessLevel}',
        ),
      if (day.fatigueLevel != null)
        (
          AppLocalizations.of(context)!.deviceHealthFatigueLevel,
          '${day.fatigueLevel}',
        ),
      if (day.trainingStressScore != null)
        (
          AppLocalizations.of(context)!.deviceHealthTrainingStress,
          '${day.trainingStressScore}',
        ),
    ];
    final theme = Theme.of(context);
    final vitalityColor = _color(context, XiaomiHealthMetric.vitality);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    color: vitalityColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.deviceHealthVitality,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deviceHealthCurrentVitality,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _number(day.vitalityCurrent ?? vitalityScore),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.deviceHealthSevenDayVitality,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _number(vitalityScore),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: vitalityScore == null
                      ? 0
                      : (vitalityScore / 100).clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: vitalityColor,
                ),
              ),
              if (day.vitalityNextTargetMinutes != null) ...[
                const SizedBox(height: 6),
                Text(
                  day.vitalityNextTargetType == 1
                      ? l10n.deviceHealthVitalityRunSuggestion(
                          day.vitalityNextTargetMinutes!,
                        )
                      : l10n.deviceHealthVitalityActiveMinutes(
                          day.vitalityNextTargetMinutes!,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _period == HealthChartPeriod.day
                    ? l10n.deviceHealthEarnedToday
                    : l10n.deviceHealthEarnedInPeriod,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _HealthSummaryStats(
                columns: 3,
                entries: [
                  (l10n.deviceHealthLightIntensity, _number(light)),
                  (l10n.deviceHealthModerateIntensity, _number(moderate)),
                  (l10n.deviceHealthHighIntensity, _number(high)),
                ],
              ),
            ],
          ),
        ),
        if (trainingValues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deviceHealthTrainingStatus,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _MetricGrid(values: trainingValues),
              ],
            ),
          ),
        ],
      ],
    );
  }


  Widget _workouts(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final range = _currentRange;
    final workouts = args.data.workouts
        .where(
          (workout) =>
              workout.startedAt.toLocal().isBefore(range.end) &&
              !workout.endedAt.toLocal().isBefore(range.start),
        )
        .toList();
    if (workouts.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoWorkouts));
    }
    workouts.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _workoutPeriodSummary(context, workouts),
        const SizedBox(height: 12),
        for (final workout in workouts) ...[
          _DetailCard(
            onTap: () => _openWorkout(context, workout),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      workoutIcon(workout),
                      color: healthWorkoutVisualColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workoutName(context, workout),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${_date(workout.startedAt)} · '
                            '${_clock(workout.startedAt)}–${_clock(workout.endedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _duration(
                        workout.totalDurationSeconds ??
                            workout.endedAt
                                .difference(workout.startedAt)
                                .inSeconds,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).hintColor,
                    ),
                  ],
                ),
                if (workout.distanceMeters != null ||
                    workout.calories != null ||
                    workout.effectiveAverageHeartRate != null ||
                    healthWorkoutSupportsPace(workout)) ...[
                  const SizedBox(height: 12),
                  _HealthSummaryStats(
                    columns: healthWorkoutSupportsPace(workout) ? 4 : 3,
                    entries: [
                      (
                        l10n.deviceHealthDistance,
                        workout.distanceMeters == null
                            ? '—'
                            : workoutDistance(workout.distanceMeters!),
                      ),
                      (
                        l10n.deviceHealthCalories,
                        workout.calories == null
                            ? '—'
                            : '${workout.calories} kcal',
                      ),
                      (
                        l10n.deviceHealthAverageHeartRateLabel,
                        workout.effectiveAverageHeartRate == null
                            ? '—'
                            : '${workout.effectiveAverageHeartRate} bpm',
                      ),
                      if (healthWorkoutSupportsPace(workout))
                        (
                          l10n.deviceHealthAveragePace,
                          workoutPace(workout.averagePaceSecondsPerKilometer!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _openWorkout(BuildContext context, HealthWorkoutSummary workout) {
    final routeId = Uri.encodeComponent(xiaomiHealthWorkoutRouteId(workout));
    final extra = XiaomiHealthWorkoutRouteArgs(health: args, workout: workout);
    if (GoRouter.maybeOf(context) != null) {
      context.push(
        '/devices/velaos-health/detail/workout/$routeId',
        extra: extra,
      );
      return;
    }
    // Keep this widget usable in isolated previews/tests that intentionally
    // do not install the application's GoRouter above the page.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _WorkoutDetailPage(workout: workout),
      ),
    );
  }

  Widget _workoutPeriodSummary(
    BuildContext context,
    List<HealthWorkoutSummary> workouts,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final duration = workouts.fold<int>(
      0,
      (total, workout) =>
          total +
          (workout.totalDurationSeconds ??
              workout.endedAt.difference(workout.startedAt).inSeconds),
    );
    final distanceValues = workouts
        .map((workout) => workout.distanceMeters)
        .whereType<int>()
        .toList(growable: false);
    final distance = distanceValues.fold<int>(
      0,
      (total, value) => total + value,
    );
    final calorieValues = workouts
        .map((workout) => workout.calories)
        .whereType<int>()
        .toList(growable: false);
    final calories = calorieValues.fold<int>(
      0,
      (total, value) => total + value,
    );
    final heartRates = workouts
        .map((workout) => workout.effectiveAverageHeartRate)
        .whereType<int>()
        .toList(growable: false);
    final averageHeartRate = heartRates.isEmpty
        ? null
        : (heartRates.reduce((left, right) => left + right) / heartRates.length)
              .round();
    return _DetailCard(
      child: _HealthSummaryStats(
        columns: 4,
        entries: [
          (l10n.deviceHealthWorkoutDuration, _duration(duration)),
          (
            l10n.deviceHealthDistance,
            distanceValues.isEmpty ? '—' : workoutDistance(distance),
          ),
          (
            l10n.deviceHealthCalories,
            calorieValues.isEmpty ? '—' : '$calories kcal',
          ),
          (
            l10n.deviceHealthAverageHeartRateLabel,
            averageHeartRate == null ? '—' : '$averageHeartRate bpm',
          ),
        ],
      ),
    );
  }

  List<_ActivityDayValues> _activityDaysInRange(_HealthDateRange range) => [
    for (
      var offset = 0;
      offset < healthCalendarDaysBetween(range.start, range.end);
      offset++
    )
      _activityDayValues(healthAddCalendarDays(range.start, offset)),
  ].where((day) => day.hasValue).toList(growable: false);

  List<HealthDailySummary> _activityChartDaysInRange(_HealthDateRange range) =>
      [
        for (
          var offset = 0;
          offset < healthCalendarDaysBetween(range.start, range.end);
          offset++
        )
          _activityDaySummary(healthAddCalendarDays(range.start, offset)),
      ];

  HealthDailySummary _activityDaySummary(DateTime date) {
    final values = _activityDayValues(date);
    return HealthDailySummary(
      date: values.date,
      steps: values.steps,
      activeCalories: values.activeCalories,
    );
  }

  List<HealthDailySummary> _dailyDaysInRange(_HealthDateRange range) =>
      args.data.daily.where((day) {
        final date = _dateOnly(day.date);
        return !date.isBefore(range.start) && date.isBefore(range.end);
      }).toList()..sort((left, right) => left.date.compareTo(right.date));

  int? _vitalitySevenDayTotal(HealthDailySummary anchor) =>
      args.data.vitalitySevenDayTotal(anchor);

  List<HealthActivitySample> _activitySamplesForDay(DateTime date) => args
      .data
      .activitySamples
      .where((sample) => _sameDate(sample.timestamp, date))
      .toList(growable: false);

  List<double> _activityHourlySeries(
    List<HealthActivitySample> samples,
    int? Function(HealthActivitySample sample) valueFor,
    XiaomiHealthMetric metric,
  ) {
    const slots = 24;
    final values = List<double>.filled(slots, 0);
    for (final sample in samples) {
      final value = valueFor(sample);
      if (value == null || value < 0) continue;
      final hour = sample.timestamp.toLocal().hour;
      if (hour >= 0 && hour < slots) values[hour] += value;
    }
    if (values.any((value) => value > 0)) return values;
    for (final sample in args.data.samples) {
      if (sample.metric != metric || !sample.isUsable) continue;
      final hour = sample.timestamp.toLocal().hour;
      if (hour >= 0 && hour < slots) values[hour] += sample.value;
    }
    return values;
  }

  List<double> _standingHourlySeries(
    DateTime date,
    List<HealthActivitySample> samples,
  ) {
    final activitySummary = args.data.activitySummary;
    final day =
        _dailyDaysInRange(
          _HealthDateRange(start: date, end: healthAddCalendarDays(date, 1)),
        ).firstOrNull ??
        (activitySummary != null && _sameDate(activitySummary.date, date)
            ? activitySummary
            : null);
    final bitmap = day?.standingBitmap;
    if (bitmap != null) {
      return [
        for (var hour = 0; hour < 24; hour++) ((bitmap >> hour) & 1).toDouble(),
      ];
    }
    final values = List<double>.filled(24, 0);
    for (final sample in samples) {
      if ((sample.steps ?? 0) <= 0) continue;
      final hour = sample.timestamp.toLocal().hour;
      if (hour >= 0 && hour < values.length) values[hour] = 1;
    }
    return values;
  }

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
    final rawActivitySamples = args.data.activitySamples.where(
      (sample) => _sameDate(sample.timestamp, normalized),
    );
    int? sum(XiaomiHealthMetric metric) {
      final values = activitySamples
          .where((sample) => sample.metric == metric)
          .map((sample) => sample.value)
          .toList(growable: false);
      if (values.isNotEmpty) {
        return values.fold<double>(0, (total, value) => total + value).round();
      }
      final rawValues = rawActivitySamples
          .map(
            (sample) => switch (metric) {
              XiaomiHealthMetric.activity => sample.steps,
              XiaomiHealthMetric.activeCalories => sample.activeCalories,
              _ => null,
            },
          )
          .whereType<int>();
      final raw = rawValues.toList(growable: false);
      if (raw.isEmpty) return null;
      return raw.reduce((left, right) => left + right);
    }

    final standingHours =
        summary?.standingHours ??
        (() {
          final hours = activitySamples
              .where((sample) => sample.metric == XiaomiHealthMetric.activity)
              .map((sample) => sample.timestamp.toLocal().hour)
              .toSet();
          if (hours.isEmpty) {
            hours.addAll(
              rawActivitySamples
                  .where((sample) => (sample.steps ?? 0) > 0)
                  .map((sample) => sample.timestamp.toLocal().hour),
            );
          }
          return hours.length;
        })();
    final result = _ActivityDayValues(
      date: normalized,
      steps: summary?.steps ?? sum(XiaomiHealthMetric.activity),
      activeCalories:
          summary?.activeCalories ?? sum(XiaomiHealthMetric.activeCalories),
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


