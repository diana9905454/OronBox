import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/systems/screenshot_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';
import 'package:oronbox/src/device/xiaomi/utils/auth_utils.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_account.pb.dart'
    as pb_account;
import 'package:oronbox/src/device/xiaomi/protocol/crypto/miwear_crypto.dart';

class XiaomiAuthSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiAuthSystem');
  Completer<void>? _completer;
  String? _authKeyHex;
  Uint8List? _appRandom;

  Future<void> authenticate(String authKeyHex) async {
    _log.info('[${entity.id}] starting auth');
    entity.system<XiaomiScreenshotSystem>()?.resetSession();
    _authKeyHex = authKeyHex;
    _appRandom = generateRandomBytes(16);
    _completer = Completer<void>();
    final packet = buildAuthStep1(_appRandom!);
    try {
      await component.sendPbPacketUnencrypted(packet);
    } catch (e, st) {
      _log.severe('[${entity.id}] failed to send auth step 1', e, st);
      _completeError(e);
      rethrow;
    }
    return _completer!.future;
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.account) return;
    final account = packet.account;
    _log.fine('[${entity.id}] account payload: ${account.whichPayload()}');
    switch (account.whichPayload()) {
      case pb_account.Account_Payload.authDeviceVerify:
        _onDeviceVerify(account.authDeviceVerify);
      case pb_account.Account_Payload.authDeviceConfirm:
        _onDeviceConfirm(account.authDeviceConfirm);
      default:
        break;
    }
  }

  Future<void> _onDeviceVerify(pb_account.Auth_DeviceVerify verify) async {
    try {
      if (_authKeyHex == null || _appRandom == null) {
        throw StateError('auth state missing');
      }
      _log.info('[${entity.id}] received device verify, building confirm');
      final (keys, confirmPacket) = buildAuthStep2(
        authKeyHex: _authKeyHex!,
        appRandom: _appRandom!,
        deviceVerify: verify,
      );
      component.authKeys = keys;
      await component.sendPbPacketUnencrypted(confirmPacket);
    } catch (e, st) {
      _log.severe('[${entity.id}] auth step 2 failed', e, st);
      entity.emit(AuthFailed(deviceId: entity.id, error: e.toString()));
      _completeError(e);
    }
  }

  void _onDeviceConfirm(pb_account.Auth_DeviceConfirm confirm) {
    if (confirm.confirmResult) {
      _log.info('[${entity.id}] auth confirmed');
      final cap1 = confirm.hasDeviceCapability() ? confirm.deviceCapability : 0;
      final cap2 =
          confirm.hasDeviceCapability2() ? confirm.deviceCapability2 : 0;
      entity.emit(
        XiaomiDeviceCapabilitiesUpdated(
          deviceId: entity.id,
          deviceCapability: cap1,
          deviceCapabilityV2: cap2,
        ),
      );
      unawaited(_finishAuthentication());
    } else {
      final error = 'auth confirm rejected by device';
      _log.warning('[${entity.id}] $error');
      entity.emit(AuthFailed(deviceId: entity.id, error: error));
      _completeError(Exception(error));
    }
  }

  Future<void> _finishAuthentication() async {
    // Capability registration is best effort.  It must not turn an otherwise
    // usable device connection into an auth failure.
    await entity
        .system<XiaomiScreenshotSystem>()
        ?.negotiateAfterAuthentication();
    entity.emit(DeviceAuthenticated(deviceId: entity.id));
    final c = _completer;
    _completer = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  void _completeError(Object error) {
    final c = _completer;
    _completer = null;
    if (c != null && !c.isCompleted) {
      c.completeError(error);
    }
  }

  @override
  Future<void> dispose() async {
    _completeError(StateError('auth system disposed'));
    await super.dispose();
  }
}
