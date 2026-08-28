import 'dart:async';
import 'dart:math' as math;

import 'package:segmented_list/segmented_list.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/models/device.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_automatic_sync_service.dart';
import 'package:oronbox/src/features/devices/widgets/device_connection_text.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_fitness_logo.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/widgets/resource_install_confirmation.dart';
import 'package:oronbox/src/features/devices/pages/install/local_file_picker_policy.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  bool _syncingTime = false;
  String? _lastErrorToast;
  StreamSubscription<DeviceEvent>? _deviceEventSubscription;

  @override
  void initState() {
    super.initState();
    _deviceEventSubscription = ref
        .read(deviceManagerProvider.notifier)
        .deviceEvents
        .listen(_handleDeviceEvent);
  }

  @override
  void dispose() {
    unawaited(_deviceEventSubscription?.cancel());
    super.dispose();
  }

  void _handleDeviceEvent(DeviceEvent event) {
    if (!mounted || event is! PassiveReconnectStatus) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (event.phase) {
      PassiveReconnectPhase.attempt => l10n.deviceReconnectAttempting,
      PassiveReconnectPhase.success => l10n.deviceReconnectSucceeded,
      PassiveReconnectPhase.failed =>
        '${l10n.deviceReconnectFailedPrefix}${l10n.errorBluetoothConnectFailed}',
    };
    _showDeviceStatusSnackBar(message, replaceCurrent: true);
  }

  void _showDeviceStatusSnackBar(
    String message, {
    bool replaceCurrent = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    if (replaceCurrent) messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final device = state.currentDevice;

    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      if (next.error == null) _lastErrorToast = null;
      if (next.error == null) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final wasConnecting = previous?.connecting == true;
      if (next.connecting ||
          (wasConnecting && next.connectStatus != 3) ||
          (next.error == previous?.error &&
              !(wasConnecting && next.connectStatus == 3))) {
        return;
      }
      final message = localizedErrorMessage(l10n, next.error);
      if (message == _lastErrorToast) return;
      _lastErrorToast = message;
      _showDeviceStatusSnackBar(message);
    });

    final isReady = state.protocolState == proto.ProtocolState.ready;
    void reconnectCurrent() {
      final current = state.currentDevice;
      if (current == null || current.authkey == null) return;
      ref
          .read(deviceManagerProvider.notifier)
          .connect(
            current.addr,
            current.name,
            current.authkey!,
            connectType: current.connectType,
          );
    }

    Future<void> refreshOrReconnect() async {
      final current = state.currentDevice;
      if (current == null) return;
      final manager = ref.read(deviceManagerProvider.notifier);
      if (current.disconnected) {
        reconnectCurrent();
        return;
      }
      await manager.refreshDeviceData();
    }

    Future<void> syncCurrentTime() async {
      if (_syncingTime) return;
      setState(() => _syncingTime = true);
      try {
        await XiaomiAutomaticSyncService(
          ref.read(deviceManagerProvider.notifier),
        ).run(automatic: false);
      } finally {
        if (mounted) setState(() => _syncingTime = false);
      }
    }

    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.devicesTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.connecting || device == null
                ? null
                : refreshOrReconnect,
            tooltip: device?.disconnected ?? true
                ? l10n.deviceReconnect
                : l10n.refresh,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = useWideLayout(constraints.maxWidth);
          final isZeppOs =
              (device?.codename?.startsWith('zepp:') ?? false) ||
              (device != null &&
                  zeppOsDeviceForBluetoothName(device.name) != null);
          final infoPanel = _DeviceInfoPanel(
            compact: !isWide,
            showMetrics: false,
            device: device,
            isZeppOs: isZeppOs,
            isReady: isReady,
            connectionState: state,
            battery: state.battery,
            storage: state.systemInfo?.storageInfo,
            uploadBytesPerSecond: state.uploadBytesPerSecond,
            downloadBytesPerSecond: state.downloadBytesPerSecond,
            onReconnect: reconnectCurrent,
            onCancelConnect: () =>
                ref.read(deviceManagerProvider.notifier).cancelConnect(),
            onSwitch: () {
              context.push('/devices/switch');
            },
            onSyncTime: () {
              unawaited(syncCurrentTime());
            },
            syncingTime: _syncingTime,
          );
          final featuresPanel = _DeviceFeaturesPanel(
            compact: !isWide,
            showInstall: false,
            enabled: isReady,
            hasDevice: device != null,
            isZeppOs: isZeppOs,
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoPanel,
                    const SizedBox(height: StyleConstants.sectionSpacing),
                    _DeviceStatusGrid(
                      compact: !isWide,
                      showStorage: !isZeppOs,
                      enabled: isReady,
                      battery: state.battery,
                      storage: state.systemInfo?.storageInfo,
                      appCount: state.apps
                          .where(
                            (app) => !app.packageName.startsWith(
                              'com.xiaomi.miwear.',
                            ),
                          )
                          .length,
                      watchfaceCount: state.watchfaces.length,
                      onManageApps: () => context.push('/devices/apps'),
                      onManageWatchfaces: () =>
                          context.push('/devices/watchfaces'),
                      onInstallApp: () => _pickAndEnqueueResource(
                        context,
                        ref,
                        LocalDeviceInstallType.app,
                      ),
                      onInstallWatchface: () => _pickAndEnqueueResource(
                        context,
                        ref,
                        LocalDeviceInstallType.watchface,
                      ),
                    ),
                    const SizedBox(height: StyleConstants.sectionSpacing),
                    featuresPanel,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceInfoPanel extends StatelessWidget {
  const _DeviceInfoPanel({
    required this.compact,
    required this.showMetrics,
    required this.device,
    required this.isZeppOs,
    required this.isReady,
    required this.connectionState,
    this.battery,
    this.storage,
    required this.uploadBytesPerSecond,
    required this.downloadBytesPerSecond,
    required this.onReconnect,
    required this.onCancelConnect,
    required this.onSwitch,
    required this.onSyncTime,
    this.syncingTime = false,
  });

  final bool compact;
  final bool showMetrics;
  final MiWearState? device;
  final bool isZeppOs;
  final bool isReady;
  final DeviceManagerState connectionState;
  final BatteryStatus? battery;
  final StorageInfo? storage;
  final double uploadBytesPerSecond;
  final double downloadBytesPerSecond;
  final VoidCallback onReconnect;
  final VoidCallback onCancelConnect;
  final VoidCallback onSwitch;
  final VoidCallback onSyncTime;
  final bool syncingTime;

  bool get _isConnected => isReady && device != null && !device!.disconnected;
  bool get _isConnecting =>
      device != null &&
      connectionState.connecting &&
      connectionState.connectionTargetAddr == device?.addr;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final illustration =
        device?.illustrationAsset() ?? 'assets/images/devices/xiaomi-watch.svg';
    final isNarrow = compact;

    Widget infoContent;
    if (device != null) {
      final nameStyle = textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: device!.name, style: nameStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final statusRowWidth = math.min(
        math.max(namePainter.width, 220.0),
        MediaQuery.sizeOf(context).width - 32.0,
      );
      infoContent = Column(
        crossAxisAlignment: isNarrow
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(device!.name, style: nameStyle),
          const SizedBox(height: 8),
          SizedBox(
            width: statusRowWidth,
            child: !_isConnected
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (_isConnecting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _isConnecting
                              ? deviceConnectionPhaseText(
                                  l10n,
                                  connectionState,
                                  fallbackDeviceName: device!.name,
                                  connectType: device!.connectType,
                                )
                              : l10n.deviceDisconnected,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: _isConnecting
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.deviceConnected,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '↑ ${_formatRate(uploadBytesPerSecond)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '↓ ${_formatRate(downloadBytesPerSecond)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (_isConnecting)
                _ActionButton(
                  icon: Icons.close,
                  label: l10n.cancel,
                  onPressed: onCancelConnect,
                )
              else if (!_isConnected)
                _ActionButton(
                  icon: Icons.link,
                  label: l10n.deviceReconnect,
                  onPressed: onReconnect,
                ),
              if (_isConnected)
                _ActionButton(
                  icon: Icons.sync,
                  label: l10n.deviceSyncTime,
                  loading: syncingTime,
                  onPressed: onSyncTime,
                ),
              _ActionButton(
                icon: Icons.swap_horiz,
                label: _isConnected ? l10n.deviceSwitch : l10n.deviceConnect,
                onPressed: onSwitch,
              ),
            ],
          ),
        ],
      );
    } else {
      infoContent = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.deviceNotConnected,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.swap_horiz,
            label: l10n.deviceConnect,
            onPressed: onSwitch,
          ),
        ],
      );
    }

    final metricCards = Padding(
      padding: EdgeInsetsDirectional.only(start: 16, top: 18, end: 16),
      child: Row(
        children: [
          Expanded(
            child: _BatteryCard(
              battery: battery,
              borderRadius: isNarrow
                  ? BorderRadius.circular(20)
                  : const BorderRadiusDirectional.only(
                      topStart: Radius.circular(20),
                      bottomStart: Radius.circular(20),
                      topEnd: Radius.circular(3),
                      bottomEnd: Radius.circular(3),
                    ),
            ),
          ),
          SizedBox(width: isNarrow ? 12 : 2),
          Expanded(
            child: _StorageCard(
              storage: storage,
              borderRadius: isNarrow
                  ? BorderRadius.circular(20)
                  : const BorderRadiusDirectional.only(
                      topStart: Radius.circular(3),
                      bottomStart: Radius.circular(3),
                      topEnd: Radius.circular(20),
                      bottomEnd: Radius.circular(20),
                    ),
            ),
          ),
        ],
      ),
    );

    final content = isNarrow
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                illustration,
                width: 120,
                height: 120,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              infoContent,
              if (showMetrics) metricCards,
            ],
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 28, end: 16),
                child: Row(
                  children: [
                    Expanded(child: infoContent),
                    const SizedBox(width: 32),
                    SvgPicture.asset(
                      illustration,
                      width: 150,
                      height: 150,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              if (showMetrics) metricCards,
            ],
          );
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: isNarrow ? 0 : 12),
      child: content,
    );
  }

  String _formatRate(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.round()} B/s';
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery, this.borderRadius});

  final BatteryStatus? battery;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final charging = battery?.chargeStatus == ChargeStatus.charging;
    final supportingText = charging
        ? AppLocalizations.of(context)!.deviceCharging
        : _lastChargedText(context, battery?.chargeInfo?.timestamp);
    return _DeviceMetricCard(
      title: AppLocalizations.of(context)!.fieldBattery,
      value: battery == null ? '--' : '${battery!.capacity}%',
      progress: battery == null
          ? null
          : (battery!.capacity / 100).clamp(0.0, 1.0),
      icon: Icons.battery_std,
      iconColor: scheme.onSurfaceVariant,
      valueIcon: charging ? Icons.bolt : null,
      valueColor: charging ? scheme.primary : scheme.onSurface,
      progressColor: charging ? scheme.primary : scheme.onSurfaceVariant,
      supportingText: supportingText,
      borderRadius: borderRadius,
    );
  }

  String? _lastChargedText(BuildContext context, int? timestamp) {
    if (timestamp == null) return null;
    final chargedAt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final elapsed = now.difference(chargedAt);
    final l10n = AppLocalizations.of(context)!;
    if (elapsed.inMinutes < 1) return l10n.deviceLastChargedNow;
    if (elapsed.inHours < 1) {
      return l10n.deviceLastChargedMinutes(elapsed.inMinutes);
    }
    if (elapsed.inDays < 1) {
      return l10n.deviceLastChargedHours(elapsed.inHours);
    }
    return l10n.deviceLastChargedDays(elapsed.inDays);
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage, this.borderRadius});

  final StorageInfo? storage;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final used = storage == null ? '--' : _formatBytes(storage!.used);
    final total = storage == null ? '--' : _formatBytes(storage!.total);
    final ratio = storage == null || storage!.total <= 0
        ? null
        : (storage!.used / storage!.total).clamp(0.0, 1.0);
    return _DeviceMetricCard(
      icon: Icons.storage_outlined,
      title: AppLocalizations.of(context)!.fieldStorage,
      value: '$used / $total',
      progress: ratio,
      borderRadius: borderRadius,
    );
  }

  String _formatBytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }
}

class _DeviceMetricCard extends StatelessWidget {
  const _DeviceMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    this.progress,
    this.iconColor,
    this.valueIcon,
    this.valueColor,
    this.progressColor,
    this.supportingText,
    this.borderRadius,
  });

  final IconData icon;
  final String title;
  final String value;
  final double? progress;
  final Color? iconColor;
  final IconData? valueIcon;
  final Color? valueColor;
  final Color? progressColor;
  final String? supportingText;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: valueColor ?? scheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    final resolvedIconColor = iconColor ?? scheme.onSurfaceVariant;
    final resolvedValueColor = valueColor ?? scheme.onSurface;
    final resolvedProgressColor = progressColor ?? scheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final valuePainter =
            TextPainter(
              text: TextSpan(text: value, style: valueStyle),
              maxLines: 1,
              textDirection: Directionality.of(context),
            )..layout(
              maxWidth: (constraints.maxWidth - 28).clamp(0, double.infinity),
            );
        final valueWraps = valuePainter.didExceedMaxLines;
        return SizedBox(
          height: 104,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: resolvedIconColor),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (valueIcon != null) ...[
                        Icon(valueIcon, size: 18, color: resolvedValueColor),
                        const SizedBox(width: 2),
                      ],
                      if (supportingText == null)
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: valueStyle,
                          ),
                        )
                      else ...[
                        Text(value, maxLines: 1, style: valueStyle),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              supportingText!,
                              maxLines: 2,
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (progress != null) ...[
                    SizedBox(height: valueWraps ? 4 : 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                      color: resolvedProgressColor,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceFeaturesPanel extends ConsumerStatefulWidget {
  const _DeviceFeaturesPanel({
    required this.compact,
    required this.showInstall,
    required this.enabled,
    required this.hasDevice,
    required this.isZeppOs,
  });

  final bool compact;
  final bool showInstall;
  final bool enabled;
  final bool hasDevice;
  final bool isZeppOs;

  @override
  ConsumerState<_DeviceFeaturesPanel> createState() =>
      _DeviceFeaturesPanelState();
}

class _DeviceFeaturesPanelState extends ConsumerState<_DeviceFeaturesPanel> {
  bool _findingBusy = false;

  Future<void> _setFinding(bool finding) async {
    if (_findingBusy) return;
    setState(() => _findingBusy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setFindingXiaomiWearable(finding);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _findingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final appCount = state.apps
        .where((app) => !app.packageName.startsWith('com.xiaomi.miwear.'))
        .length;
    final isNarrow = widget.compact;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isNarrow ? 0 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showInstall)
            _InstallSection(
              compact: widget.compact,
              enabled: widget.enabled,
              appCount: appCount,
              watchfaceCount: state.watchfaces.length,
              onManageApps: () => context.push('/devices/apps'),
              onManageWatchfaces: () => context.push('/devices/watchfaces'),
              onInstallApp: () =>
                  _pickAndEnqueue(context, ref, LocalDeviceInstallType.app),
              onInstallWatchface: () => _pickAndEnqueue(
                context,
                ref,
                LocalDeviceInstallType.watchface,
              ),
            ),
          SegmentedSection(
            margin: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 16,
            ),
            tiles: [
              if (widget.isZeppOs)
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/zeppos-more'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.functions),
                  title: Text(l10n.zeppOsMoreFeatures),
                  description: Text(l10n.zeppOsMoreFeaturesDescription),
                )
              else ...[
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-health'),
                  enabled: widget.enabled,
                  leading: const XiaomiFitnessLogo(),
                  title: Text(l10n.deviceHealthTitle),
                  description: Text(l10n.deviceHealthFeatureDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-music'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(l10n.deviceMusicSync),
                  description: Text(l10n.deviceMusicSyncDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-recordings'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.mic_none),
                  title: Text(l10n.deviceRecordingsTitle),
                  description: Text(l10n.deviceRecordingsDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-weather'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.weatherSyncTitle),
                  description: Text(l10n.weatherSyncDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-alarms'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.alarm_outlined),
                  title: Text(l10n.alarmManagementTitle),
                  description: Text(l10n.alarmManagementDescription),
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.vibration),
                  title: Text(l10n.zeppOsFindDevice),
                  description: Text(l10n.findDeviceDescription),
                  initialValue: state.findingXiaomiWearable,
                  enabled: widget.enabled && !_findingBusy,
                  onToggle: (value) => _setFinding(value ?? false),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-app-order'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.swap_vert_outlined),
                  title: Text(l10n.appOrderTitle),
                  description: Text(l10n.appOrderDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/velaos-app-layout'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.grid_view_outlined),
                  title: Text(l10n.appLayoutTitle),
                  description: Text(l10n.appLayoutDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/firmware'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.memory_outlined),
                  title: Text(l10n.deviceFeaturesInstallFirmware),
                  description: Text(l10n.firmwareUpdateDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/info'),
                  enabled: widget.hasDevice,
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.deviceAboutTitle),
                  description: Text(l10n.deviceAboutDescription),
                ),
              ],
              if (widget.isZeppOs) ...[
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/zeppos-more/music'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(l10n.deviceMusicSync),
                  description: Text(l10n.deviceMusicSyncDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) =>
                      context.push('/devices/zeppos-more/voice-memos'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.mic_none),
                  title: Text(l10n.deviceRecordingsTitle),
                  description: Text(l10n.deviceRecordingsDescription),
                ),
              ],
              if (widget.isZeppOs) ...[
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/firmware'),
                  enabled: widget.enabled,
                  leading: const Icon(Icons.memory_outlined),
                  title: Text(l10n.deviceFeaturesInstallFirmware),
                  description: Text(l10n.deviceFeaturesInstallFirmwareDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/devices/info'),
                  enabled: widget.hasDevice,
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.deviceFeaturesDeviceInfo),
                  description: Text(l10n.deviceFeaturesDeviceInfoDesc),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndEnqueue(
    BuildContext context,
    WidgetRef ref,
    LocalDeviceInstallType selectedType,
  ) async {
    final file = await pickFileData(
      type: FileType.any,
      loadBytes: shouldLoadPickedFileData,
    );
    final selected = file?.xFile;
    if (selected == null) return;
    if (!context.mounted) return;

    await confirmAndEnqueueResourceFile(
      context: context,
      ref: ref,
      file: selected,
      selectedType: selectedType,
    );
  }
}

class _DeviceStatusGrid extends StatelessWidget {
  const _DeviceStatusGrid({
    required this.compact,
    required this.showStorage,
    required this.enabled,
    required this.battery,
    required this.storage,
    required this.appCount,
    required this.watchfaceCount,
    required this.onManageApps,
    required this.onManageWatchfaces,
    required this.onInstallApp,
    required this.onInstallWatchface,
  });

  final bool compact;
  final bool showStorage;
  final bool enabled;
  final BatteryStatus? battery;
  final StorageInfo? storage;
  final int appCount;
  final int watchfaceCount;
  final VoidCallback onManageApps;
  final VoidCallback onManageWatchfaces;
  final VoidCallback onInstallApp;
  final VoidCallback onInstallWatchface;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = <Widget>[
      _BatteryCard(battery: battery),
      if (showStorage) _StorageCard(storage: storage),
      _InstallSummaryCard(
        enabled: enabled,
        icon: Icons.apps_outlined,
        label: l10n.apps,
        countLabel: l10n.deviceAppCount,
        count: appCount,
        installTooltip: l10n.deviceFeaturesInstallApp,
        onOpen: onManageApps,
        onInstall: onInstallApp,
        borderRadius: BorderRadius.circular(20),
      ),
      _InstallSummaryCard(
        enabled: enabled,
        icon: Icons.watch_outlined,
        label: l10n.watchfaces,
        countLabel: l10n.deviceWatchfaceCount,
        count: watchfaceCount,
        installTooltip: l10n.deviceFeaturesInstallWatchface,
        onOpen: onManageWatchfaces,
        onInstall: onInstallWatchface,
        borderRadius: BorderRadius.circular(20),
      ),
    ];

    Widget row(Iterable<Widget> children) => Row(
      children: children.expand((card) sync* {
        if (card != children.first) yield const SizedBox(width: 12);
        yield Expanded(child: card);
      }).toList(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: compact
          ? showStorage
                ? Column(
                    children: [
                      row(cards.take(2)),
                      const SizedBox(height: 12),
                      row(cards.skip(2)),
                    ],
                  )
                : Column(
                    children: [
                      row(cards.take(1)),
                      const SizedBox(height: 12),
                      row(cards.skip(1)),
                    ],
                  )
          : row(cards),
    );
  }
}

Future<void> _pickAndEnqueueResource(
  BuildContext context,
  WidgetRef ref,
  LocalDeviceInstallType selectedType,
) async {
  final file = await pickFileData(
    type: FileType.any,
    loadBytes: shouldLoadPickedFileData,
  );
  final selected = file?.xFile;
  if (selected == null) return;
  if (!context.mounted) return;
  await confirmAndEnqueueResourceFile(
    context: context,
    ref: ref,
    file: selected,
    selectedType: selectedType,
  );
}

class _InstallSection extends StatelessWidget {
  const _InstallSection({
    required this.compact,
    required this.enabled,
    required this.appCount,
    required this.watchfaceCount,
    required this.onManageApps,
    required this.onManageWatchfaces,
    required this.onInstallApp,
    required this.onInstallWatchface,
  });

  final bool compact;
  final bool enabled;
  final int appCount;
  final int watchfaceCount;
  final VoidCallback onManageApps;
  final VoidCallback onManageWatchfaces;
  final VoidCallback onInstallApp;
  final VoidCallback onInstallWatchface;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = compact;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InstallSummaryCard(
                  enabled: enabled,
                  icon: Icons.apps_outlined,
                  label: l10n.apps,
                  countLabel: l10n.deviceAppCount,
                  count: appCount,
                  installTooltip: l10n.deviceFeaturesInstallApp,
                  onOpen: onManageApps,
                  onInstall: onInstallApp,
                  borderRadius: isNarrow
                      ? BorderRadius.circular(20)
                      : const BorderRadiusDirectional.only(
                          topStart: Radius.circular(20),
                          bottomStart: Radius.circular(20),
                          topEnd: Radius.circular(3),
                          bottomEnd: Radius.circular(3),
                        ),
                ),
              ),
              SizedBox(width: isNarrow ? 12 : 2),
              Expanded(
                child: _InstallSummaryCard(
                  enabled: enabled,
                  icon: Icons.watch_outlined,
                  label: l10n.watchfaces,
                  countLabel: l10n.deviceWatchfaceCount,
                  count: watchfaceCount,
                  installTooltip: l10n.deviceFeaturesInstallWatchface,
                  onOpen: onManageWatchfaces,
                  onInstall: onInstallWatchface,
                  borderRadius: isNarrow
                      ? BorderRadius.circular(20)
                      : const BorderRadiusDirectional.only(
                          topStart: Radius.circular(3),
                          bottomStart: Radius.circular(3),
                          topEnd: Radius.circular(20),
                          bottomEnd: Radius.circular(20),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstallSummaryCard extends StatelessWidget {
  const _InstallSummaryCard({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.countLabel,
    required this.count,
    required this.installTooltip,
    required this.onOpen,
    required this.onInstall,
    required this.borderRadius,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final String countLabel;
  final int count;
  final String installTooltip;
  final VoidCallback onOpen;
  final VoidCallback onInstall;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled ? colors.onSurface : theme.disabledColor;
    final resolvedBorderRadius = borderRadius.resolve(
      Directionality.of(context),
    );
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: resolvedBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onOpen : null,
        child: SizedBox(
          height: 104,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: foreground),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            countLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: enabled
                                  ? colors.onSurfaceVariant
                                  : theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                end: 8,
                bottom: 8,
                child: Tooltip(
                  message: installTooltip,
                  child: Material(
                    color: enabled
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? onInstall : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Center(
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: enabled
                                ? colors.onSecondaryContainer
                                : theme.disabledColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.loading = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurface.withAlpha(96),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
