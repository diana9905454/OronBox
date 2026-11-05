import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';

import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_fit_exporter.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/pages/health_detail_components.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_detail_page.dart'
    show XiaomiHealthDetailArgs;

typedef _DetailCard = HealthDetailCard;
typedef _HealthSummaryStats = HealthSummaryStats;

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

String _clock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// The in-memory preview passed while opening a workout from the current
/// health snapshot. The route still carries [workoutId], so a deep link or a
/// restored route can reload the record from the local health store.
class XiaomiHealthWorkoutRouteArgs {
  const XiaomiHealthWorkoutRouteArgs({
    required this.health,
    required this.workout,
  });

  final XiaomiHealthDetailArgs health;
  final HealthWorkoutSummary workout;
}

String xiaomiHealthWorkoutRouteId(HealthWorkoutSummary workout) =>
    '${workout.startedAt.toUtc().millisecondsSinceEpoch}-${workout.activityType}';

/// Route entry for a workout detail. A list tap supplies [preview] so the
/// page renders immediately; a direct/restored route reloads the same record
/// from the active device's local health store using [workoutId].
class XiaomiHealthWorkoutPage extends ConsumerStatefulWidget {
  const XiaomiHealthWorkoutPage({
    super.key,
    required this.workoutId,
    this.preview,
    this.deviceId,
  });

  final String workoutId;
  final String? deviceId;
  final HealthWorkoutSummary? preview;

  @override
  ConsumerState<XiaomiHealthWorkoutPage> createState() =>
      _XiaomiHealthWorkoutPageState();
}

class _XiaomiHealthWorkoutPageState
    extends ConsumerState<XiaomiHealthWorkoutPage> {
  HealthWorkoutSummary? _workout;
  Object? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _workout = widget.preview;
    unawaited(_loadWorkout());
  }

  Future<void> _loadWorkout() async {
    if (mounted) setState(() => _loading = true);
    try {
      final deviceId =
          widget.deviceId ??
          ref.read(deviceManagerProvider).currentDevice?.addr;
      final workout = deviceId == null
          ? null
          : await HealthStore().workout(deviceId, widget.workoutId);
      if (workout == null && _workout != null) return;
      if (workout == null) throw StateError('Workout record not found');
      if (mounted) setState(() => _workout = workout);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    if (workout != null) return WorkoutDetailPage(workout: workout);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.deviceHealthWorkout)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(
                _error == null
                    ? l10n.deviceHealthNoWorkouts
                    : l10n.deviceHealthLoadFailed,
              ),
      ),
    );
  }
}

class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({super.key, required this.workout});

  final HealthWorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = healthWorkoutVisualColor(context);
    final details = _workoutDetails(context, workout);
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(workoutName(context, workout)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: l10n.deviceHealthWorkoutExport,
            onPressed: () => _exportWorkout(context, workout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          bottomContentPadding(context, extra: 32),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StyleConstants.pageMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deviceHealthWorkoutDuration,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _duration(
                          workout.totalDurationSeconds ??
                              workout.endedAt
                                  .difference(workout.startedAt)
                                  .inSeconds,
                        ),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_date(workout.startedAt)} · '
                        '${_clock(workout.startedAt)}–${_clock(workout.endedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  child: _HealthSummaryStats(
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
                ),
                if (workout.route.length >= 2) ...[
                  const SizedBox(height: 12),
                  _WorkoutRouteCard(route: workout.route, color: color),
                ],
                if (_hasWorkoutChartSeries(workout)) ...[
                  const SizedBox(height: 12),
                  _WorkoutRecordSeriesCard(workout: workout),
                ],
                if (workout.heartRateZones.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _WorkoutHeartRateZonesCard(workout: workout),
                ],
                if (workout.samples.any(
                  (sample) =>
                      sample.swolf != null ||
                      sample.swimmingPaceSecondsPer100Meters != null,
                )) ...[
                  const SizedBox(height: 12),
                  _WorkoutSwimmingSectionsCard(workout: workout),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!
                              .deviceHealthWorkoutDetails,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 640 ? 3 : 2;
                            return _HealthSummaryStats(
                              entries: details,
                              columns: columns,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (workout.recovery != null) ...[
                  const SizedBox(height: 12),
                  _WorkoutRecoveryCard(recovery: workout.recovery!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _exportWorkout(
  BuildContext context,
  HealthWorkoutSummary workout,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final bytes = HealthWorkoutFitExporter.encode(workout);
    final local = workout.startedAt.toLocal();
    final fileName =
        'workout_${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}_'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}.fit';
    final saved = await FilePicker.saveFile(
      dialogTitle: l10n.deviceHealthWorkoutExport,
      fileName: fileName,
      mimeType: 'application/octet-stream',
      bytes: Uint8List.fromList(bytes),
    );
    if (!context.mounted || saved == null) return;
    final path = saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deviceHealthWorkoutExported(path))),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deviceHealthWorkoutExportFailed(error.toString())),
      ),
    );
  }
}

class _WorkoutSwimmingSectionsCard extends StatelessWidget {
  const _WorkoutSwimmingSectionsCard({required this.workout});

  final HealthWorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    final sections = workout.samples
        .where(
          (sample) =>
              sample.swolf != null ||
              sample.swimmingPaceSecondsPer100Meters != null,
        )
        .toList(growable: false);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.deviceHealthSwimmingSections,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final (index, section) in sections.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    _swimmingStrokeName(context, section.swimmingStroke),
                  ),
                ),
                if (section.swimmingPaceSecondsPer100Meters != null)
                  Text(
                    '${_shortDuration(section.swimmingPaceSecondsPer100Meters!)} /100m',
                  ),
                const SizedBox(width: 14),
                Text('SWOLF ${section.swolf ?? '—'}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkoutRecordSeriesCard extends StatelessWidget {
  const _WorkoutRecordSeriesCard({required this.workout});

  final HealthWorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    final series = _workoutChartSeries(context, workout);
    if (series.isEmpty) return const SizedBox.shrink();
    final points = series.expand((value) => value.points).toList()
      ..sort((left, right) => left.$1.compareTo(right.$1));
    if (points.isEmpty) return const SizedBox.shrink();
    final start = points.first.$1;
    final end = points.last.$1;
    final hasLeftAxis = series.any(
      (value) => value.axis == HealthChartAxis.left,
    );
    final hasRightAxis = series.any(
      (value) => value.axis == HealthChartAxis.right,
    );
    final scheme = Theme.of(context).colorScheme;
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.deviceHealthWorkoutCharts,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                      '${value.label}${value.unit.isEmpty ? '' : ' · ${value.unit}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 206,
            child: HealthFlChart(
              series: series,
              gridColor: scheme.outlineVariant,
              surfaceColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(width: hasLeftAxis ? _workoutYAxisReservedSize : 0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _clock(start),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _clock(end),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: hasRightAxis ? _workoutYAxisReservedSize : 0),
            ],
          ),
        ],
      ),
    );
  }
}

const _workoutYAxisReservedSize = 28.0;

bool _hasWorkoutChartSeries(HealthWorkoutSummary workout) =>
    workout.samples.any(
      (sample) =>
          sample.heartRate != null ||
          sample.cadence != null ||
          sample.paceSecondsPerKilometer != null ||
          sample.speedKph != null ||
          sample.powerWatts != null ||
          sample.strokeFrequency != null ||
          sample.jumpFrequency != null ||
          sample.bloodOxygen != null ||
          sample.stress != null,
    );

List<HealthChartSeries> _workoutChartSeries(
  BuildContext context,
  HealthWorkoutSummary workout,
) {
  final scheme = Theme.of(context).colorScheme;
  List<(DateTime, double)> points(double? Function(HealthWorkoutSample) read) {
    final result =
        workout.samples
            .map((sample) {
              final value = read(sample);
              // A non-finite value would poison the painter's bounds and can
              // produce NaN canvas coordinates, which hangs rasterization.
              if (value == null || !value.isFinite) return null;
              return (sample.timestamp, value);
            })
            .whereType<(DateTime, double)>()
            .toList()
          ..sort((left, right) => left.$1.compareTo(right.$1));
    return result;
  }

  HealthChartSeries? make({
    required String label,
    required String unit,
    required Color color,
    required HealthChartAxis axis,
    required double? Function(HealthWorkoutSample) read,
  }) {
    final values = points(read);
    return values.isEmpty
        ? null
        : HealthChartSeries(
            label: label,
            unit: unit,
            color: color,
            axis: axis,
            points: values,
          );
  }

  final result = <HealthChartSeries>[];
  final heartRate = make(
    label: AppLocalizations.of(context)!.deviceHealthChartHeartRate,
    unit: 'bpm',
    color: scheme.error,
    axis: HealthChartAxis.left,
    read: (sample) => sample.heartRate?.toDouble(),
  );
  if (heartRate != null) result.add(heartRate);

  final secondary = [
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartCadence,
      unit: '/min',
      color: scheme.tertiary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.cadence?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartPace,
      unit: '',
      color: scheme.primary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.paceSecondsPerKilometer?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartSpeed,
      unit: 'km/h',
      color: scheme.secondary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.speedKph,
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartPower,
      unit: 'W',
      color: scheme.tertiary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.powerWatts?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartStrokeRate,
      unit: '/min',
      color: scheme.primary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.strokeFrequency?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartJumpRate,
      unit: '/min',
      color: scheme.secondary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.jumpFrequency?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartBloodOxygen,
      unit: '%',
      color: scheme.primary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.bloodOxygen?.toDouble(),
    ),
    make(
      label: AppLocalizations.of(context)!.deviceHealthChartStress,
      unit: '',
      color: scheme.secondary,
      axis: HealthChartAxis.right,
      read: (sample) => sample.stress?.toDouble(),
    ),
  ];
  final selectedSecondary = secondary
      .whereType<HealthChartSeries>()
      .firstOrNull;
  if (selectedSecondary != null) result.add(selectedSecondary);
  if (result.isEmpty) {
    final fallback = secondary.whereType<HealthChartSeries>().firstOrNull;
    if (fallback != null) {
      result.add(
        HealthChartSeries(
          label: fallback.label,
          unit: fallback.unit,
          color: fallback.color,
          axis: HealthChartAxis.left,
          points: fallback.points,
        ),
      );
    }
  }
  return result;
}

class _WorkoutHeartRateZonesCard extends StatelessWidget {
  const _WorkoutHeartRateZonesCard({required this.workout});

  final HealthWorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    final zones = [...workout.heartRateZones]
      ..sort((left, right) => left.zone.compareTo(right.zone));
    final maximum = zones.fold<int>(
      1,
      (value, zone) =>
          zone.durationSeconds > value ? zone.durationSeconds : value,
    );
    final colors = healthHeartRateZoneColors(context);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.deviceHealthHeartRateZones,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          for (final zone in zones) ...[
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    _heartRateZoneLabel(
                      AppLocalizations.of(context)!,
                      zone.zone,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: zone.durationSeconds / maximum,
                      color: colors[(zone.zone - 1).clamp(0, 4)],
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Text(
                    _shortDuration(zone.durationSeconds),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            if (zone != zones.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _WorkoutRecoveryCard extends StatelessWidget {
  const _WorkoutRecoveryCard({required this.recovery});

  final HealthWorkoutHeartRateRecovery recovery;

  @override
  Widget build(BuildContext context) {
    final values = recovery.heartRates;
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.deviceHealthRecoveryAfterWorkout,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _HealthSummaryStats(
            columns: 3,
            entries: [
              (
                AppLocalizations.of(context)!.deviceHealthRecoveredHeartRate,
                recovery.recoveredHeartRate == null
                    ? '—'
                    : '${recovery.recoveredHeartRate} bpm',
              ),
              (
                AppLocalizations.of(context)!.deviceHealthRecoveryRate,
                recovery.recoveryRate == null
                    ? '—'
                    : '${recovery.recoveryRate}%',
              ),
              (
                AppLocalizations.of(context)!.deviceHealthSamples,
                '${values.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _WorkoutRouteCard = WorkoutRouteCard;

class WorkoutRouteCard extends StatefulWidget {
  const WorkoutRouteCard({super.key, required this.route, required this.color});

  final List<HealthWorkoutRoutePoint> route;
  final Color color;

  @override
  State<WorkoutRouteCard> createState() => _WorkoutRouteCardState();
}

class _WorkoutRouteCardState extends State<WorkoutRouteCard> {
  late final MapController _mapController;
  bool _showOsmMap = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = widget.route
        .where(
          (point) =>
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude != 0 &&
              point.longitude != 0,
        )
        .toList(growable: false);

    if (validPoints.length < 2) {
      return const SizedBox.shrink();
    }

    final latLngs = validPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final bounds = LatLngBounds.fromPoints(latLngs);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const darkMapColorFilter = ColorFilter.matrix(<double>[
      -0.75,
      0.0,
      0.0,
      0.0,
      220.0,
      0.0,
      -0.75,
      0.0,
      0.0,
      220.0,
      0.0,
      0.0,
      -0.75,
      0.0,
      220.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.deviceHealthWorkoutRoute,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _showOsmMap ? Icons.map_outlined : Icons.gesture_outlined,
                  size: 20,
                ),
                tooltip: _showOsmMap ? '切换至矢量简图' : '切换至街道底图',
                onPressed: () => setState(() => _showOsmMap = !_showOsmMap),
              ),
              if (_showOsmMap)
                IconButton(
                  icon: const Icon(Icons.my_location_outlined, size: 20),
                  tooltip: '重新居中',
                  onPressed: () {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(32),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 280,
              child: _showOsmMap
                  ? ColoredBox(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF5F5F5),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCameraFit: CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(32),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag |
                                InteractiveFlag.doubleTapZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'org.zxor.oronbox',
                            maxZoom: 19,
                            tileBuilder: isDark
                                ? (context, tileWidget, tile) => ColorFiltered(
                                    colorFilter: darkMapColorFilter,
                                    child: tileWidget,
                                  )
                                : null,
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: latLngs,
                                strokeWidth: 4.5,
                                color: widget.color,
                                borderStrokeWidth: 2.0,
                                borderColor: isDark
                                    ? Colors.black87
                                    : Colors.white.withValues(alpha: 0.9),
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: latLngs.first,
                                width: 26,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '起',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Marker(
                                point: latLngs.last,
                                width: 26,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC62828),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '终',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : CustomPaint(
                      painter: _WorkoutRoutePainter(
                        points: widget.route,
                        color: widget.color,
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutRoutePainter extends CustomPainter {
  const _WorkoutRoutePainter({required this.points, required this.color});

  final List<HealthWorkoutRoutePoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final valid = points
        .where((point) => point.latitude.isFinite && point.longitude.isFinite)
        .toList(growable: false);
    if (valid.length < 2 || size.isEmpty) return;
    final minLat = valid.map((point) => point.latitude).reduce(math.min);
    final maxLat = valid.map((point) => point.latitude).reduce(math.max);
    final minLon = valid.map((point) => point.longitude).reduce(math.min);
    final maxLon = valid.map((point) => point.longitude).reduce(math.max);
    final latSpan = math.max(maxLat - minLat, .000001);
    // A longitude degree is shorter at higher latitudes. Use local planar
    // distances and one scale for both axes so the route keeps its shape.
    final longitudeScale = math
        .cos((minLat + maxLat) / 2 * math.pi / 180)
        .abs();
    final lonSpan = math.max((maxLon - minLon) * longitudeScale, .000001);
    const inset = 18.0;
    final usableWidth = math.max(1.0, size.width - inset * 2);
    final usableHeight = math.max(1.0, size.height - inset * 2);
    final scale = math.min(usableWidth / lonSpan, usableHeight / latSpan);
    final mapWidth = lonSpan * scale;
    final mapHeight = latSpan * scale;
    final left = (size.width - mapWidth) / 2;
    final top = (size.height - mapHeight) / 2;
    final path = Path();
    for (final (index, point) in valid.indexed) {
      final x = left + (point.longitude - minLon) * longitudeScale * scale;
      final y = top + mapHeight - (point.latitude - minLat) * scale;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkoutRoutePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

String workoutDistance(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '$meters m';

String workoutName(BuildContext context, HealthWorkoutSummary workout) {
  final type = workout.activityType;
  final subType = workout.subSportType;
  if (type == 22) {
    return switch (subType) {
      2 ||
      207 => AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorWalking,
      4 => AppLocalizations.of(context)!.deviceHealthWorkoutMountaineering,
      5 => AppLocalizations.of(context)!.deviceHealthWorkoutTrailRunning,
      15 => AppLocalizations.of(context)!.deviceHealthWorkoutHiking,
      _ => AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorRunning,
    };
  }
  if (type == 23) {
    return AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorCycling;
  }
  return switch (type) {
    1 => AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorRunning,
    2 => AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorWalking,
    3 => AppLocalizations.of(context)!.deviceHealthWorkoutIndoorRunning,
    4 => AppLocalizations.of(context)!.deviceHealthWorkoutMountaineering,
    5 => AppLocalizations.of(context)!.deviceHealthWorkoutTrailRunning,
    6 => AppLocalizations.of(context)!.deviceHealthWorkoutOutdoorCycling,
    7 => AppLocalizations.of(context)!.deviceHealthWorkoutIndoorCycling,
    8 => AppLocalizations.of(context)!.deviceHealthWorkoutFreeTraining,
    9 || 10 => AppLocalizations.of(context)!.deviceHealthWorkoutSwimming,
    11 => AppLocalizations.of(context)!.deviceHealthWorkoutElliptical,
    13 => AppLocalizations.of(context)!.deviceHealthWorkoutRowing,
    14 => AppLocalizations.of(context)!.deviceHealthWorkoutJumpRope,
    15 => AppLocalizations.of(context)!.deviceHealthWorkoutHiking,
    _ => AppLocalizations.of(context)!.deviceHealthWorkoutGeneric,
  };
}

IconData workoutIcon(HealthWorkoutSummary workout) =>
    switch (workout.activityType) {
      2 || 4 || 5 || 15 => Icons.hiking_outlined,
      6 || 7 || 23 => Icons.directions_bike_outlined,
      8 => Icons.fitness_center_outlined,
      9 || 10 => Icons.pool_outlined,
      11 => Icons.motion_photos_on_outlined,
      13 => Icons.rowing_outlined,
      14 => Icons.sports_gymnastics_outlined,
      _ => Icons.directions_run_outlined,
    };

String _heartRateZoneLabel(AppLocalizations l10n, int zone) => switch (zone) {
  1 => l10n.deviceHealthZoneWarmup,
  2 => l10n.deviceHealthZoneFatBurning,
  3 => l10n.deviceHealthZoneAerobic,
  4 => l10n.deviceHealthZoneAnaerobic,
  5 => l10n.deviceHealthZoneExtreme,
  _ => l10n.deviceHealthZoneLabel(zone),
};

List<(String, String)> _workoutDetails(
  BuildContext context,
  HealthWorkoutSummary workout,
) {
  final l10n = AppLocalizations.of(context)!;
  final values = <(String, String)>[];
  void add(String label, Object? value, String unit) {
    if (value == null) return;
    final formatted = value is double
        ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
        : value.toString();
    values.add((label, '$formatted$unit'));
  }

  if (workout.effectiveDurationSeconds != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthActiveDuration,
      _duration(workout.effectiveDurationSeconds!),
    ));
  }
  if (workout.averagePaceSecondsPerKilometer != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthAveragePace,
      workoutPace(workout.averagePaceSecondsPerKilometer!),
    ));
  }
  if (workout.bestPaceSecondsPerKilometer != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthBestPace,
      workoutPace(workout.bestPaceSecondsPerKilometer!),
    ));
  }
  add(l10n.deviceHealthAverageSpeed, workout.averageSpeedKph, ' km/h');
  add(l10n.deviceHealthTopSpeed, workout.bestSpeedKph, ' km/h');
  add(l10n.deviceHealthSteps, workout.totalSteps, '');
  add(l10n.deviceHealthAverageStride, workout.averageStrideCentimeters, ' cm');
  add(l10n.deviceHealthAverageCadence, workout.averageCadence, '/min');
  add(l10n.deviceHealthMaximumCadence, workout.maximumCadence, '/min');
  if (workout.effectiveMinimumHeartRate != null ||
      workout.effectiveMaximumHeartRate != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthHeartRateRange,
      '${workout.effectiveMinimumHeartRate ?? '—'}–'
          '${workout.effectiveMaximumHeartRate ?? '—'} bpm',
    ));
  }
  if (workout.minimumBloodOxygen != null ||
      workout.maximumBloodOxygen != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthBloodOxygenRange,
      '${workout.minimumBloodOxygen ?? '—'}–${workout.maximumBloodOxygen ?? '—'}%',
    ));
  }
  add(
    l10n.deviceHealthAverageBloodOxygenDetail,
    workout.averageBloodOxygen,
    '%',
  );
  add(l10n.deviceHealthAverage, workout.averageStress, '');
  add(l10n.deviceHealthTotalAscent, workout.totalAscentMeters, ' m');
  add(l10n.deviceHealthTotalDescent, workout.totalDescentMeters, ' m');
  add(l10n.deviceHealthAverageAltitude, workout.averageAltitudeMeters, ' m');
  add(l10n.deviceHealthAerobicEffect, workout.aerobicTrainingEffect, '');
  add(l10n.deviceHealthAnaerobicEffect, workout.anaerobicTrainingEffect, '');
  add(l10n.deviceHealthPeakEffect, workout.peakTrainingEffect, '');
  add(l10n.deviceHealthVo2Max, workout.vo2Max, ' ml/kg/min');
  add(l10n.deviceHealthBodyEnergyUsed, workout.bodyEnergyConsumption, '');
  add(l10n.deviceHealthExpectedRecovery, workout.expectedRecoveryHours, ' h');
  add(l10n.deviceHealthTrainingLoad, workout.trainingLoad, '');
  add(l10n.deviceHealthVitalityEarned, workout.earnedVitality, '');
  add(l10n.deviceHealthAveragePower, workout.averagePowerWatts, ' W');
  add(l10n.deviceHealthMaximumPower, workout.maximumPowerWatts, ' W');
  add(l10n.deviceHealthArmPulls, workout.totalArmPulls, '');
  if (workout.mainSwimmingStroke != null) {
    values.add((
      AppLocalizations.of(context)!.deviceHealthMainStroke,
      _swimmingStrokeName(context, workout.mainSwimmingStroke),
    ));
  }
  add(
    l10n.deviceHealthAverageStrokeRate,
    workout.averageStrokeFrequency,
    '/min',
  );
  add(
    l10n.deviceHealthMaximumStrokeRate,
    workout.maximumStrokeFrequency,
    '/min',
  );
  add(l10n.deviceHealthTurns, workout.turnCount, '');
  add(l10n.deviceHealthAverageSwolf, workout.averageSwolf, '');
  add(l10n.deviceHealthBestSwolf, workout.bestSwolf, '');
  add(l10n.deviceHealthPoolLength, workout.poolWidthMeters, ' m');
  add(l10n.deviceHealthJumps, workout.totalJumps, '');
  add(l10n.deviceHealthAverageJumpRate, workout.averageJumpFrequency, '/min');
  add(l10n.deviceHealthBestJumpRate, workout.bestJumpFrequency, '/min');
  add(l10n.deviceHealthTrips, workout.tripCount, '');
  add(l10n.deviceHealthSets, workout.setCount, '');
  add(l10n.deviceHealthTotalStrokes, workout.totalStrokes, '');
  add(
    l10n.deviceHealthAverageRowingRate,
    workout.averageRowingFrequency,
    '/min',
  );
  add(l10n.deviceHealthBestRowingRate, workout.bestRowingFrequency, '/min');
  return values;
}

String workoutPace(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return "$minutes'$remainder\"";
}

String _shortDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return minutes == 0 ? '${remainder}s' : '${minutes}m ${remainder}s';
}

String _swimmingStrokeName(BuildContext context, int? stroke) =>
    switch (stroke) {
      0 => AppLocalizations.of(context)!.deviceHealthStrokeMedley,
      1 => AppLocalizations.of(context)!.deviceHealthStrokeBreaststroke,
      2 => AppLocalizations.of(context)!.deviceHealthStrokeFreestyle,
      3 => AppLocalizations.of(context)!.deviceHealthStrokeBackstroke,
      4 => AppLocalizations.of(context)!.deviceHealthStrokeButterfly,
      _ => AppLocalizations.of(context)!.deviceHealthSectionLabel,
    };

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}
