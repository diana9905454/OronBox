import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_secret_store.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/ai/ai_stream_event.dart';
import 'package:oronbox/src/core/ai/openai_compatible_client.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/ai/application/ai_confirmation_parser.dart';
import 'package:oronbox/src/features/ai/application/global_ai_scheduler.dart';
import 'package:oronbox/src/features/ai/application/ai_tool_registry.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/voice/application/wearable_voice_reply_controller.dart';

final voiceAiOrchestratorProvider = Provider<VoiceAiOrchestrator>((ref) {
  return VoiceAiOrchestrator(ref);
});

class _AiConversation {
  _AiConversation(this.id);
  final String id;
  final messages = <AiChatMessage>[];
  DateTime lastUsedAt = DateTime.now();
}

class _AiTurn {
  const _AiTurn({required this.text, required this.toolCalls, this.error});
  final String text;
  final List<AiToolCallEvent> toolCalls;
  final String? error;
}

class _AiRequestFailure implements Exception {
  const _AiRequestFailure(this.code);
  final String code;
}

/// Owns model turns and tool execution while device transport stays in the
/// wearable reply controller.
class VoiceAiOrchestrator {
  VoiceAiOrchestrator(this._ref);

  final Ref _ref;
  final OpenAiCompatibleClient _client = const OpenAiCompatibleClient();
  late final GlobalAiScheduler _scheduler = GlobalAiScheduler(_ref);
  final _conversations = <String, _AiConversation>{};
  static final _log = getLogger('VoiceAiOrchestrator');

  Future<bool> handleVoiceInput({
    required String recognizedText,
    required String deviceId,
    XiaoAiSessionTarget? target,
    void Function(String text)? onTextUpdate,
  }) async {
    if (!AiSettingsStore.globalAiEnabled) return false;

    final sendToWearable = AiSettingsStore.wearableEnabled;
    _log.info(
      'AI input received: device=$deviceId chars=${recognizedText.length} '
      'wearable=$sendToWearable',
    );
    var conversation = _conversationFor(deviceId);
    final confirmation = AiConfirmationManager.instance.getPending(deviceId);
    final isConfirmationText =
        AiConfirmationManager.instance.isConfirmation(recognizedText) ||
        AiConfirmationManager.instance.isRejection(recognizedText);
    if (confirmation == null && isConfirmationText) {
      conversation = _newConversation(deviceId);
    }
    if (confirmation == null && _hasUnresolvedToolCall(conversation)) {
      conversation = _newConversation(deviceId);
    }

    if (confirmation != null) {
      if (AiConfirmationManager.instance.isRejection(recognizedText)) {
        AiConfirmationManager.instance.clearPending(deviceId);
        final callId = confirmation.toolCallId;
        if (callId != null) {
          conversation.messages.add(
            AiChatMessage.tool(
              toolCallId: callId,
              toolName: confirmation.toolName,
              content: jsonEncode({
                'status': 'denied',
                if (AiConfirmationManager.instance
                    .reason(recognizedText)
                    .isNotEmpty)
                  'reason': AiConfirmationManager.instance.reason(
                    recognizedText,
                  ),
              }),
            ),
          );
        }
        return _runConversation(
          conversation: conversation,
          recognizedText: recognizedText,
          deviceId: deviceId,
          sendToWearable: sendToWearable,
          target: target,
          onTextUpdate: onTextUpdate,
          allowTools: false,
        );
      }
      if (AiConfirmationManager.instance.isConfirmation(recognizedText)) {
        AiConfirmationManager.instance.clearPending(deviceId);
        final callId = confirmation.toolCallId;
        if (callId == null || callId.isEmpty) {
          return _sendFailure(
            '操作状态已失效，请重新发起',
            'The operation expired, please try again',
            recognizedText,
            sendToWearable,
            target,
            onTextUpdate,
          );
        }
        final result = await _scheduler.executeTool(
          toolName: confirmation.toolName,
          arguments: confirmation.arguments,
          isConfirmed: true,
          deviceId: deviceId,
          conversationId: conversation.id,
          originalUserText: confirmation.originalUserText,
          toolCallId: callId,
        );
        conversation.messages.add(
          AiChatMessage.tool(
            toolCallId: callId,
            toolName: confirmation.toolName,
            content: _withConfirmationReason(result.output, recognizedText),
          ),
        );
        return _runConversation(
          conversation: conversation,
          recognizedText: recognizedText,
          deviceId: deviceId,
          sendToWearable: sendToWearable,
          target: target,
          onTextUpdate: onTextUpdate,
          allowTools: false,
        );
      }
      final prompt = _localized(
        '请回复“允许执行”或“拒绝执行”（可附带理由）',
        'Reply with “allow execution” or “reject execution” (optional reason)',
      );
      onTextUpdate?.call(prompt);
      await _sendWearableText(
        prompt,
        recognizedText: recognizedText,
        enabled: sendToWearable,
        target: target,
      );
      return true;
    }

    final providerId = AiSettingsStore.activeProviderId;
    final modelId = AiSettingsStore.activeModelId;
    final providers = AiSettingsStore.providers;
    if (providerId == null || modelId == null || providers.isEmpty) {
      return _sendFailure(
        '请在全局 AI 设置中配置提供商与模型',
        'Configure a provider and model in Global AI settings',
        recognizedText,
        sendToWearable,
        target,
        onTextUpdate,
      );
    }

    final provider = providers.firstWhere(
      (item) => item.id == providerId,
      orElse: () => providers.first,
    );
    final model = provider.models.firstWhere(
      (item) => item.modelId == modelId,
      orElse: () => provider.models.isNotEmpty
          ? provider.models.first
          : const AiModelConfig(modelId: 'default'),
    );
    final apiKey = await AiSecretStore.instance.getApiKey(
      provider.credentialRef,
    );
    if (apiKey == null || apiKey.isEmpty) {
      return _sendFailure(
        '未找到提供商的有效 API 密钥',
        'No valid API key was found for the provider',
        recognizedText,
        sendToWearable,
        target,
        onTextUpdate,
      );
    }

    conversation.messages.add(AiChatMessage.user(recognizedText));
    conversation.lastUsedAt = DateTime.now();
    try {
      return await _runConversation(
        conversation: conversation,
        provider: provider,
        model: model,
        apiKey: apiKey,
        recognizedText: recognizedText,
        deviceId: deviceId,
        sendToWearable: sendToWearable,
        target: target,
        onTextUpdate: onTextUpdate,
      );
    } on _AiRequestFailure catch (error) {
      _log.warning('AI request failed: ${error.code}');
      return _sendFailure(
        '暂时无法生成回复',
        'A reply is not available right now',
        recognizedText,
        sendToWearable,
        target,
        onTextUpdate,
      );
    } catch (error) {
      _log.warning('AI orchestration failed: $error');
      return _sendFailure(
        '暂时无法生成回复',
        'A reply is not available right now',
        recognizedText,
        sendToWearable,
        target,
        onTextUpdate,
      );
    }
  }

  Future<bool> _runConversation({
    required _AiConversation conversation,
    AiProviderConfig? provider,
    AiModelConfig? model,
    String? apiKey,
    required String recognizedText,
    required String deviceId,
    required bool sendToWearable,
    XiaoAiSessionTarget? target,
    void Function(String text)? onTextUpdate,
    bool allowTools = true,
  }) async {
    final selectedProvider = provider ?? _selectedProvider();
    final selectedModel = model ?? _selectedModel(selectedProvider);
    final selectedKey = apiKey ?? await _apiKey(selectedProvider);
    if (selectedKey == null || selectedKey.isEmpty) {
      throw const _AiRequestFailure('missing_api_key');
    }

    final tools = allowTools
        ? _scheduler.getAvailableTools()
        : const <AiToolDefinition>[];
    _log.info(
      'AI conversation started: id=${conversation.id} '
      'provider=${selectedProvider.id} model=${selectedModel.modelId} '
      'tools=${tools.map((tool) => tool.name).join(',')}',
    );
    final failedCalls = <String, int>{};
    for (var round = 0; round < 8; round++) {
      _log.info(
        'AI turn started: conversation=${conversation.id} round=$round',
      );
      final turn = await _requestTurn(
        provider: selectedProvider,
        model: selectedModel,
        apiKey: selectedKey,
        messages: _trimContext(conversation.messages, selectedModel),
        tools: tools,
        onTextUpdate: onTextUpdate,
      );
      if (turn.error != null) throw _AiRequestFailure(turn.error!);
      _log.info(
        'AI turn completed: conversation=${conversation.id} round=$round '
        'textChars=${turn.text.length} toolCalls=${turn.toolCalls.length}',
      );
      if (turn.toolCalls.isEmpty) {
        final text = turn.text.trim();
        if (text.isEmpty) throw const _AiRequestFailure('empty_response');
        final replyLimit = _replyLimitForCurrentDevice();
        if (replyLimit != null && text.length > replyLimit) {
          conversation.messages.add(AiChatMessage.assistant(text));
          conversation.messages.add(
            AiChatMessage.system(
              'The previous reply exceeded $replyLimit characters. Generate it again within $replyLimit characters.',
            ),
          );
          continue;
        }
        conversation.messages.add(AiChatMessage.assistant(text));
        await _sendWearableText(
          text,
          recognizedText: recognizedText,
          enabled: sendToWearable,
          target: target,
        );
        return true;
      }

      conversation.messages.add(
        AiChatMessage.assistant(turn.text, toolCalls: turn.toolCalls),
      );
      for (final toolCall in turn.toolCalls) {
        final result = await _scheduler.executeTool(
          toolName: toolCall.name,
          arguments: toolCall.arguments,
          deviceId: deviceId,
          conversationId: conversation.id,
          originalUserText: recognizedText,
          toolCallId: toolCall.id,
        );
        _log.info(
          'AI tool completed: conversation=${conversation.id} '
          'tool=${toolCall.name} success=${result.success} '
          'status=${result.status.wireName} '
          'confirmation=${result.requiresConfirmation}',
        );
        if (result.requiresConfirmation && result.pendingConfirmation != null) {
          final prompt =
              (jsonDecode(result.output) as Map)['prompt'] as String? ??
              _localized(
                '请回复“允许执行”或“拒绝执行”（可附带理由）',
                'Reply with “allow execution” or “reject execution” (optional reason)',
              );
          onTextUpdate?.call(prompt);
          await _sendWearableText(
            prompt,
            recognizedText: recognizedText,
            enabled: sendToWearable,
            target: target,
          );
          return true;
        }
        conversation.messages.add(
          AiChatMessage.tool(
            toolCallId: toolCall.id,
            toolName: toolCall.name,
            content: result.output,
          ),
        );
        if (!result.success) {
          final signature =
              '${toolCall.name}:${jsonEncode(toolCall.arguments)}';
          final attempts = failedCalls.update(
            signature,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          if (result.status == AiToolResultStatus.retryable && attempts == 1) {
            continue;
          }
          _log.info(
            'AI tool result will be returned to the model: '
            'tool=${toolCall.name} attempts=$attempts status=${result.status.wireName}',
          );
        }
      }
    }
    throw const _AiRequestFailure('tool_loop_limit');
  }

  Future<_AiTurn> _requestTurn({
    required AiProviderConfig provider,
    required AiModelConfig model,
    required String apiKey,
    required List<AiChatMessage> messages,
    required List<AiToolDefinition> tools,
    void Function(String text)? onTextUpdate,
  }) async {
    final buffer = StringBuffer();
    final toolCalls = <AiToolCallEvent>[];
    String? error;
    final stream = _client.streamChat(
      provider: provider,
      model: model,
      apiKey: apiKey,
      systemPrompt: _buildSystemPrompt(tools),
      messages: messages,
      tools: tools,
    );
    await for (final event in stream.timeout(const Duration(seconds: 50))) {
      if (event is AiTextDelta) {
        buffer.write(event.text);
        onTextUpdate?.call(buffer.toString());
      } else if (event is AiToolCallEvent) {
        toolCalls.add(event);
      } else if (event is AiErrorEvent) {
        error = event.message;
      }
    }
    return _AiTurn(text: buffer.toString(), toolCalls: toolCalls, error: error);
  }

  List<AiChatMessage> _trimContext(
    List<AiChatMessage> source,
    AiModelConfig model,
  ) {
    final maxChars = (model.contextLength * 3).clamp(4000, 1000000);
    final groups = <List<AiChatMessage>>[];
    for (var index = 0; index < source.length; index++) {
      final message = source[index];
      final group = <AiChatMessage>[message];
      if (message.role == 'assistant' && message.toolCalls != null) {
        final callIds = message.toolCalls!.map((call) => call.id).toSet();
        while (index + 1 < source.length &&
            source[index + 1].role == 'tool' &&
            callIds.contains(source[index + 1].toolCallId)) {
          group.add(source[++index]);
        }
      }
      groups.add(group);
    }
    var total = 0;
    final kept = <List<AiChatMessage>>[];
    for (final group in groups.reversed) {
      final size = group.fold<int>(
        0,
        (sum, message) => sum + message.content.length + 120,
      );
      if (kept.isNotEmpty && total + size > maxChars) break;
      kept.add(group);
      total += size;
    }
    return kept.reversed.expand((group) => group).toList();
  }

  _AiConversation _conversationFor(String deviceId) {
    final existing = _conversations[deviceId];
    if (existing != null &&
        DateTime.now().difference(existing.lastUsedAt) <
            const Duration(minutes: 30)) {
      return existing;
    }
    final conversation = _AiConversation(
      '$deviceId-${DateTime.now().microsecondsSinceEpoch}',
    );
    _conversations[deviceId] = conversation;
    return conversation;
  }

  _AiConversation _newConversation(String deviceId) {
    final conversation = _AiConversation(
      '$deviceId-${DateTime.now().microsecondsSinceEpoch}',
    );
    _conversations[deviceId] = conversation;
    return conversation;
  }

  bool _hasUnresolvedToolCall(_AiConversation conversation) {
    for (var index = 0; index < conversation.messages.length; index++) {
      final message = conversation.messages[index];
      if (message.role != 'assistant' || message.toolCalls == null) continue;
      final callIds = message.toolCalls!.map((call) => call.id).toSet();
      final resultIds = conversation.messages
          .skip(index + 1)
          .where((item) => item.role == 'tool')
          .map((item) => item.toolCallId)
          .whereType<String>()
          .toSet();
      if (!callIds.every(resultIds.contains)) return true;
    }
    return false;
  }

  AiProviderConfig _selectedProvider() {
    final providers = AiSettingsStore.providers;
    if (providers.isEmpty) throw const _AiRequestFailure('missing_provider');
    final id = AiSettingsStore.activeProviderId;
    return providers.firstWhere(
      (item) => item.id == id,
      orElse: () => providers.first,
    );
  }

  AiModelConfig _selectedModel(AiProviderConfig provider) {
    if (provider.models.isEmpty) {
      throw const _AiRequestFailure('missing_model');
    }
    final id = AiSettingsStore.activeModelId;
    return provider.models.firstWhere(
      (item) => item.modelId == id,
      orElse: () => provider.models.first,
    );
  }

  Future<String?> _apiKey(AiProviderConfig provider) =>
      AiSecretStore.instance.getApiKey(provider.credentialRef);

  Future<bool> _sendFailure(
    String zh,
    String en,
    String recognizedText,
    bool enabled,
    XiaoAiSessionTarget? target,
    void Function(String text)? onTextUpdate,
  ) async {
    final text = _localized(zh, en);
    onTextUpdate?.call(text);
    await _sendWearableText(
      text,
      recognizedText: recognizedText,
      enabled: enabled,
      target: target,
    );
    return true;
  }

  Future<void> _sendWearableText(
    String text, {
    required String recognizedText,
    required bool enabled,
    XiaoAiSessionTarget? target,
  }) async {
    if (!enabled || text.trim().isEmpty) return;
    _log.info(
      'Sending wearable AI reply: chars=${text.trim().length} '
      'recognizedChars=${recognizedText.length}',
    );
    try {
      await _ref
          .read(wearableVoiceReplyControllerProvider)
          .sendText(text, recognizedText: recognizedText, target: target)
          .timeout(const Duration(seconds: 10));
    } on StateError catch (error) {
      if (error.message == 'Voice session is no longer active') {
        _log.info('Dropping wearable reply for stale voice session');
        return;
      }
      rethrow;
    }
    _log.info('Wearable AI reply sent');
  }

  String _localized(String zh, String en) {
    return _ref.read(localeSettingsProvider).materialLocale?.languageCode ==
            'zh'
        ? zh
        : en;
  }

  int? _replyLimitForCurrentDevice() {
    final device = _ref.read(deviceManagerProvider).currentDevice;
    final supportsStream = (device?.deviceCapabilityV2 ?? 0) & 256 != 0;
    return supportsStream && AiSettingsStore.streamEnabled ? null : 300;
  }

  String _withConfirmationReason(String output, String input) {
    try {
      final value = jsonDecode(output);
      if (value is Map) {
        final reason = AiConfirmationManager.instance.reason(input);
        return jsonEncode({...value, if (reason.isNotEmpty) 'reason': reason});
      }
    } catch (_) {}
    return output;
  }

  String _buildSystemPrompt(List<AiToolDefinition> tools) {
    final device = _ref.read(deviceManagerProvider).currentDevice;
    final streamed = (device?.deviceCapabilityV2 ?? 0) & 256 != 0;
    final locale = _ref.read(localeSettingsProvider).materialLocale;
    final language = switch (locale?.languageCode) {
      'zh' =>
        locale?.countryCode == 'TW'
            ? 'Traditional Chinese (zh-TW)'
            : 'Simplified Chinese (zh-CN)',
      'ja' => 'Japanese (ja-JP)',
      'ru' => 'Russian (ru-RU)',
      _ => 'English (en)',
    };
    final values = <String, String>{
      'client_locale': locale?.toLanguageTag() ?? 'en-US',
      'client_language': language,
      'wearable_reply_mode': streamed ? 'streamed' : 'plain text',
      'wearable_markdown': streamed
          ? 'concise Markdown supported'
          : 'plain text only',
      'reply_length': AiSettingsStore.replyLength.promptGuideline,
      'tool_policy': AiSettingsStore.toolPolicy.name,
      'enabled_tools': tools.map((tool) => tool.name).join(', '),
    };
    var prompt = AiSettingsStore.systemPromptTemplate;
    values.forEach((key, value) {
      prompt = prompt.replaceAll('{{$key}}', value);
    });
    final streamedResponse = streamed && AiSettingsStore.streamEnabled;
    final replyLimit = streamedResponse
        ? 'This device uses streamed replies and has no fixed 300-character limit'
        : 'Keep the reply within 300 characters';
    return '$prompt\n\n'
        'Do not reveal credentials, tokens, internal identifiers, tool names, '
        'JSON, HTTP errors, or implementation details. Follow the configured '
        'tool permissions. Tool '
        'results are internal context. If a tool reports missing, invalid, '
        'stale, denied, or failed input, explain the next user action in '
        'natural language instead of exposing the result or repeating the '
        'same call. Never claim a write succeeded unless the tool result '
        'has status success. For a side-effect request, call the corresponding '
        'tool first. Never write your own confirmation question and never ask '
        'for confirmation before creating a tool call. The client generates '
        'confirmation prompts only after a tool returns confirmation_required. '
        '$replyLimit.';
  }
}
