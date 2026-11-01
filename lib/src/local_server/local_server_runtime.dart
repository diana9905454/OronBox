import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../commands/command_protocol.dart';
import '../core/logging/logging_service.dart';
import 'local_server.dart';
import 'local_server_auth.dart';
import 'local_server_protocol.dart';

class LocalServerIdentity {
  const LocalServerIdentity({required this.serverId, required this.keyPair});

  final String serverId;
  final LocalServerEd25519KeyPair keyPair;

  Map<String, Object?> toJson() => {
    'serverId': serverId,
    'keyPair': keyPair.toJson(),
  };

  factory LocalServerIdentity.fromJson(Map<String, Object?> json) {
    return LocalServerIdentity(
      serverId: json['serverId']?.toString() ?? '',
      keyPair: LocalServerEd25519KeyPair.fromJson(
        (json['keyPair'] as Map).cast<String, Object?>(),
      ),
    );
  }
}

class LocalServerIdentityStore {
  LocalServerIdentityStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<LocalServerIdentity> loadOrCreate() async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}local-server',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}identity.json',
    );
    if (await file.exists()) {
      try {
        final value = jsonDecode(await file.readAsString());
        if (value is Map) {
          final identity = LocalServerIdentity.fromJson(
            value.cast<String, Object?>(),
          );
          if (identity.serverId.isNotEmpty) return identity;
        }
      } catch (_) {}
    }

    final identity = LocalServerIdentity(
      serverId: _newServerId(),
      keyPair: LocalServerEd25519KeyPair.generate(),
    );
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(identity.toJson()), flush: true);
    await temporary.rename(file.path);
    return identity;
  }

  Future<List<LocalAuthorizedClient>> loadAuthorizedClients() async {
    final root = await _directoryProvider();
    final file = File(
      '${root.path}${Platform.pathSeparator}local-server${Platform.pathSeparator}authorized-clients.json',
    );
    if (!await file.exists()) return const [];
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! List) return const [];
      return [
        for (final item in value)
          if (item is Map)
            LocalAuthorizedClient.fromJson(item.cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAuthorizedClients(
    Iterable<LocalAuthorizedClient> clients,
  ) async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}local-server',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}authorized-clients.json',
    );
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(clients.map((c) => c.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}

class LocalServerRuntime {
  static final _log = getLogger('LocalServerRuntime');

  LocalServerRuntime({
    required this.commandBus,
    this.displayName = 'OronBox',
    this.platform = 'unknown',
    this.port = defaultLocalServerPort,
    LocalServerIdentityStore? identityStore,
    this.temporaryDirectoryProvider,
    this.onChanged,
    this.onPairingRequested,
  }) : _identityStore = identityStore ?? LocalServerIdentityStore();

  final OronBoxCommandBus commandBus;
  final String displayName;
  final String platform;
  final int port;
  final LocalServerIdentityStore _identityStore;
  final Future<Directory> Function()? temporaryDirectoryProvider;
  final void Function()? onChanged;
  final void Function(LocalServerPairingRequest pairing)? onPairingRequested;

  LocalServer? _server;
  Future<LocalServer>? _starting;
  Future<void> _authorizationSaveTail = Future<void>.value();

  LocalServer? get server => _server;

  List<LocalServerPairingRequest> get pendingPairings =>
      _server?.pendingPairings ?? const [];

  List<LocalAuthorizedClient> get authorizedClients =>
      _server?.authorizedClients ?? const [];

  Future<LocalServer> start() {
    final existing = _server;
    if (existing != null) return Future.value(existing);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<LocalServer> _start() async {
    final identity = await _identityStore.loadOrCreate();
    final authorized = await _identityStore.loadAuthorizedClients();
    late final LocalServer server;
    server = LocalServer(
      serverId: identity.serverId,
      displayName: displayName,
      platform: platform,
      identity: identity.keyPair,
      host: InternetAddress.anyIPv4,
      port: port,
      commandBus: commandBus,
      temporaryDirectoryProvider: temporaryDirectoryProvider,
      authorizedClients: authorized,
      onAuthorizationChanged: () => _queueSaveAuthorizedClients(server),
      onChanged: onChanged,
      onPairingRequested: onPairingRequested,
    );
    try {
      await server.start();
      _server = server;
      onChanged?.call();
      return server;
    } catch (error, stackTrace) {
      _log.severe('Local API Server startup failed', error, stackTrace);
      await server.stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    final starting = _starting;
    if (starting != null) {
      try {
        final server = await starting;
        await server.stop();
      } catch (_) {}
      _starting = null;
    }
    final server = _server;
    _server = null;
    if (server != null) {
      await server.stop();
    }
    onChanged?.call();
  }

  void approvePairing(String pairingId, {bool remember = true}) {
    _server?.approvePairing(pairingId, remember: remember);
  }

  void rejectPairing(String pairingId) {
    _server?.rejectPairing(pairingId);
  }

  void approveClient(LocalAuthorizedClient client) {
    _server?.approveClient(client);
  }

  void rejectClient(String fingerprint) {
    _server?.rejectClient(fingerprint);
  }

  void revokeClient(String fingerprint) {
    _server?.revokeClient(fingerprint);
  }

  void _queueSaveAuthorizedClients(LocalServer server) {
    final snapshot = server.authorizedClients;
    _authorizationSaveTail = _authorizationSaveTail.then(
      (_) => _identityStore.saveAuthorizedClients(snapshot),
    );
  }
}

String _newServerId() {
  final random = List<int>.generate(8, (_) => Random.secure().nextInt(256));
  final suffix = random
      .map((item) => item.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'oronbox-$suffix';
}
