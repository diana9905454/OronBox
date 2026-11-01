import 'local_server_protocol.dart';

enum LocalServerStatus { stopped, starting, running, stopping, error }

class LocalServerState {
  const LocalServerState({
    this.status = LocalServerStatus.stopped,
    this.info,
    this.addresses = const [],
    this.pendingPairings = const [],
    this.authorizedClients = const [],
    this.error,
  });

  final LocalServerStatus status;
  final LocalServerInfo? info;
  final List<String> addresses;
  final List<LocalServerPairingRequest> pendingPairings;
  final List<LocalAuthorizedClient> authorizedClients;
  final String? error;

  bool get isRunning => status == LocalServerStatus.running;
  bool get isBusy =>
      status == LocalServerStatus.starting ||
      status == LocalServerStatus.stopping;

  LocalServerState copyWith({
    LocalServerStatus? status,
    LocalServerInfo? info,
    List<String>? addresses,
    List<LocalServerPairingRequest>? pendingPairings,
    List<LocalAuthorizedClient>? authorizedClients,
    String? error,
    bool clearInfo = false,
    bool clearError = false,
  }) {
    return LocalServerState(
      status: status ?? this.status,
      info: clearInfo ? null : info ?? this.info,
      addresses: addresses ?? this.addresses,
      pendingPairings: pendingPairings ?? this.pendingPairings,
      authorizedClients: authorizedClients ?? this.authorizedClients,
      error: clearError ? null : error ?? this.error,
    );
  }
}
