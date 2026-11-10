import 'dart:convert';

import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';

import 'ai_models.dart';

enum WearableReplyLength {
  short,
  medium,
  long,
  unlimited;

  static WearableReplyLength fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'short':
        return WearableReplyLength.short;
      case 'long':
        return WearableReplyLength.long;
      case 'unlimited':
        return WearableReplyLength.unlimited;
      case 'medium':
      default:
        return WearableReplyLength.medium;
    }
  }

  String get promptGuideline {
    switch (this) {
      case WearableReplyLength.short:
        return 'Keep reply within 20 characters.';
      case WearableReplyLength.medium:
        return 'Keep reply around 50 characters.';
      case WearableReplyLength.long:
        return 'Keep reply around 100 characters.';
      case WearableReplyLength.unlimited:
        return 'Keep reply concise and structured.';
    }
  }
}

enum AiToolPolicy {
  disabled,
  readOnly,
  readWrite;

  static AiToolPolicy fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'disabled':
        return AiToolPolicy.disabled;
      case 'readwrite':
        return AiToolPolicy.readWrite;
      case 'readonly':
      default:
        return AiToolPolicy.readOnly;
    }
  }
}

enum AiConfirmationMode {
  wearableVoice,
  clientManual;

  static AiConfirmationMode fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'clientmanual':
        return AiConfirmationMode.clientManual;
      case 'wearablevoice':
      default:
        return AiConfirmationMode.wearableVoice;
    }
  }
}

class AiSettingsStore {
  static const _keyGlobalAiEnabled = 'global_ai_enabled';
  static const _keyStreamEnabled = 'global_ai_stream_enabled';
  static const _keyWearableEnabled = 'global_ai_wearable_enabled';
  static const _keyActiveProviderId = 'global_ai_active_provider_id';
  static const _keyActiveModelId = 'global_ai_active_model_id';
  static const _keyProviders = 'global_ai_providers_json';

  static const _keyReplyLength = 'global_ai_reply_length';
  static const _keyToolPolicy = 'global_ai_tool_policy';
  static const _keyConfirmMode = 'global_ai_confirm_mode';

  static const _keyToolDeviceStatus = 'global_ai_tool_device_status';
  static const _keyToolHealthData = 'global_ai_tool_health_data';
  static const _keyToolWeather = 'global_ai_tool_weather';
  static const _keyToolSearchResources = 'global_ai_tool_search_resources';
  static const _keyToolInstallResources = 'global_ai_tool_install_resources';
  static const _keyToolDeleteResources = 'global_ai_tool_delete_resources';
  static const _keyToolManageAlarms = 'global_ai_tool_manage_alarms';
  static const _keyToolFindDevice = 'global_ai_tool_find_device';
  static const _keyToolAppArrangement = 'global_ai_tool_app_arrangement';
  static const _keyToolPhoneLocation = 'global_ai_tool_phone_location';
  static const _keyAsrBackend = 'global_ai_asr_backend';
  static const _keySystemPromptTemplate = 'global_ai_system_prompt_template';

  static const defaultSystemPromptTemplate =
      '''You are OronBox's wearable assistant.
The response receiver is a wearable device.
Reply in {{client_language}}.
Keep the response within the configured length.
{{wearable_markdown}}
Do not expose tool names, JSON, internal fields, HTTP errors, or implementation details.
Use the available tools directly when they match the user's request.''';

  static final _prefs = SharedPrefsService.instance;

  static bool get globalAiEnabled =>
      _prefs.getBool(_keyGlobalAiEnabled) ?? false;
  static set globalAiEnabled(bool v) => _prefs.setBool(_keyGlobalAiEnabled, v);

  static bool get streamEnabled => _prefs.getBool(_keyStreamEnabled) ?? true;
  static set streamEnabled(bool v) => _prefs.setBool(_keyStreamEnabled, v);

  static bool get wearableEnabled =>
      _prefs.getBool(_keyWearableEnabled) ?? true;
  static set wearableEnabled(bool v) => _prefs.setBool(_keyWearableEnabled, v);

  static String? get activeProviderId => _prefs.getString(_keyActiveProviderId);
  static set activeProviderId(String? v) {
    if (v == null) {
      _prefs.remove(_keyActiveProviderId);
    } else {
      _prefs.setString(_keyActiveProviderId, v);
    }
  }

  static String? get activeModelId => _prefs.getString(_keyActiveModelId);
  static set activeModelId(String? v) {
    if (v == null) {
      _prefs.remove(_keyActiveModelId);
    } else {
      _prefs.setString(_keyActiveModelId, v);
    }
  }

  static WearableReplyLength get replyLength =>
      WearableReplyLength.fromString(_prefs.getString(_keyReplyLength));
  static set replyLength(WearableReplyLength v) =>
      _prefs.setString(_keyReplyLength, v.name);

  static AiToolPolicy get toolPolicy =>
      AiToolPolicy.fromString(_prefs.getString(_keyToolPolicy));
  static set toolPolicy(AiToolPolicy v) =>
      _prefs.setString(_keyToolPolicy, v.name);

  static AiConfirmationMode get confirmationMode =>
      AiConfirmationMode.fromString(_prefs.getString(_keyConfirmMode));
  static set confirmationMode(AiConfirmationMode v) =>
      _prefs.setString(_keyConfirmMode, v.name);

  static AsrBackend get asrBackend {
    String? raw;
    try {
      raw = _prefs.getString(_keyAsrBackend);
    } on StateError {
      return AsrBackend.wetype;
    }
    if (raw == null) {
      return AsrBackend.wetype;
    }
    for (final b in AsrBackend.values) {
      if (b.name == raw) return b;
    }
    return AsrBackend.wetype;
  }

  static set asrBackend(AsrBackend v) =>
      _prefs.setString(_keyAsrBackend, v.name);

  static String get systemPromptTemplate =>
      _prefs.getString(_keySystemPromptTemplate) ?? defaultSystemPromptTemplate;

  static set systemPromptTemplate(String value) =>
      _prefs.setString(_keySystemPromptTemplate, value);

  // Tools scope
  static bool get toolDeviceStatus =>
      _prefs.getBool(_keyToolDeviceStatus) ?? true;
  static set toolDeviceStatus(bool v) =>
      _prefs.setBool(_keyToolDeviceStatus, v);

  static bool get toolHealthData => _prefs.getBool(_keyToolHealthData) ?? true;
  static set toolHealthData(bool v) => _prefs.setBool(_keyToolHealthData, v);

  static bool get toolWeather => _prefs.getBool(_keyToolWeather) ?? true;
  static set toolWeather(bool v) => _prefs.setBool(_keyToolWeather, v);

  static bool get toolSearchResources =>
      _prefs.getBool(_keyToolSearchResources) ?? true;
  static set toolSearchResources(bool v) =>
      _prefs.setBool(_keyToolSearchResources, v);

  static bool get toolInstallResources =>
      _prefs.getBool(_keyToolInstallResources) ?? false;
  static set toolInstallResources(bool v) =>
      _prefs.setBool(_keyToolInstallResources, v);

  static bool get toolDeleteResources =>
      _prefs.getBool(_keyToolDeleteResources) ?? false;
  static set toolDeleteResources(bool v) =>
      _prefs.setBool(_keyToolDeleteResources, v);

  static bool get toolManageAlarms =>
      _prefs.getBool(_keyToolManageAlarms) ?? true;
  static set toolManageAlarms(bool v) =>
      _prefs.setBool(_keyToolManageAlarms, v);

  static bool get toolFindDevice => _prefs.getBool(_keyToolFindDevice) ?? true;
  static set toolFindDevice(bool v) => _prefs.setBool(_keyToolFindDevice, v);

  static bool get toolAppArrangement =>
      _prefs.getBool(_keyToolAppArrangement) ?? false;
  static set toolAppArrangement(bool v) =>
      _prefs.setBool(_keyToolAppArrangement, v);

  static bool get toolPhoneLocation =>
      _prefs.getBool(_keyToolPhoneLocation) ?? false;
  static set toolPhoneLocation(bool v) =>
      _prefs.setBool(_keyToolPhoneLocation, v);

  // Providers list
  static List<AiProviderConfig> get providers {
    final raw = _prefs.getString(_keyProviders);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AiProviderConfig.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static set providers(List<AiProviderConfig> list) {
    final encoded = jsonEncode(list.map((p) => p.toJson()).toList());
    _prefs.setString(_keyProviders, encoded);
  }

  static AiProviderConfig? get activeProvider {
    final list = providers;
    final id = activeProviderId;
    if (id == null) return list.isNotEmpty ? list.first : null;
    return list.cast<AiProviderConfig?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => list.isNotEmpty ? list.first : null,
    );
  }

  static AiModelConfig? get activeModel {
    final provider = activeProvider;
    if (provider == null || provider.models.isEmpty) return null;
    final mid = activeModelId;
    if (mid == null) return provider.models.first;
    return provider.models.cast<AiModelConfig?>().firstWhere(
      (m) => m?.modelId == mid,
      orElse: () => provider.models.first,
    );
  }
}
