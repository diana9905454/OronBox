import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/local_server/local_server_auth.dart';
import 'package:oronbox/src/local_server/local_server_protocol.dart';
import 'package:oronbox/src/local_server/local_server_runtime.dart';

void main() {
  group('LocalServerRuntime and IdentityStore', () {
    test('loads or generates server identity and persists clients', () async {
      final root = await Directory.systemTemp.createTemp(
        'oronbox-identity-test-',
      );
      addTearDown(() => root.delete(recursive: true));

      final store = LocalServerIdentityStore(
        directoryProvider: () async => root,
      );
      final first = await store.loadOrCreate();
      expect(first.serverId, startsWith('oronbox-'));
      expect(first.keyPair.fingerprint.length, 64);

      final second = await store.loadOrCreate();
      expect(second.serverId, first.serverId);
      expect(second.keyPair.fingerprint, first.keyPair.fingerprint);

      expect(await store.loadAuthorizedClients(), isEmpty);

      final client = LocalAuthorizedClient(
        fingerprint: 'fp-1',
        publicKey: 'pub-1',
        displayName: 'Test Client',
        scopes: {'device.read'},
        authorizedAt: DateTime.utc(2026, 1, 1),
      );
      await store.saveAuthorizedClients([client]);

      final loaded = await store.loadAuthorizedClients();
      expect(loaded.length, 1);
      expect(loaded.first.fingerprint, 'fp-1');
      expect(loaded.first.displayName, 'Test Client');
    });

    test('runtime manages server lifecycle and callbacks', () async {
      final root = await Directory.systemTemp.createTemp(
        'oronbox-runtime-test-',
      );
      addTearDown(() => root.delete(recursive: true));

      final host = _FakeCommandBus();
      var changedCount = 0;

      final runtime = LocalServerRuntime(
        commandBus: host,
        displayName: 'Test OronBox',
        platform: 'macos',
        port: 0,
        identityStore: LocalServerIdentityStore(
          directoryProvider: () async => root,
        ),
        temporaryDirectoryProvider: () async => root,
        onChanged: () => changedCount++,
      );

      final server = await runtime.start();
      expect(server.isRunning, isTrue);
      expect(runtime.server, isNotNull);

      final clientPair = LocalServerEd25519KeyPair.generate();
      final pairing = server.authenticator.createPairingRequest(
        clientName: 'CLI Tool',
        publicKey: clientPair.publicKeyBase64Url,
        requestedScopes: {'device.read'},
      );

      runtime.approvePairing(pairing.pairingId);
      expect(runtime.authorizedClients.length, 1);
      expect(
        runtime.authorizedClients.first.fingerprint,
        clientPair.fingerprint,
      );

      await runtime.stop();
      expect(runtime.server, isNull);
      expect(changedCount, greaterThan(0));
    });
  });
}

class _FakeCommandBus implements OronBoxCommandBus {
  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async =>
      const CommandResult.success(null);

  @override
  Future<void> close() async {}
}
