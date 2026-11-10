import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'local_server_protocol.dart';

final BigInt _q = BigInt.two.pow(255) - BigInt.from(19);
final BigInt _l =
    BigInt.two.pow(252) +
    BigInt.parse('27742317777372353535851937790883648493');
final BigInt _d = (-BigInt.from(121665) * _inv(BigInt.from(121666))) % _q;
final BigInt _i = _modPow(BigInt.two, (_q - BigInt.one) ~/ BigInt.from(4), _q);

BigInt _inv(BigInt x) => _modPow(x, _q - BigInt.two, _q);

BigInt _modPow(BigInt base, BigInt exponent, BigInt modulus) {
  var b = base % modulus;
  var e = exponent;
  var result = BigInt.one;
  while (e > BigInt.zero) {
    if (e.isOdd) result = (result * b) % modulus;
    b = (b * b) % modulus;
    e ~/= BigInt.two;
  }
  return result;
}

class _Point {
  const _Point(this.x, this.y, this.z, this.t);

  final BigInt x;
  final BigInt y;
  final BigInt z;
  final BigInt t;

  static final _Point identity = _Point(
    BigInt.zero,
    BigInt.one,
    BigInt.one,
    BigInt.zero,
  );

  static _Point fromAffine(BigInt x, BigInt y) =>
      _Point(x, y, BigInt.one, (x * y) % _q);

  _Point add(_Point other) {
    final a = ((y - x) * (other.y - other.x)) % _q;
    final b = ((y + x) * (other.y + other.x)) % _q;
    final c = (t * BigInt.two * _d * other.t) % _q;
    final d = (z * BigInt.two * other.z) % _q;
    final e = (b - a) % _q;
    final f = (d - c) % _q;
    final g = (d + c) % _q;
    final h = (b + a) % _q;
    return _Point((e * f) % _q, (g * h) % _q, (f * g) % _q, (e * h) % _q);
  }

  _Point scalarMul(BigInt k) {
    var result = identity;
    var current = this;
    var n = k;
    while (n > BigInt.zero) {
      if (n.isOdd) result = result.add(current);
      current = current.add(current);
      n ~/= BigInt.two;
    }
    return result;
  }

  Uint8List toBytes() {
    final invZ = _inv(z);
    final xAffine = (x * invZ) % _q;
    final yAffine = (y * invZ) % _q;
    final buffer = Uint8List(32);
    _encodeInt(yAffine, buffer);
    if (xAffine.isOdd) {
      buffer[31] |= 0x80;
    }
    return buffer;
  }
}

final BigInt _by = (BigInt.from(4) * _inv(BigInt.from(5))) % _q;
final BigInt _bx = _recoverX(_by, false);
final _Point _basePoint = _Point.fromAffine(_bx, _by);

BigInt _recoverX(BigInt y, bool isOdd) {
  final u = (y * y - BigInt.one) % _q;
  final v = (_d * y * y + BigInt.one) % _q;
  var x2 = (u * _inv(v)) % _q;
  var x = _modPow(x2, (_q + BigInt.from(3)) ~/ BigInt.from(8), _q);
  if (((x * x) - x2) % _q != BigInt.zero) {
    x = (x * _i) % _q;
  }
  if (x.isOdd != isOdd) {
    x = (_q - x) % _q;
  }
  return x;
}

_Point? _decodePoint(Uint8List bytes) {
  if (bytes.length != 32) return null;
  final isOdd = (bytes[31] & 0x80) != 0;
  final yBytes = Uint8List.fromList(bytes);
  yBytes[31] &= 0x7f;
  final y = _decodeInt(yBytes);
  if (y >= _q) return null;
  try {
    final x = _recoverX(y, isOdd);
    if (((-x * x + y * y - BigInt.one - _d * x * x * y * y) % _q) !=
        BigInt.zero) {
      return null;
    }
    return _Point.fromAffine(x, y);
  } catch (_) {
    return null;
  }
}

void _encodeInt(BigInt value, Uint8List buffer) {
  var v = value;
  for (var i = 0; i < 32; i++) {
    buffer[i] = (v & BigInt.from(0xff)).toInt();
    v ~/= BigInt.from(256);
  }
}

BigInt _decodeInt(Uint8List buffer) {
  var result = BigInt.zero;
  for (var i = buffer.length - 1; i >= 0; i--) {
    result = (result * BigInt.from(256)) + BigInt.from(buffer[i]);
  }
  return result;
}

BigInt _hashModL(List<List<int>> chunks) {
  final combined = <int>[];
  for (final chunk in chunks) {
    combined.addAll(chunk);
  }
  final digestBytes = sha512.convert(combined).bytes;
  return _decodeInt(Uint8List.fromList(digestBytes)) % _l;
}

class Ed25519 {
  static (Uint8List privateKey, Uint8List publicKey) generateKeyPair({
    Uint8List? seed,
  }) {
    final rawSeed = seed ?? Uint8List(32);
    if (seed == null) {
      final random = Random.secure();
      for (var i = 0; i < 32; i++) {
        rawSeed[i] = random.nextInt(256);
      }
    }
    final digest = sha512.convert(rawSeed).bytes;
    final aBytes = Uint8List.fromList(digest.sublist(0, 32));
    aBytes[0] &= 248;
    aBytes[31] &= 127;
    aBytes[31] |= 64;
    final a = _decodeInt(aBytes);
    final pubPoint = _basePoint.scalarMul(a);
    final pubBytes = pubPoint.toBytes();
    return (rawSeed, pubBytes);
  }

  static Uint8List sign(Uint8List seed, Uint8List message) {
    final digest = sha512.convert(seed).bytes;
    final aBytes = Uint8List.fromList(digest.sublist(0, 32));
    aBytes[0] &= 248;
    aBytes[31] &= 127;
    aBytes[31] |= 64;
    final a = _decodeInt(aBytes);
    final pubBytes = _basePoint.scalarMul(a).toBytes();

    final prefix = digest.sublist(32, 64);
    final r = _hashModL([prefix, message]);
    final rPoint = _basePoint.scalarMul(r);
    final rBytes = rPoint.toBytes();

    final k = _hashModL([rBytes, pubBytes, message]);
    final s = (r + k * a) % _l;
    final sBytes = Uint8List(32);
    _encodeInt(s, sBytes);

    final signature = Uint8List(64);
    signature.setRange(0, 32, rBytes);
    signature.setRange(32, 64, sBytes);
    return signature;
  }

  static bool verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) {
    if (publicKey.length != 32 || signature.length != 64) return false;
    final rBytes = signature.sublist(0, 32);
    final sBytes = signature.sublist(32, 64);
    final s = _decodeInt(sBytes);
    if (s >= _l) return false;

    final aPoint = _decodePoint(publicKey);
    final rPoint = _decodePoint(rBytes);
    if (aPoint == null || rPoint == null) return false;

    final k = _hashModL([rBytes, publicKey, message]);
    final lhs = _basePoint.scalarMul(s);
    final rhs = rPoint.add(aPoint.scalarMul(k));
    return _pointsEqual(lhs, rhs);
  }

  static bool _pointsEqual(_Point p1, _Point p2) {
    final x1 = (p1.x * p2.z) % _q;
    final x2 = (p2.x * p1.z) % _q;
    final y1 = (p1.y * p2.z) % _q;
    final y2 = (p2.y * p1.z) % _q;
    return x1 == x2 && y1 == y2;
  }
}

class LocalServerEd25519KeyPair {
  const LocalServerEd25519KeyPair({
    required this.seed,
    required this.publicKey,
  });

  final Uint8List seed;
  final Uint8List publicKey;

  String get publicKeyBase64Url =>
      base64Url.encode(publicKey).replaceAll('=', '');

  String get publicKeyHex =>
      publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  String get fingerprint => sha256.convert(publicKey).toString().toLowerCase();

  factory LocalServerEd25519KeyPair.generate() {
    final (seed, pub) = Ed25519.generateKeyPair();
    return LocalServerEd25519KeyPair(seed: seed, publicKey: pub);
  }

  Uint8List sign(List<int> message) =>
      Ed25519.sign(seed, Uint8List.fromList(message));

  Map<String, Object?> toJson() => {
    'seed': base64Url.encode(seed).replaceAll('=', ''),
    'publicKey': publicKeyBase64Url,
  };

  factory LocalServerEd25519KeyPair.fromJson(Map<String, Object?> json) {
    final seedStr = json['seed']?.toString() ?? '';
    final pubStr = json['publicKey']?.toString() ?? '';
    final seed = decodeBase64Url(seedStr);
    final pub = pubStr.isNotEmpty
        ? decodeBase64Url(pubStr)
        : Ed25519.generateKeyPair(seed: seed).$2;
    return LocalServerEd25519KeyPair(seed: seed, publicKey: pub);
  }
}

Uint8List decodeBase64Url(String input) {
  final padded = '$input${'=' * ((4 - input.length % 4) % 4)}';
  return base64Url.decode(padded);
}

String fingerprintForPublicKey(String publicKeyBase64Url) {
  final bytes = decodeBase64Url(publicKeyBase64Url);
  return sha256.convert(bytes).toString().toLowerCase();
}

class LocalServerAuthException implements Exception {
  const LocalServerAuthException(this.code, this.message, {this.status = 400});

  final String code;
  final String message;
  final int status;

  @override
  String toString() => 'LocalServerAuthException($code): $message';
}

class LocalServerAuthenticator {
  LocalServerAuthenticator({
    required this.serverId,
    required this.serverIdentity,
    DateTime Function()? now,
    this.pairingLifetime = const Duration(minutes: 5),
    this.challengeLifetime = const Duration(seconds: 45),
    this.sessionLifetime = const Duration(hours: 24),
    Iterable<LocalAuthorizedClient> authorizedClients = const [],
  }) : now = now ?? DateTime.now {
    for (final client in authorizedClients) {
      _authorized[client.fingerprint] = client;
    }
  }

  final String serverId;
  final LocalServerEd25519KeyPair serverIdentity;
  final DateTime Function() now;
  final Duration pairingLifetime;
  final Duration challengeLifetime;
  final Duration sessionLifetime;

  final _authorized = <String, LocalAuthorizedClient>{};
  final _pendingPairings = <String, LocalServerPairingRequest>{};
  final _challenges = <String, _ActiveChallenge>{};
  final _sessions = <String, LocalServerSession>{};

  String get serverFingerprint => serverIdentity.fingerprint;

  List<LocalAuthorizedClient> get authorizedClients =>
      List.unmodifiable(_authorized.values);

  List<LocalServerPairingRequest> get pendingPairings => List.unmodifiable(
    _pendingPairings.values.where(
      (r) => r.state == LocalServerPairingState.pending,
    ),
  );

  LocalServerPairingRequest createPairingRequest({
    required String clientName,
    required String publicKey,
    required Set<String> requestedScopes,
    List<String> deviceAllowlist = const [],
  }) {
    clearExpired();
    final cleanKey = publicKey.trim();
    final pubBytes = decodeBase64Url(cleanKey);
    if (pubBytes.length != 32) {
      throw const LocalServerAuthException(
        'invalid_public_key',
        'Ed25519 public key must be 32 bytes',
      );
    }
    final fp = sha256.convert(pubBytes).toString().toLowerCase();

    // Check if already authorized
    final existingAuth = _authorized[fp];
    if (existingAuth != null) {
      final req = LocalServerPairingRequest(
        pairingId: _randomId('pair'),
        clientName: clientName,
        publicKey: cleanKey,
        fingerprint: fp,
        requestedScopes: requestedScopes.isEmpty
            ? existingAuth.scopes
            : requestedScopes,
        deviceAllowlist: deviceAllowlist,
        createdAt: now().toUtc(),
        expiresAt: now().toUtc().add(pairingLifetime),
        state: LocalServerPairingState.granted,
      );
      _pendingPairings[req.pairingId] = req;
      return req;
    }

    // Reuse existing pending if identical
    for (final pending in _pendingPairings.values) {
      if (pending.fingerprint == fp &&
          pending.state == LocalServerPairingState.pending) {
        return pending;
      }
    }

    final req = LocalServerPairingRequest(
      pairingId: _randomId('pair'),
      clientName: clientName,
      publicKey: cleanKey,
      fingerprint: fp,
      requestedScopes: Set.unmodifiable(requestedScopes),
      deviceAllowlist: List.unmodifiable(deviceAllowlist),
      createdAt: now().toUtc(),
      expiresAt: now().toUtc().add(pairingLifetime),
      state: LocalServerPairingState.pending,
    );
    _pendingPairings[req.pairingId] = req;
    return req;
  }

  LocalServerPairingRequest? getPairingRequest(String pairingId) {
    clearExpired();
    return _pendingPairings[pairingId];
  }

  void approvePairing(String pairingId) {
    final req = _pendingPairings[pairingId];
    if (req == null) return;
    req.state = LocalServerPairingState.granted;
    _authorized[req.fingerprint] = LocalAuthorizedClient(
      fingerprint: req.fingerprint,
      publicKey: req.publicKey,
      displayName: req.clientName,
      scopes: req.requestedScopes,
      deviceAllowlist: req.deviceAllowlist,
      authorizedAt: now().toUtc(),
    );
  }

  void approveClient(LocalAuthorizedClient client) {
    _authorized[client.fingerprint] = client;
    for (final req in _pendingPairings.values) {
      if (req.fingerprint == client.fingerprint) {
        req.state = LocalServerPairingState.granted;
      }
    }
  }

  void rejectPairing(String pairingId) {
    final req = _pendingPairings[pairingId];
    if (req == null) return;
    req.state = LocalServerPairingState.denied;
  }

  void rejectClient(String fingerprint) {
    _pendingPairings.removeWhere((_, req) => req.fingerprint == fingerprint);
  }

  void revokeClient(String fingerprint) {
    _authorized.remove(fingerprint);
    _pendingPairings.removeWhere((_, req) => req.fingerprint == fingerprint);
    _sessions.removeWhere((_, s) => s.fingerprint == fingerprint);
  }

  LocalServerChallenge issueChallenge({required String fingerprint}) {
    clearExpired();
    final fp = fingerprint.trim().toLowerCase();
    final client = _authorized[fp];
    if (client == null) {
      throw const LocalServerAuthException(
        'client_not_paired',
        'Client has not completed pairing approval',
        status: 403,
      );
    }

    final challengeId = _randomId('ch');
    final payloadBytes = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < 32; i++) {
      payloadBytes[i] = random.nextInt(256);
    }
    final signingPayload = base64Url.encode(payloadBytes).replaceAll('=', '');

    final challenge = LocalServerChallenge(
      challengeId: challengeId,
      signingPayload: signingPayload,
      fingerprint: fp,
      expiresAt: now().toUtc().add(challengeLifetime),
    );

    _challenges[challengeId] = _ActiveChallenge(
      challenge: challenge,
      client: client,
      payloadBytes: payloadBytes,
    );
    return challenge;
  }

  LocalServerSession createSession({
    required String challengeId,
    required String signatureBase64Url,
  }) {
    clearExpired();
    final active = _challenges.remove(challengeId);
    if (active == null || now().toUtc().isAfter(active.challenge.expiresAt)) {
      throw const LocalServerAuthException(
        'invalid_challenge',
        'Challenge expired or unknown',
        status: 401,
      );
    }

    final pubBytes = decodeBase64Url(active.client.publicKey);
    final sigBytes = decodeBase64Url(signatureBase64Url);
    if (sigBytes.length != 64) {
      throw const LocalServerAuthException(
        'invalid_signature',
        'Ed25519 signature must be 64 bytes',
        status: 401,
      );
    }

    final valid = Ed25519.verify(pubBytes, active.payloadBytes, sigBytes);
    if (!valid) {
      throw const LocalServerAuthException(
        'signature_verification_failed',
        'Ed25519 signature is invalid',
        status: 401,
      );
    }

    final token = _randomToken();
    final session = LocalServerSession(
      token: token,
      tokenType: 'Bearer',
      clientId: active.client.displayName,
      fingerprint: active.client.fingerprint,
      scopes: active.client.scopes,
      deviceAllowlist: active.client.deviceAllowlist,
      expiresAt: now().toUtc().add(sessionLifetime),
    );
    _sessions[token] = session;
    return session;
  }

  LocalServerSession? verifySession(String token) {
    final session = _sessions[token];
    if (session == null) return null;
    if (now().toUtc().isAfter(session.expiresAt)) {
      _sessions.remove(token);
      return null;
    }
    return session;
  }

  void clearExpired() {
    final current = now().toUtc();
    _challenges.removeWhere((_, c) => current.isAfter(c.challenge.expiresAt));
    _sessions.removeWhere((_, s) => current.isAfter(s.expiresAt));
    _pendingPairings.removeWhere(
      (_, p) =>
          p.state == LocalServerPairingState.pending &&
          current.isAfter(p.expiresAt),
    );
  }
}

class _ActiveChallenge {
  const _ActiveChallenge({
    required this.challenge,
    required this.client,
    required this.payloadBytes,
  });

  final LocalServerChallenge challenge;
  final LocalAuthorizedClient client;
  final Uint8List payloadBytes;
}

String _randomId(String prefix) => '$prefix-${_randomToken()}';

String _randomToken() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
