import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/status_surface_bridge.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_detail_page.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_automatic_sync_service.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_sync_preferences.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_fitness_logo.dart';
import 'package:oronbox/src/device/core/device_state.dart';

class XiaomiHealthPage extends ConsumerStatefulWidget {
  const XiaomiHealthPage({super.key});

  @override
  ConsumerState<XiaomiHealthPage> createState() => _XiaomiHealthPageState();
}

class _XiaomiHealthPageState extends ConsumerState<XiaomiHealthPage> {
  XiaomiHealthData? _data;
  String? _error;
  bool _loading = true;
  bool _syncing = false;
  bool _autoSync = false;
  List<Widget Function()> _cardBuildersForRender = const [];

  @override
  void initState() {
    super.initState();
    _autoSync = XiaomiSyncPreferences.healthAutoSync;
    healthDataRevision.addListener(_onHealthDataPersisted);

    unawaited(_load(silent: false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = _data;
    if (data != null) _cardBuildersForRender = _cardBuilders(data);
  }

  @override
  void dispose() {
    healthDataRevision.removeListener(_onHealthDataPersisted);
    super.dispose();
  }

  /// Auto-sync, the scheduler and the command bus all persist through
  /// [HealthStore]; refresh so the open page does not show stale data or a
  /// stale "data as of" timestamp.
  void _onHealthDataPersisted() {
    if (!mounted || _syncing) return;
    unawaited(_load(silent: _data != null));
  }

  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final deviceId = ref.read(deviceManagerProvider).currentDevice?.addr;
      final data = deviceId == null
          ? const XiaomiHealthData()
          : await HealthStore().overview(deviceId);
      unawaited(updateHealthStatusSurface(healthStatusSurfaceData(data)));
      if (!mounted) return;
      _showData(data);
    } catch (error) {
      if (!mounted) return;
      if (!silent || _data == null) {
        setState(() => _error = _healthErrorMessage(error));
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final result = await XiaomiAutomaticSyncService(
        ref.read(deviceManagerProvider.notifier),
      ).runHealthSync();
      unawaited(
        updateHealthStatusSurface(healthStatusSurfaceData(result.data)),
      );
      if (!mounted) return;
      final deviceId = ref.read(deviceManagerProvider).currentDevice?.addr;
      if (deviceId != null) _showData(await HealthStore().overview(deviceId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _healthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showData(XiaomiHealthData data) {
    setState(() {
      _data = data;
      _cardBuildersForRender = _cardBuilders(data);
      _loading = false;
      _error = null;
    });
  }

  void _openDetail(XiaomiHealthMetric metric) {
    final data = _data;
    if (data == null) return;
    context.push(
      '/devices/velaos-health/detail',
      extra: XiaomiHealthDetailArgs(
        metric: metric,
        data: data,
        deviceId: ref.read(deviceManagerProvider).currentDevice?.addr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    final cardBuilders = _cardBuildersForRender;
    final ready =
        ref.watch(deviceManagerProvider).protocolState == ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.deviceHealthTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/devices/velaos-health/debug'),
            icon: const Icon(Icons.data_object_outlined),
            tooltip: l10n.deviceHealthDebugSnapshots,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList.list(
              children: [
                for (final section in <Widget>[
                  SegmentedSection(
                    tiles: [
                      SegmentedTile(
                        leading: _syncing
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const XiaomiFitnessLogo(),
                        title: Text(
                          _syncing
                              ? l10n.deviceHealthSyncing
                              : l10n.deviceHealthSync,
                        ),
                        description: Text(
                          data?.lastSyncedAt == null
                              ? l10n.deviceHealthNeverSynced
                              : l10n.deviceHealthLastSynced(
                                  _formatDateTime(data!.lastSyncedAt!),
                                ),
                        ),
                        enabled: ready && !_syncing,
                        trailing: IconButton(
                          onPressed: ready && !_syncing ? _sync : null,
                          icon: const Icon(Icons.sync),
                          tooltip: l10n.deviceHealthSync,
                        ),
                        onPressed: (_) {
                          if (ready && !_syncing) _sync();
                        },
                      ),
                      SegmentedTile.switchTile(
                        title: Text(l10n.deviceHealthAutoSyncTitle),
                        description: Text(l10n.deviceHealthAutoSyncDescription),
                        initialValue: _autoSync,
                        onToggle: (value) {
                          final enabled = value ?? false;
                          setState(() => _autoSync = enabled);
                          unawaited(
                            XiaomiSyncPreferences.setHealthAutoSync(enabled),
                          );
                        },
                      ),
                    ],
                  ),
                  if (_error != null)
                    SegmentedSection(
                      tiles: [
                        SegmentedTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(l10n.deviceHealthLoadFailed),
                          description: Text(_error!),
                          trailing: IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ),
                  if (data != null && cardBuilders.isEmpty)
                    CustomSegmentedSection(
                      child: SizedBox(
                        height: 220,
                        child: Center(child: Text(l10n.deviceHealthNoData)),
                      ),
                    )
                  else if (data != null)
                    CustomSegmentedSection(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: AdaptiveHealthCardWrap(
                          children: [
                            for (final (index, builder) in cardBuilders.indexed)
                              KeyedSubtree(
                                key: ValueKey(index),
                                child: builder(),
                              ),
                          ],
                        ),
                      ),
                    ),
                ])
                  Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: StyleConstants.pageMaxWidth,
                      ),
                      child: section,
                    ),
                  ),
              ],
            ),
          ),
          if (_loading && data == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget Function()> _cardBuilders(XiaomiHealthData? data) {
    final l10n = AppLocalizations.of(context)!;
    final value = data ?? const XiaomiHealthData();
    final cards = <Widget Function()>[
      () => ActivityOverviewCard(
        summary: value.activitySummary,
        onPressed: () => _openDetail(XiaomiHealthMetric.activity),
      ),
    ];
    final capabilities = value.capabilities;
    final vitalityDay = _latestDaily(
      value.daily,
      (day) => day.vitalityLast7Days ?? day.vitalityCurrent,
    );
    if (capabilities.workouts) {
      cards.add(
        () => HealthWorkoutCard(
          workouts: value.workouts,
          onPressed: () => _openDetail(XiaomiHealthMetric.workout),
        ),
      );
    }
    final restingDay = _latestDaily(value.daily, (day) => day.restingHeartRate);
    if (capabilities.heartRate || restingDay != null) {
      cards.add(
        () => _metricCard(
          data: value,
          metric: XiaomiHealthMetric.heartRate,
          title: l10n.deviceHealthHeartRate,
          icon: Icons.favorite_outline,
          color: context.appColors.healthHeartRate,
          summaryValue: value.latestDay?.averageHeartRate,
          unit: 'bpm',
          detail: _range(
            value.latestDay?.minHeartRate,
            value.latestDay?.maxHeartRate,
            'bpm',
          ),
          supportingDetail: restingDay?.restingHeartRate == null
              ? null
              : '${l10n.deviceHealthRestingHeartRate} '
                    '${restingDay!.restingHeartRate} bpm',
        ),
      );
    }
    if (capabilities.bloodOxygen) {
      cards.add(
        () => _metricCard(
          data: value,
          metric: XiaomiHealthMetric.bloodOxygen,
          title: l10n.deviceHealthBloodOxygen,
          icon: Icons.bloodtype_outlined,
          color: context.appColors.healthBloodOxygen,
          summaryValue: value.latestDay?.averageBloodOxygen,
          unit: '%',
          detail: _range(
            value.latestDay?.minBloodOxygen,
            value.latestDay?.maxBloodOxygen,
            '%',
          ),
        ),
      );
    }
    if (capabilities.stress) {
      cards.add(
        () => _metricCard(
          data: value,
          metric: XiaomiHealthMetric.stress,
          title: l10n.deviceHealthStress,
          icon: Icons.spa_outlined,
          color: context.appColors.healthStress,
          summaryValue: value.latestDay?.averageStress,
          unit: '',
          detail: _range(
            value.latestDay?.minStress,
            value.latestDay?.maxStress,
            '',
          ),
        ),
      );
    }
    if (capabilities.vitality) {
      cards.add(
        () => HealthVitalityCard(
          title: l10n.deviceHealthVitality,
          icon: Icons.local_fire_department_outlined,
          color: context.appColors.healthVitality,
          summary: vitalityDay,
          sevenDayTotal: vitalityDay == null
              ? null
              : value.vitalitySevenDayTotal(vitalityDay),
          noDataLabel: l10n.deviceHealthNoData,
          onPressed: () => _openDetail(XiaomiHealthMetric.vitality),
        ),
      );
    }
    if (capabilities.sleep) {
      final sleep = value.latestPrimarySleep;
      cards.add(
        () => HealthSleepCard(
          title: l10n.deviceHealthSleepCard,
          icon: Icons.bedtime_outlined,
          color: context.appColors.healthSleep,
          summary: sleep,
          totalDurationSeconds: value.latestSleepDayDurationSeconds,
          noDataLabel: l10n.deviceHealthNoData,
          onPressed: () => _openDetail(XiaomiHealthMetric.sleep),
        ),
      );
    }
    return cards;
  }

  HealthMetricCard _metricCard({
    required XiaomiHealthData data,
    required XiaomiHealthMetric metric,
    required String title,
    required IconData icon,
    required Color color,
    required int? summaryValue,
    required String unit,
    required String detail,
    String? supportingDetail,
  }) {
    final latest = data.latestSample(metric);
    final anchor = latest?.timestamp ?? DateTime.now();
    final chartStart = healthDayStart(anchor);
    final chartEnd = chartStart.add(const Duration(days: 1));
    final samples =
        data
            .samplesFor(metric)
            .where(
              (sample) =>
                  sample.isUsable &&
                  !sample.timestamp.isBefore(chartStart) &&
                  sample.timestamp.isBefore(chartEnd),
            )
            .toList()
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final displayedValue = latest?.value.round() ?? summaryValue;
    return HealthMetricCard(
      metric: metric,
      title: title,
      icon: icon,
      color: color,
      value: displayedValue == null ? '—' : '$displayedValue $unit'.trim(),
      detail: latest == null
          ? detail
          : supportingDetail == null
          ? _formatDateTime(latest.timestamp)
          : '${_formatDateTime(latest.timestamp)} · $supportingDetail',
      samples: samples,
      chartStart: chartStart,
      chartEnd: chartEnd,
      onPressed: () => _openDetail(metric),
    );
  }

  String _range(int? min, int? max, String unit) {
    if (min == null && max == null) {
      return AppLocalizations.of(context)!.deviceHealthNoDetailedRange;
    }
    if (min == null || max == null) return '${min ?? max} $unit'.trim();
    return '$min–$max $unit'.trim();
  }

  HealthDailySummary? _latestDaily(
    List<HealthDailySummary> days,
    int? Function(HealthDailySummary day) valueFor,
  ) {
    final matching = days.where((day) => valueFor(day) != null).toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return matching.isEmpty ? null : matching.last;
  }

  String _healthErrorMessage(Object error) {
    if (error is UnsupportedError) {
      return AppLocalizations.of(context)!.errorUnknown;
    }
    return localizedErrorMessage(AppLocalizations.of(context)!, error);
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day} ${_formatTime(local)}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
