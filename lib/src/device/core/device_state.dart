/// Device connection and protocol lifecycle state.
enum ProtocolState {
  disconnected,
  connecting,
  connected,
  authenticating,
  ready,
  error,
}

/// Generic protocol or hardware communication failure.
class ProtocolException implements Exception {
  const ProtocolException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message (caused by $cause)';
}
