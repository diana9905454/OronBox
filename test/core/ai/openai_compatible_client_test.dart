import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/ai/ai_stream_event.dart';
import 'package:oronbox/src/core/ai/openai_compatible_client.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OpenAiCompatibleClient and Models Test', () {
    test('AiChatMessage factories and properties', () {
      final sys = AiChatMessage.system('sys prompt');
      expect(sys.role, 'system');
      expect(sys.content, 'sys prompt');

      final user = AiChatMessage.user('hello');
      expect(user.role, 'user');
      expect(user.content, 'hello');

      final assistant = AiChatMessage.assistant('hi there');
      expect(assistant.role, 'assistant');
      expect(assistant.content, 'hi there');

      final assistantWithTools = AiChatMessage.assistant(
        'checking',
        toolCalls: [
          const AiToolCallEvent(
            id: 'call_1',
            name: 'tool_a',
            arguments: {'x': 1},
          ),
        ],
      );
      expect(assistantWithTools.content, 'checking');
      expect(assistantWithTools.toolCalls?.length, 1);
      expect(assistantWithTools.toolCalls?.first.id, 'call_1');

      final tool = AiChatMessage.tool(
        toolCallId: 'call_123',
        toolName: 'get_battery',
        content: '{"battery": 80}',
      );
      expect(tool.role, 'tool');
      expect(tool.toolCallId, 'call_123');
      expect(tool.toolName, 'get_battery');
      expect(tool.content, '{"battery": 80}');
    });

    test('AiStreamEvent sub-classes', () {
      const delta = AiTextDelta('test chunk');
      expect(delta.text, 'test chunk');

      const toolCall = AiToolCallEvent(
        id: 'c1',
        name: 'test_tool',
        arguments: {'query': 'abc'},
      );
      expect(toolCall.id, 'c1');
      expect(toolCall.name, 'test_tool');
      expect(toolCall.arguments['query'], 'abc');

      const done = AiDoneEvent(fullText: 'hello world');
      expect(done.fullText, 'hello world');

      const error = AiErrorEvent('some error');
      expect(error.message, 'some error');
    });

    test('AiModelConfig and AiProviderConfig json serialization', () {
      const model = AiModelConfig(
        modelId: 'gpt-4o',
        protocol: AiProtocolType.completions,
        supportImages: true,
        supportAudio: false,
        contextLength: 128000,
      );

      final modelJson = model.toJson();
      expect(modelJson['modelId'], 'gpt-4o');
      expect(modelJson['protocol'], 'completions');

      final restoredModel = AiModelConfig.fromJson(modelJson);
      expect(restoredModel.modelId, 'gpt-4o');
      expect(restoredModel.protocol, AiProtocolType.completions);
      expect(restoredModel.supportImages, isTrue);

      const provider = AiProviderConfig(
        id: 'p1',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        credentialRef: 'cred_1',
        models: [model],
      );

      final providerJson = provider.toJson();
      final restoredProvider = AiProviderConfig.fromJson(providerJson);
      expect(restoredProvider.id, 'p1');
      expect(restoredProvider.name, 'OpenAI');
      expect(restoredProvider.models.length, 1);
      expect(restoredProvider.models.first.modelId, 'gpt-4o');
      expect(restoredProvider.models.first.contextLength, 128000);
    });

    test(
      'OpenAiCompatibleClient testPrompt adheres strictly to specification',
      () {
        expect(
          OpenAiCompatibleClient.testPrompt,
          'Hello\nPlease reply with OK only',
        );
      },
    );

    test('AiModelConfig copyWith updates fields correctly', () {
      const original = AiModelConfig(
        modelId: 'gpt-4o',
        protocol: AiProtocolType.completions,
        supportImages: false,
        supportAudio: false,
        contextLength: 4096,
      );

      final updated = original.copyWith(
        modelId: 'qwen3.8-flash',
        protocol: AiProtocolType.responses,
        supportImages: true,
        supportAudio: true,
        contextLength: 200000,
      );

      expect(updated.modelId, 'qwen3.8-flash');
      expect(updated.protocol, AiProtocolType.responses);
      expect(updated.supportImages, isTrue);
      expect(updated.supportAudio, isTrue);
      expect(updated.contextLength, 200000);
    });

    test(
      'AiSettingsStore asrBackend defaults to wetype and persists updates',
      () async {
        SharedPreferences.setMockInitialValues({});
        await SharedPrefsService.instance.init();

        expect(AiSettingsStore.asrBackend, AsrBackend.wetype);

        AiSettingsStore.asrBackend = AsrBackend.doubao;
        expect(AiSettingsStore.asrBackend, AsrBackend.doubao);

        AiSettingsStore.asrBackend = AsrBackend.native;
        expect(AiSettingsStore.asrBackend, AsrBackend.native);
      },
    );
  });
}
