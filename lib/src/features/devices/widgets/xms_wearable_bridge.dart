import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/widgets/xms_fingerprint.dart';
import 'package:oronbox/src/device/core/device_state.dart';

class XmsWearableBridge extends ConsumerStatefulWidget {
  const XmsWearableBridge({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<XmsWearableBridge> createState() => _XmsWearableBridgeState();
}

class _XmsWearableBridgeState extends ConsumerState<XmsWearableBridge> {
  static const _channel = MethodChannel('oronbox/xms_wearable');
  static final _log = getLogger('XmsWearableBridge');
  StreamSubscription? _messages;
  ProviderSubscription<DeviceManagerState>? _deviceState;

  @override
  void initState() {
    super.initState();
    // XMS wearable is an Android-only SDK for VelaOS (Xiaomi) devices.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler(_handleCall);
    final manager = ref.read(deviceManagerProvider.notifier);
    _messages = manager.interconnectMessages.listen((message) {
      if (!_isVelaOsDevice) return;
      _log.info(
        'forwarding interconnect reply package=${message.pkgName} '
        'bytes=${message.payload.length}',
      );
      unawaited(
        _channel.invokeMethod<void>('messageReceived', {
          'packageName': message.pkgName,
          'nodeId': message.deviceId,
          'payload': message.payload,
        }),
      );
    });
    _deviceState = ref.listenManual(deviceManagerProvider, (previous, next) {
      final previousConnected = previous?.protocolState == ProtocolState.ready;
      final nextConnected = next.protocolState == ProtocolState.ready;
      if (previousConnected != nextConnected) {
        _emitDataChanged(1, nextConnected ? 1 : 2);
      }
      final previousChargingStatus = _chargingStatus(previous);
      final nextChargingStatus = _chargingStatus(next);
      if (previousChargingStatus != nextChargingStatus) {
        _emitDataChanged(2, nextChargingStatus ?? 2);
      }
      if (previous?.battery?.capacity != next.battery?.capacity) {
        _emitDataChanged(5, next.battery?.capacity ?? 0);
      }
    });
  }

  bool get _isVelaOsDevice =>
      ref.read(deviceManagerProvider.notifier).currentDeviceKind ==
      DeviceKind.xiaomi;

  void _emitDataChanged(int type, Object value) {
    if (!_isVelaOsDevice) return;
    unawaited(
      _channel.invokeMethod<void>('dataChanged', {
        'nodeId': ref.read(deviceManagerProvider).currentDevice?.addr ?? '',
        'type': type,
        'value': value,
      }),
    );
  }

  int? _chargingStatus(DeviceManagerState? state) {
    final healthStatus = state?.health?.chargingStatus;
    if (healthStatus != null) return healthStatus;
    return switch (state?.battery?.chargeStatus) {
      ChargeStatus.charging => 1,
      ChargeStatus.notCharging => 2,
      ChargeStatus.full => 3,
      ChargeStatus.unknown || null => null,
    };
  }

  Future<Object?> _handleCall(MethodCall call) async {
    _log.info('received native XMS call ${call.method}');
    final manager = ref.read(deviceManagerProvider.notifier);
    final state = ref.read(deviceManagerProvider);
    final arguments =
        (call.arguments as Map?)?.cast<Object?, Object?>() ?? const {};
    switch (call.method) {
      case 'getConnectedNodes':
        if (state.protocolState != ProtocolState.ready ||
            state.currentDevice == null) {
          return const <Object>[];
        }
        return [
          {'id': state.currentDevice!.addr, 'name': state.currentDevice!.name},
        ];
      case 'verifyCaller':
        final packageName = arguments['packageName']?.toString() ?? '';
        final supplied =
            (arguments['fingerprint'] as Uint8List?)?.toList() ?? const <int>[];
        if (SharedPrefsService.instance.getBool(xmsDeveloperSkipSignatureKey) ??
            false) {
          _log.warning(
            'caller signature verification bypassed in developer mode '
            'package=$packageName suppliedBytes=${supplied.length}',
          );
          return true;
        }
        final app = await _findApp(manager, packageName);
        final allowed =
            app != null &&
            app.fingerprint.isNotEmpty &&
            xmsFingerprintsMatch(app.fingerprint, supplied);
        _log.info(
          'caller signature verification package=$packageName '
          'deviceBytes=${app?.fingerprint.length ?? 0} '
          'suppliedBytes=${supplied.length} allowed=$allowed',
        );
        return allowed;
      case 'isWearAppInstalled':
        return await _findApp(
              manager,
              arguments['packageName']?.toString() ?? '',
            ) !=
            null;
      case 'launchWearApp':
        final app = await _requireApp(
          manager,
          arguments['packageName']?.toString() ?? '',
        );
        await manager.openApp(app, page: arguments['uri']?.toString() ?? '');
        return null;
      case 'sendMessage':
        _log.info(
          'sending interconnect request package=${arguments['packageName']} '
          'bytes=${(arguments['payload'] as Uint8List?)?.length ?? 0}',
        );
        await manager.sendInterconnectMessage(
          arguments['packageName']?.toString() ?? '',
          arguments['payload'] as Uint8List? ?? Uint8List(0),
        );
        return null;
      case 'query':
        final type = (arguments['type'] as num?)?.toInt() ?? 0;
        return {
          'value': switch (type) {
            1 => state.protocolState == ProtocolState.ready ? 1 : 2,
            2 =>
              state.health?.isCharging ??
                  (state.battery?.chargeStatus == ChargeStatus.charging),
            3 || 4 => throw PlatformException(
              code: 'unsupported',
              message: 'Sleep and wearing status are not supported',
            ),
            5 => state.battery?.capacity ?? 0,
            _ => false,
          },
        };
      case 'sendNotify':
        throw PlatformException(
          code: 'unsupported',
          message: 'Device notification delivery is unavailable',
        );
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<AppInfo?> _findApp(DeviceManager manager, String packageName) async {
    AppInfo? find() => ref
        .read(deviceManagerProvider)
        .apps
        .cast<AppInfo?>()
        .firstWhere(
          (app) => app?.packageName == packageName,
          orElse: () => null,
        );
    var app = find();
    if (app != null) return app;
    await manager.fetchApps();
    return find();
  }

  Future<AppInfo> _requireApp(DeviceManager manager, String packageName) async {
    final app = await _findApp(manager, packageName);
    if (app == null) {
      throw PlatformException(code: 'not_installed', message: packageName);
    }
    return app;
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    _deviceState?.close();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
