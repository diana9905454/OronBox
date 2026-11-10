import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/local_server/local_server_protocol.dart';

void main() {
  group('LocalServerProtocol', () {
    test('LocalServerInfo serializes and deserializes', () {
      const info = LocalServerInfo(
        serverId: 'server-1',
        displayName: 'OronBox Local Server',
        platform: 'macos',
        port: 10517,
        protocolVersion: 1,
        capabilities: {'device.list', 'install.upload', 'events.stream'},
        fingerprint: 'abcdef0123456789',
        publicKeyHex: '1234',
        secure: false,
      );

      final json = info.toJson();
      expect(json['auth'], 'ed25519-challenge');
      expect(json['transport'], 'http');

      final restored = LocalServerInfo.fromJson(json);
      expect(restored, equals(info));
    });

    test('LocalServerPairingRequest serialization and public status', () {
      final req = LocalServerPairingRequest(
        pairingId: 'pair-123',
        clientName: 'Test CLI',
        publicKey: 'pubKeyBase64',
        fingerprint: 'fp123',
        requestedScopes: {'device.read', 'resource.install'},
        deviceAllowlist: ['dev-1'],
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
        state: LocalServerPairingState.pending,
      );

      final json = req.toJson();
      final restored = LocalServerPairingRequest.fromJson(json);
      expect(restored.pairingId, req.pairingId);
      expect(restored.clientName, req.clientName);
      expect(restored.state, LocalServerPairingState.pending);

      final publicStatus = req.toPublicStatus();
      expect(publicStatus['pairingId'], 'pair-123');
      expect(publicStatus['state'], 'pending');
      expect(publicStatus['scopes'], contains('device.read'));
    });

    test('LocalServerChallenge and LocalServerSession models', () {
      final challenge = LocalServerChallenge(
        challengeId: 'ch-1',
        signingPayload: 'payload-base64',
        fingerprint: 'fp-1',
        expiresAt: DateTime.utc(2026, 1, 1, 0, 1),
      );
      final chJson = challenge.toJson();
      final restoredCh = LocalServerChallenge.fromJson(chJson);
      expect(restoredCh.challengeId, 'ch-1');
      expect(restoredCh.signingPayload, 'payload-base64');

      final session = LocalServerSession(
        token: 'token-abc',
        tokenType: 'Bearer',
        clientId: 'cli-1',
        fingerprint: 'fp-1',
        scopes: {'device.read'},
        expiresAt: DateTime.utc(2026, 1, 2),
      );
      final sessJson = session.toJson();
      final restoredSess = LocalServerSession.fromJson(sessJson);
      expect(restoredSess.token, 'token-abc');
      expect(restoredSess.tokenType, 'Bearer');
    });

    test('LocalServerInstallRequest validation', () {
      final valid = LocalServerInstallRequest.fromJson({
        'fileName': 'app.rpk',
        'type': 'app',
        'sha256': 'a' * 64,
        'size': 1024,
      });
      expect(valid.fileName, 'app.rpk');
      expect(valid.size, 1024);

      expect(
        () => LocalServerInstallRequest.fromJson({
          'fileName': '',
          'type': 'app',
          'sha256': 'a' * 64,
          'size': 1024,
        }),
        throwsFormatException,
      );

      expect(
        () => LocalServerInstallRequest.fromJson({
          'fileName': 'app.rpk',
          'type': 'app',
          'sha256': 'short',
          'size': 1024,
        }),
        throwsFormatException,
      );
    });
  });
}
