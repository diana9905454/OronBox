import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

Future<void> requestBluetoothPermissionOnStartup() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
  try {
    // Creating CBCentralManager is what makes macOS show the Bluetooth privacy
    // prompt. UniversalBle keeps the manager lazy until its first API call.
    await UniversalBle.requestPermissions(withAndroidFineLocation: false);
  } catch (error, stackTrace) {
    getLogger('BluetoothPermissionBootstrap').warning(
      'Unable to request Bluetooth access at startup',
      error,
      stackTrace,
    );
  }
}
