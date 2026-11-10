import 'dart:async';
import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

import 'ai_models.dart';
import 'ai_stream_event.dart';

/// 统一的 AI 消息结构
class AiChatMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String content;
  final String? toolCallId;
  final String? toolName;
  final List<AiToolCallEvent>? toolCalls;

  const AiChatMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolName,
    this.toolCalls,
  });

  factory AiChatMessage.system(String content) =>
      AiChatMessage(role: 'system', content: content);

  factory AiChatMessage.user(String content) =>
      AiChatMessage(role: 'user', content: content);

  factory AiChatMessage.assistant(
    String content, {
    List<AiToolCallEvent>? toolCalls,
  }) =>
      AiChatMessage(role: 'assistant', content: content, toolCalls: toolCalls);

  factory AiChatMessage.tool({
    required String toolCallId,
    required String toolName,
    required String content,
  }) => AiChatMessage(
    role: 'tool',
    content: content,
    toolCallId: toolCallId,
    toolName: toolName,
  );
}

/// 统一的工具定义结构
class AiToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AiToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const {},
  });
}

/// 基于 openai_dart 的统一兼容请求客户端
class OpenAiCompatibleClient {
  const OpenAiCompatibleClient();

  /// 获取配置好的 OpenAIClient 实例
  OpenAIClient _buildClient({required String baseUrl, required String apiKey}) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final config = OpenAIConfig(
      baseUrl: url,
      authProvider: ApiKeyProvider(apiKey),
      timeout: const Duration(seconds: 45),
      connectTimeout: const Duration(seconds: 15),
    );

    return OpenAIClient(config: config);
  }

  /// 发起统一流式请求
  Stream<AiStreamEvent> streamChat({
    required AiProviderConfig provider,
    required AiModelConfig model,
    required String apiKey,
    required List<AiChatMessage> messages,
    List<AiToolDefinition>? tools,
    String? systemPrompt,
  }) async* {
    final client = _buildClient(baseUrl: provider.baseUrl, apiKey: apiKey);

    try {
      if (model.protocol == AiProtocolType.responses) {
        yield* _streamResponses(
          client: client,
          model: model,
          messages: messages,
          tools: tools,
          systemPrompt: systemPrompt,
        );
      } else {
        yield* _streamCompletions(
          client: client,
          model: model,
          messages: messages,
          tools: tools,
          systemPrompt: systemPrompt,
        );
      }
    } catch (e) {
      yield AiErrorEvent(e.toString());
    } finally {
      client.close();
    }
  }

  /// completions 流式分支
  Stream<AiStreamEvent> _streamCompletions({
    required OpenAIClient client,
    required AiModelConfig model,
    required List<AiChatMessage> messages,
    List<AiToolDefinition>? tools,
    String? systemPrompt,
  }) async* {
    final chatMessages = <ChatMessage>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      chatMessages.add(ChatMessage.system(systemPrompt));
    }

    for (final m in messages) {
      if (m.role == 'user') {
        chatMessages.add(ChatMessage.user(m.content));
      } else if (m.role == 'assistant') {
        final toolCalls = m.toolCalls?.map((tc) {
          return ToolCall.functionCall(
            id: tc.id,
            call: FunctionCall.fromMap(name: tc.name, arguments: tc.arguments),
          );
        }).toList();
        chatMessages.add(
          ChatMessage.assistant(
            content: m.content.isEmpty && (toolCalls?.isNotEmpty ?? false)
                ? null
                : m.content,
            toolCalls: toolCalls?.isNotEmpty == true ? toolCalls : null,
          ),
        );
      } else if (m.role == 'system') {
        chatMessages.add(ChatMessage.system(m.content));
      } else if (m.role == 'tool') {
        chatMessages.add(
          ChatMessage.tool(toolCallId: m.toolCallId ?? '', content: m.content),
        );
      }
    }

    List<Tool>? toolDefs;
    if (tools != null && tools.isNotEmpty) {
      toolDefs = tools.map((t) {
        return Tool.function(
          name: t.name,
          description: t.description,
          parameters: t.parameters.isEmpty ? null : t.parameters,
        );
      }).toList();
    }

    final request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: chatMessages,
      tools: toolDefs,
    );

    final accumulator = ChatStreamAccumulator();
    final stream = client.chat.completions.createStream(request);

    final fullText = StringBuffer();

    await for (final event in stream) {
      accumulator.add(event);
      final delta = event.textDelta;
      if (delta != null && delta.isNotEmpty) {
        fullText.write(delta);
        yield AiTextDelta(delta);
      }
    }

    // 检查是否有 tool call
    final toolCalls = accumulator.toolCalls;
    if (toolCalls.isNotEmpty) {
      for (final tc in toolCalls) {
        Map<String, dynamic> parsedArgs = {};
        try {
          parsedArgs =
              jsonDecode(tc.function.arguments) as Map<String, dynamic>;
        } catch (_) {}

        yield AiToolCallEvent(
          id: tc.id,
          name: tc.function.name,
          arguments: parsedArgs,
        );
      }
    }

    yield AiDoneEvent(fullText: fullText.toString());
  }

  /// responses 流式分支
  Stream<AiStreamEvent> _streamResponses({
    required OpenAIClient client,
    required AiModelConfig model,
    required List<AiChatMessage> messages,
    List<AiToolDefinition>? tools,
    String? systemPrompt,
  }) async* {
    List<ResponseTool>? toolDefs;
    if (tools != null && tools.isNotEmpty) {
      toolDefs = tools.map((t) {
        return FunctionTool(
          name: t.name,
          description: t.description,
          parameters: t.parameters.isEmpty ? null : t.parameters,
        );
      }).toList();
    }

    final inputItems = <Item>[];
    for (final m in messages) {
      if (m.role == 'user') {
        inputItems.add(MessageItem.userText(m.content));
      } else if (m.role == 'assistant') {
        inputItems.add(MessageItem.assistantText(m.content));
        for (final toolCall in m.toolCalls ?? const <AiToolCallEvent>[]) {
          inputItems.add(
            FunctionCallItem(
              callId: toolCall.id,
              name: toolCall.name,
              arguments: jsonEncode(toolCall.arguments),
            ),
          );
        }
      } else if (m.role == 'system') {
        inputItems.add(MessageItem.systemText(m.content));
      } else if (m.role == 'tool') {
        inputItems.add(
          FunctionCallOutputItem.string(
            callId: m.toolCallId ?? '',
            output: m.content,
          ),
        );
      }
    }

    final request = CreateResponseRequest(
      model: model.modelId,
      instructions: systemPrompt,
      input: ResponseInput.items(inputItems),
      tools: toolDefs,
    );

    final stream = client.responses.createStream(request);
    final toolCallAccumulator = <String, _AccumulatedFunctionCall>{};
    final fullText = StringBuffer();

    await for (final event in stream) {
      if (event is OutputTextDeltaEvent) {
        fullText.write(event.delta);
        yield AiTextDelta(event.delta);
      } else if (event is OutputItemAddedEvent) {
        final item = event.item;
        if (item is FunctionCallOutputItemResponse) {
          toolCallAccumulator[item.callId] = _AccumulatedFunctionCall(
            id: item.callId,
            name: item.name,
            arguments: StringBuffer(item.arguments),
          );
        }
      } else if (event is FunctionCallArgumentsDeltaEvent) {
        final callId = event.itemId ?? '';
        final entry = toolCallAccumulator[callId];
        if (entry != null) {
          entry.arguments.write(event.delta);
        }
      } else if (event is FunctionCallArgumentsDoneEvent) {
        final callId = event.itemId ?? '';
        final entry = toolCallAccumulator[callId];
        if (entry != null && event.arguments.isNotEmpty) {
          entry.arguments.clear();
          entry.arguments.write(event.arguments);
        }
      } else if (event is ResponseFailedEvent) {
        yield AiErrorEvent('Response failed: ${event.response.id}');
      }
    }

    for (final tc in toolCallAccumulator.values) {
      Map<String, dynamic> parsedArgs = {};
      try {
        parsedArgs =
            jsonDecode(tc.arguments.toString()) as Map<String, dynamic>;
      } catch (_) {}

      yield AiToolCallEvent(id: tc.id, name: tc.name, arguments: parsedArgs);
    }

    yield AiDoneEvent(fullText: fullText.toString());
  }

  /// 轻量连通性测试输入提示词
  static const String testPrompt = 'Hello\nPlease reply with OK only';

  /// 轻量连通性测试
  Stream<String> testConnection({
    required AiProviderConfig provider,
    required AiModelConfig model,
    required String apiKey,
    String? prompt,
  }) async* {
    final client = _buildClient(baseUrl: provider.baseUrl, apiKey: apiKey);
    final text = (prompt != null && prompt.trim().isNotEmpty)
        ? prompt.trim()
        : testPrompt;

    try {
      if (model.protocol == AiProtocolType.responses) {
        final request = CreateResponseRequest(
          model: model.modelId,
          input: ResponseInput.text(text),
        );
        final stream = client.responses.createStream(request);
        await for (final event in stream) {
          if (event is OutputTextDeltaEvent) {
            yield event.delta;
          }
        }
      } else {
        final request = ChatCompletionCreateRequest(
          model: model.modelId,
          messages: [ChatMessage.user(text)],
        );
        final stream = client.chat.completions.createStream(request);
        await for (final event in stream) {
          final delta = event.textDelta;
          if (delta != null && delta.isNotEmpty) {
            yield delta;
          }
        }
      }
    } finally {
      client.close();
    }
  }
}

class _AccumulatedFunctionCall {
  final String id;
  final String name;
  final StringBuffer arguments;

  _AccumulatedFunctionCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}
