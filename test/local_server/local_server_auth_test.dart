import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/local_server/local_server_auth.dart';
import 'package:oronbox/src/local_server/local_server_protocol.dart';

void main() {
  group('Ed25519 Cryptography', () {
    test('generates key pair, signs and verifies', () {
      final (seed, pub) = Ed25519.generateKeyPair();
      expect(seed.length, 32);
      expect(pub.length, 32);

      final msg = Uint8List.fromList(utf8.encode('test message'));
      final sig = Ed25519.sign(seed, msg);
      expect(sig.length, 64);

      final valid = Ed25519.verify(pub, msg, sig);
      expect(valid, isTrue);

      final corruptedMsg = Uint8List.fromList(utf8.encode('test corrupted'));
      expect(Ed25519.verify(pub, corruptedMsg, sig), isFalse);

      final otherKey = Ed25519.generateKeyPair().$2;
      expect(Ed25519.verify(otherKey, msg, sig), isFalse);
    });

    test('LocalServerEd25519KeyPair serialization and properties', () {
      final pair = LocalServerEd25519KeyPair.generate();
      expect(pair.publicKeyBase64Url, isNotEmpty);
      expect(pair.publicKeyHex.length, 64);
      expect(pair.fingerprint.length, 64);

      final json = pair.toJson();
      final restored = LocalServerEd25519KeyPair.fromJson(json);
      expect(restored.seed, pair.seed);
      expect(restored.publicKey, pair.publicKey);
      expect(restored.fingerprint, pair.fingerprint);
    });
  });

  group('LocalServerAuthenticator', () {
    test('handles pairing requests, approvals and challenges', () {
      final serverPair = LocalServerEd25519KeyPair.generate();
      final clientPair = LocalServerEd25519KeyPair.generate();

      final auth = LocalServerAuthenticator(
        serverId: 'server-test',
        serverIdentity: serverPair,
        now: () => DateTime.utc(2026, 1, 1),
      );

      // Initially client is not paired
      expect(
        () => auth.issueChallenge(fingerprint: clientPair.fingerprint),
        throwsA(isA<LocalServerAuthException>()),
      );

      // Create pairing request
      final pairing = auth.createPairingRequest(
        clientName: 'VS Code CLI',
        publicKey: clientPair.publicKeyBase64Url,
        requestedScopes: {'device.read', 'device.control'},
      );
      expect(pairing.state, LocalServerPairingState.pending);
      expect(auth.pendingPairings.length, 1);

      // Approve pairing
      auth.approvePairing(pairing.pairingId);
      expect(pairing.state, LocalServerPairingState.granted);
      expect(auth.authorizedClients.length, 1);
      expect(auth.authorizedClients.first.fingerprint, clientPair.fingerprint);

      // Issue challenge
      final challenge = auth.issueChallenge(
        fingerprint: clientPair.fingerprint,
      );
      expect(challenge.challengeId, isNotEmpty);
      expect(challenge.signingPayload, isNotEmpty);

      // Sign challenge
      final payloadBytes = decodeBase64Url(challenge.signingPayload);
      final sig = clientPair.sign(payloadBytes);
      final sigBase64Url = base64Url.encode(sig).replaceAll('=', '');

      // Verify and create session
      final session = auth.createSession(
        challengeId: challenge.challengeId,
        signatureBase64Url: sigBase64Url,
      );
      expect(session.token, isNotEmpty);
      expect(session.fingerprint, clientPair.fingerprint);
      expect(session.scopes, contains('device.read'));

      // Validate session
      final verified = auth.verifySession(session.token);
      expect(verified, isNotNull);
      expect(verified!.clientId, 'VS Code CLI');

      // Re-using challenge fails
      expect(
        () => auth.createSession(
          challengeId: challenge.challengeId,
          signatureBase64Url: sigBase64Url,
        ),
        throwsA(isA<LocalServerAuthException>()),
      );

      // Revoking client invalidates session
      auth.revokeClient(clientPair.fingerprint);
      expect(auth.verifySession(session.token), isNull);
      expect(auth.authorizedClients, isEmpty);
    });

    test('rejects expired challenges', () {
      var current = DateTime.utc(2026, 1, 1);
      final serverPair = LocalServerEd25519KeyPair.generate();
      final clientPair = LocalServerEd25519KeyPair.generate();

      final auth = LocalServerAuthenticator(
        serverId: 'server-test',
        serverIdentity: serverPair,
        now: () => current,
        challengeLifetime: const Duration(seconds: 30),
      );

      auth.approveClient(
        LocalAuthorizedClient(
          fingerprint: clientPair.fingerprint,
          publicKey: clientPair.publicKeyBase64Url,
          displayName: 'CLI',
          scopes: {'device.read'},
          authorizedAt: current,
        ),
      );

      final challenge = auth.issueChallenge(
        fingerprint: clientPair.fingerprint,
      );
      current = current.add(const Duration(seconds: 31));

      final payloadBytes = decodeBase64Url(challenge.signingPayload);
      final sig = clientPair.sign(payloadBytes);
      final sigBase64Url = base64Url.encode(sig).replaceAll('=', '');

      expect(
        () => auth.createSession(
          challengeId: challenge.challengeId,
          signatureBase64Url: sigBase64Url,
        ),
        throwsA(isA<LocalServerAuthException>()),
      );
    });
  });
}
