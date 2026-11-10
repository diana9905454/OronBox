class PluginExecutionFailure {
  const PluginExecutionFailure({
    required this.pluginId,
    required this.pluginName,
    required this.phase,
    required this.message,
    required this.occurredAt,
  });

  final String pluginId;
  final String pluginName;
  final String phase;
  final String message;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'pluginName': pluginName,
    'phase': phase,
    'message': message,
    'occurredAt': occurredAt.toIso8601String(),
  };
}

class PluginExecutionException implements Exception {
  const PluginExecutionException(this.pluginId, this.pluginName, this.message);

  factory PluginExecutionException.fromFailure(
    PluginExecutionFailure failure,
  ) => PluginExecutionException(
    failure.pluginId,
    failure.pluginName,
    failure.message,
  );

  final String pluginId;
  final String pluginName;
  final String message;

  @override
  String toString() => '$pluginName: $message';
}
