enum AiProtocolType {
  completions,
  responses;

  static AiProtocolType fromString(String? val) {
    if (val?.toLowerCase() == 'responses') return AiProtocolType.responses;
    return AiProtocolType.completions;
  }
}

class AiModelConfig {
  const AiModelConfig({
    required this.modelId,
    this.protocol = AiProtocolType.completions,
    this.supportImages = false,
    this.supportAudio = false,
    this.contextLength = 4096,
  });

  final String modelId;
  final AiProtocolType protocol;
  final bool supportImages;
  final bool supportAudio;
  final int contextLength;

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'protocol': protocol.name,
    'supportImages': supportImages,
    'supportAudio': supportAudio,
    'contextLength': contextLength,
  };

  factory AiModelConfig.fromJson(Map<String, dynamic> json) => AiModelConfig(
    modelId: json['modelId'] as String? ?? '',
    protocol: AiProtocolType.fromString(json['protocol'] as String?),
    supportImages: json['supportImages'] as bool? ?? false,
    supportAudio: json['supportAudio'] as bool? ?? false,
    contextLength: (json['contextLength'] as num?)?.toInt() ?? 4096,
  );

  AiModelConfig copyWith({
    String? modelId,
    AiProtocolType? protocol,
    bool? supportImages,
    bool? supportAudio,
    int? contextLength,
  }) => AiModelConfig(
    modelId: modelId ?? this.modelId,
    protocol: protocol ?? this.protocol,
    supportImages: supportImages ?? this.supportImages,
    supportAudio: supportAudio ?? this.supportAudio,
    contextLength: contextLength ?? this.contextLength,
  );
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.credentialRef,
    this.models = const [],
  });

  final String id;
  final String name;
  final String baseUrl;
  final String credentialRef;
  final List<AiModelConfig> models;

  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'credentialRef': credentialRef,
    'models': models.map((m) => m.toJson()).toList(),
  };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'] as List<dynamic>? ?? const [];
    return AiProviderConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      credentialRef: json['credentialRef'] as String? ?? '',
      models: rawModels
          .whereType<Map<String, dynamic>>()
          .map(AiModelConfig.fromJson)
          .toList(),
    );
  }

  AiProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? credentialRef,
    List<AiModelConfig>? models,
  }) => AiProviderConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    credentialRef: credentialRef ?? this.credentialRef,
    models: models ?? this.models,
  );
}
