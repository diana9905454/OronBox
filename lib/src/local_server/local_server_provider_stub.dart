import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_server_state.dart';

final localServerProvider =
    NotifierProvider<LocalServerController, LocalServerState>(
      LocalServerController.new,
    );

class LocalServerController extends Notifier<LocalServerState> {
  @override
  LocalServerState build() => const LocalServerState();

  Future<void> start() async {}
  Future<void> stop() async {}
  Future<void> approvePairing(String pairingId, {bool remember = true}) async {}
  Future<void> rejectPairing(String pairingId) async {}
  Future<void> revoke(String fingerprint) async {}
}
