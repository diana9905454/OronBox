import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/modal/global_modal_coordinator.dart';
import '../core/services/shared_prefs_service.dart';
import '../host/application_host_provider.dart';
import 'local_server_runtime.dart';
import 'local_server_state.dart';

const localServerEnabledKey = 'local_server_enabled';

class LocalServerController extends Notifier<LocalServerState> {
  LocalServerRuntime? _runtime;
  Future<void>? _lateStartCleanup;

  @override
  LocalServerState build() {
    _runtime = LocalServerRuntime(
      commandBus: ref.read(applicationHostProvider),
      displayName: 'OronBox',
      platform: _platformName,
      onChanged: () => unawaited(_refresh()),
      onPairingRequested: (pairing) {
        ref
            .read(globalModalCoordinatorProvider.notifier)
            .showLocalServerPairing(
              pairingId: pairing.pairingId,
              clientName: pairing.clientName,
              fingerprint: pairing.fingerprint,
              scopes: pairing.requestedScopes,
              expiresAt: pairing.expiresAt,
              onApprove: (remember) =>
                  approvePairing(pairing.pairingId, remember: remember),
              onReject: () => rejectPairing(pairing.pairingId),
            );
      },
    );
    ref.onDispose(() {
      final runtime = _runtime;
      if (runtime != null) unawaited(runtime.stop());
    });

    final isSavedEnabled =
        SharedPrefsService.instance.isInitialized &&
        SharedPrefsService.instance.getBool(localServerEnabledKey) == true;
    if (isSavedEnabled) {
      Future.microtask(() => start(persist: false));
    }

    return const LocalServerState();
  }

  Future<void> start({bool persist = true}) async {
    if (state.isRunning || state.status == LocalServerStatus.starting) return;
    await _lateStartCleanup;
    state = state.copyWith(
      status: LocalServerStatus.starting,
      clearError: true,
    );
    try {
      final runtime = _runtime!;
      final starting = runtime.start();
      await starting.timeout(const Duration(seconds: 8));
      await _refresh();
      if (persist && SharedPrefsService.instance.isInitialized) {
        await SharedPrefsService.instance.setBool(localServerEnabledKey, true);
      }
    } on TimeoutException catch (error) {
      final runtime = _runtime!;
      final cleanup = runtime.stop().catchError((_) {});
      _lateStartCleanup = cleanup;
      unawaited(cleanup.whenComplete(() => _lateStartCleanup = null));
      state = state.copyWith(
        status: LocalServerStatus.error,
        error: error.toString(),
      );
    } catch (error) {
      state = state.copyWith(
        status: LocalServerStatus.error,
        error: error.toString(),
      );
    }
  }

  Future<void> stop({bool persist = true}) async {
    if (state.status == LocalServerStatus.stopping) return;
    state = state.copyWith(status: LocalServerStatus.stopping);
    try {
      await _runtime!.stop();
      state = const LocalServerState();
      if (persist && SharedPrefsService.instance.isInitialized) {
        await SharedPrefsService.instance.setBool(localServerEnabledKey, false);
      }
    } catch (error) {
      state = state.copyWith(
        status: LocalServerStatus.error,
        error: error.toString(),
      );
    }
  }

  Future<void> approvePairing(String pairingId, {bool remember = true}) async {
    _runtime?.approvePairing(pairingId, remember: remember);
    await _refresh();
  }

  Future<void> rejectPairing(String pairingId) async {
    _runtime?.rejectPairing(pairingId);
    await _refresh();
  }

  Future<void> revoke(String fingerprint) async {
    _runtime?.revokeClient(fingerprint);
    await _refresh();
  }

  Future<void> _refresh() async {
    final runtime = _runtime;
    final server = runtime?.server;
    if (server == null) {
      if (state.status != LocalServerStatus.starting) {
        state = const LocalServerState();
      }
      return;
    }
    final addresses = await _localAddresses(server.boundPort);
    state = LocalServerState(
      status: LocalServerStatus.running,
      info: server.info,
      addresses: addresses,
      pendingPairings: server.pendingPairings,
      authorizedClients: server.authorizedClients,
    );
  }
}

final localServerProvider =
    NotifierProvider<LocalServerController, LocalServerState>(
      LocalServerController.new,
    );

String get _platformName {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return Platform.operatingSystem;
}

Future<List<String>> _localAddresses(int port) async {
  final values = <String>[];
  try {
    final discovered = await Isolate.run(() async {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final result = <String>[];
      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          if (address.isLoopback) continue;
          result.add('http://${address.address}:$port');
        }
      }
      return result;
    }).timeout(const Duration(milliseconds: 1500));
    values.addAll(discovered);
  } catch (_) {}
  if (values.isEmpty) {
    values.add('http://127.0.0.1:$port');
  }
  return values.toSet().toList()..sort();
}
