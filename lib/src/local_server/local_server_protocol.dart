const defaultLocalServerPort = 10517;

/// Wire protocol version for the OronBox Local API Server.
const localServerProtocolVersion = 1;

/// Standard capabilities advertised by the Local API Server.
const localServerCapabilities = <String>{
  'auth.ed25519',
  'auth.pairing',
  'discovery.mdns',
  'device.list',
  'device.current',
  'device.control',
  'app.list',
  'app.launch',
  'app.uninstall',
  'watchface.list',
  'watchface.set',
  'watchface.remove',
  'device.logs.export',
  'device.logs.download',
  'install.upload',
  'task.status',
  'task.cancel',
  'events.stream',
};

/// Permission scopes requested by and granted to external CLI and integration clients.
const localServerScopes = <String>{
  'device.read',
  'device.control',
  'app.read',
  'app.control',
  'watchface.read',
  'watchface.control',
  'diagnostics.read',
  'resource.read',
  'resource.control',
  'install.upload',
  'task.read',
  'task.control',
  'events.subscribe',
};

const localServerJsonContentType = 'application/json; charset=utf-8';
const localServerEventContentType = 'text/event-stream; charset=utf-8';
const localServerUploadContentType = 'application/octet-stream';
const localServerEventsPath = '/v1/events';

enum LocalServerOperationState { queued, running, completed, failed, cancelled }

enum LocalServerPairingState { pending, granted, denied }

class LocalServerInfo {
  const LocalServerInfo({
    required this.serverId,
    required this.displayName,
    required this.platform,
    required this.port,
    required this.protocolVersion,
    required this.capabilities,
    required this.fingerprint,
    this.publicKeyHex = '',
    this.secure = false,
    this.discoveryService = '_oronbox-api._tcp.local',
  });

  final String serverId;
  final String displayName;
  final String platform;
  final int port;
  final int protocolVersion;
  final Set<String> capabilities;
  final String fingerprint;
  final String publicKeyHex;
  final bool secure;
  final String discoveryService;

  Map<String, Object?> toJson() => {
    'serverId': serverId,
    'displayName': displayName,
    'platform': platform,
    'port': port,
    'protocolVersion': protocolVersion,
    'capabilities': capabilities.toList()..sort(),
    'fingerprint': fingerprint,
    if (publicKeyHex.isNotEmpty) 'publicKeyHex': publicKeyHex,
    'secure': secure,
    'transport': 'http',
    'auth': 'ed25519-challenge',
    'discoveryService': discoveryService,
  };

  factory LocalServerInfo.fromJson(Map<String, Object?> json) {
    final capabilities = json['capabilities'];
    return LocalServerInfo(
      serverId: _requiredString(json, 'serverId'),
      displayName: _requiredString(json, 'displayName'),
      platform: _requiredString(json, 'platform'),
      port: _requiredInt(json, 'port'),
      protocolVersion: _requiredInt(json, 'protocolVersion'),
      capabilities: capabilities is List
          ? capabilities.map((value) => value.toString()).toSet()
          : const {},
      fingerprint: _requiredString(json, 'fingerprint'),
      publicKeyHex: json['publicKeyHex']?.toString() ?? '',
      secure: json['secure'] == true,
      discoveryService:
          json['discoveryService']?.toString() ?? '_oronbox-api._tcp.local',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocalServerInfo &&
      other.serverId == serverId &&
      other.displayName == displayName &&
      other.platform == platform &&
      other.port == port &&
      other.protocolVersion == protocolVersion &&
      other.capabilities.length == capabilities.length &&
      other.capabilities.containsAll(capabilities) &&
      other.fingerprint == fingerprint &&
      other.publicKeyHex == publicKeyHex &&
      other.secure == secure &&
      other.discoveryService == discoveryService;

  @override
  int get hashCode => Object.hash(
    serverId,
    displayName,
    platform,
    port,
    protocolVersion,
    Object.hashAll(capabilities),
    fingerprint,
    publicKeyHex,
    secure,
    discoveryService,
  );
}

class LocalAuthorizedClient {
  const LocalAuthorizedClient({
    required this.fingerprint,
    required this.publicKey,
    required this.displayName,
    required this.scopes,
    this.deviceAllowlist = const [],
    required this.authorizedAt,
  });

  final String fingerprint;
  final String publicKey;
  final String displayName;
  final Set<String> scopes;
  final List<String> deviceAllowlist;
  final DateTime authorizedAt;

  Map<String, Object?> toJson() => {
    'fingerprint': fingerprint,
    'publicKey': publicKey,
    'displayName': displayName,
    'scopes': scopes.toList()..sort(),
    'deviceAllowlist': deviceAllowlist,
    'authorizedAt': authorizedAt.toIso8601String(),
  };

  factory LocalAuthorizedClient.fromJson(Map<String, Object?> json) {
    final scopes = json['scopes'];
    final allowlist = json['deviceAllowlist'];
    final authorizedAtRaw = json['authorizedAt']?.toString();
    return LocalAuthorizedClient(
      fingerprint: _requiredString(json, 'fingerprint'),
      publicKey: _requiredString(json, 'publicKey'),
      displayName: _requiredString(json, 'displayName'),
      scopes: scopes is List
          ? scopes.map((v) => v.toString()).toSet()
          : const {},
      deviceAllowlist: allowlist is List
          ? allowlist.map((v) => v.toString()).toList()
          : const [],
      authorizedAt: authorizedAtRaw != null
          ? DateTime.tryParse(authorizedAtRaw) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocalAuthorizedClient &&
      other.fingerprint == fingerprint &&
      other.publicKey == publicKey &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(fingerprint, publicKey, displayName);
}

class LocalServerPairingRequest {
  LocalServerPairingRequest({
    required this.pairingId,
    required this.clientName,
    required this.publicKey,
    required this.fingerprint,
    required this.requestedScopes,
    this.deviceAllowlist = const [],
    required this.createdAt,
    required this.expiresAt,
    this.state = LocalServerPairingState.pending,
  });

  final String pairingId;
  final String clientName;
  final String publicKey;
  final String fingerprint;
  final Set<String> requestedScopes;
  final List<String> deviceAllowlist;
  final DateTime createdAt;
  final DateTime expiresAt;
  LocalServerPairingState state;

  Map<String, Object?> toJson() => {
    'pairingId': pairingId,
    'clientName': clientName,
    'publicKey': publicKey,
    'fingerprint': fingerprint,
    'requestedScopes': requestedScopes.toList()..sort(),
    'deviceAllowlist': deviceAllowlist,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'state': state.name,
  };

  Map<String, Object?> toPublicStatus() => {
    'pairingId': pairingId,
    'state': state.name,
    'scopes': requestedScopes.toList()..sort(),
    'deviceAllowlist': deviceAllowlist,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LocalServerPairingRequest.fromJson(Map<String, Object?> json) {
    final scopes = json['requestedScopes'] ?? json['scopes'];
    final allowlist = json['deviceAllowlist'];
    final stateString = json['state']?.toString() ?? 'pending';
    return LocalServerPairingRequest(
      pairingId: _requiredString(json, 'pairingId'),
      clientName: json['clientName']?.toString() ?? 'cli',
      publicKey: _requiredString(json, 'publicKey'),
      fingerprint: _requiredString(json, 'fingerprint'),
      requestedScopes: scopes is List
          ? scopes.map((v) => v.toString()).toSet()
          : const {},
      deviceAllowlist: allowlist is List
          ? allowlist.map((v) => v.toString()).toList()
          : const [],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
      state: LocalServerPairingState.values.firstWhere(
        (s) => s.name == stateString,
        orElse: () => LocalServerPairingState.pending,
      ),
    );
  }
}

class LocalServerChallenge {
  const LocalServerChallenge({
    required this.challengeId,
    required this.signingPayload,
    required this.fingerprint,
    required this.expiresAt,
  });

  final String challengeId;
  final String signingPayload;
  final String fingerprint;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'challengeId': challengeId,
    'signingPayload': signingPayload,
    'fingerprint': fingerprint,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LocalServerChallenge.fromJson(Map<String, Object?> json) =>
      LocalServerChallenge(
        challengeId: _requiredString(json, 'challengeId'),
        signingPayload: _requiredString(json, 'signingPayload'),
        fingerprint: _requiredString(json, 'fingerprint'),
        expiresAt:
            DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
      );
}

class LocalServerSession {
  const LocalServerSession({
    required this.token,
    required this.tokenType,
    required this.clientId,
    required this.fingerprint,
    required this.scopes,
    this.deviceAllowlist = const [],
    required this.expiresAt,
  });

  final String token;
  final String tokenType;
  final String clientId;
  final String fingerprint;
  final Set<String> scopes;
  final List<String> deviceAllowlist;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'token': token,
    'tokenType': tokenType,
    'clientId': clientId,
    'fingerprint': fingerprint,
    'scopes': scopes.toList()..sort(),
    'deviceAllowlist': deviceAllowlist,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LocalServerSession.fromJson(Map<String, Object?> json) {
    final scopes = json['scopes'];
    final allowlist = json['deviceAllowlist'];
    return LocalServerSession(
      token: _requiredString(json, 'token'),
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      clientId: _requiredString(json, 'clientId'),
      fingerprint: _requiredString(json, 'fingerprint'),
      scopes: scopes is List
          ? scopes.map((v) => v.toString()).toSet()
          : const {},
      deviceAllowlist: allowlist is List
          ? allowlist.map((v) => v.toString()).toList()
          : const [],
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class LocalServerInstallRequest {
  const LocalServerInstallRequest({
    required this.fileName,
    required this.type,
    required this.sha256,
    required this.size,
    this.deviceId,
  });

  final String fileName;
  final String type;
  final String sha256;
  final int size;
  final String? deviceId;

  factory LocalServerInstallRequest.fromJson(Map<String, Object?> json) {
    final fileName = json['fileName']?.toString().trim() ?? '';
    final type = json['type']?.toString().trim() ?? '';
    final sha256 = json['sha256']?.toString().trim() ?? '';
    final size = json['size'];
    if (fileName.isEmpty || type.isEmpty || sha256.isEmpty || size is! num) {
      throw const FormatException(
        'fileName, type, sha256, and numeric size are required',
      );
    }
    if (size < 0 || size > 256 * 1024 * 1024) {
      throw const FormatException('Resource size is outside the allowed range');
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256)) {
      throw const FormatException('sha256 must be a 64-character hex string');
    }
    return LocalServerInstallRequest(
      fileName: fileName,
      type: type,
      sha256: sha256.toLowerCase(),
      size: size.toInt(),
      deviceId: json['deviceId']?.toString(),
    );
  }

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'type': type,
    'sha256': sha256,
    'size': size,
    if (deviceId != null) 'deviceId': deviceId,
  };
}

class LocalServerError {
  const LocalServerError(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };

  factory LocalServerError.fromJson(Map<String, Object?> json) =>
      LocalServerError(
        json['code']?.toString() ?? 'unknown',
        json['message']?.toString() ?? 'Unknown error',
        details: json['details'],
      );
}

class LocalServerOperation {
  LocalServerOperation({
    required this.id,
    required this.kind,
    required this.state,
    this.deviceId,
    this.stage,
    this.message,
    this.progress,
    this.bytesDone,
    this.bytesTotal,
    this.fileName,
    this.error,
    this.finishedAt,
  });

  final String id;
  final String kind;
  LocalServerOperationState state;
  final String? deviceId;
  String? stage;
  String? message;
  double? progress;
  int? bytesDone;
  int? bytesTotal;
  String? fileName;
  Map<String, Object?>? error;
  DateTime? finishedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'state': state.name,
    if (deviceId != null) 'deviceId': deviceId,
    if (stage != null) 'stage': stage,
    if (message != null) 'message': message,
    if (progress != null) 'progress': progress,
    if (bytesDone != null) 'bytesDone': bytesDone,
    if (bytesTotal != null) 'bytesTotal': bytesTotal,
    if (fileName != null) 'fileName': fileName,
    if (error != null) 'error': error,
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
  };
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('Missing $key');
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite) throw FormatException('Missing $key');
  return value.toInt();
}
