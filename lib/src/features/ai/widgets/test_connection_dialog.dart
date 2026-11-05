import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_secret_store.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/ai/openai_compatible_client.dart';

class TestConnectionDialog extends StatefulWidget {
  const TestConnectionDialog({super.key});

  @override
  State<TestConnectionDialog> createState() => _TestConnectionDialogState();
}

class _TestConnectionDialogState extends State<TestConnectionDialog> {
  final _client = const OpenAiCompatibleClient();
  final _outputBuffer = StringBuffer();
  late final TextEditingController _requestController;
  bool _testing = false;
  bool? _success;
  int _elapsedMs = 0;
  String _statusText = '';
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _requestController = TextEditingController(
      text: OpenAiCompatibleClient.testPrompt,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _requestController.dispose();
    super.dispose();
  }

  void _cancelTest() {
    _sub?.cancel();
    _sub = null;
    if (mounted) {
      setState(() {
        _testing = false;
      });
    }
  }

  Future<void> _startTest() async {
    final l10n = AppLocalizations.of(context)!;
    final providers = AiSettingsStore.providers;
    final pId = AiSettingsStore.activeProviderId;
    final mId = AiSettingsStore.activeModelId;

    if (pId == null || mId == null || providers.isEmpty) {
      setState(() {
        _statusText = l10n.globalAiNoProviderConfigured;
        _success = false;
      });
      return;
    }

    final provider = providers.firstWhere(
      (p) => p.id == pId,
      orElse: () => providers.first,
    );
    final model = provider.models.firstWhere(
      (m) => m.modelId == mId,
      orElse: () => provider.models.isNotEmpty
          ? provider.models.first
          : const AiModelConfig(
              modelId: 'default',
              protocol: AiProtocolType.completions,
            ),
    );

    final apiKey = await AiSecretStore.instance.getApiKey(
      provider.credentialRef,
    );
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _statusText = l10n.globalAiNoApiKeyConfigured;
        _success = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _outputBuffer.clear();
      _success = null;
      _statusText = l10n.globalAiConnecting;
      _elapsedMs = 0;
    });

    final stopwatch = Stopwatch()..start();
    final prompt = _requestController.text.trim();

    try {
      final stream = _client.testConnection(
        provider: provider,
        model: model,
        apiKey: apiKey,
        prompt: prompt.isNotEmpty ? prompt : null,
      );

      _sub = stream.listen(
        (delta) {
          if (!mounted) return;
          setState(() {
            _outputBuffer.write(delta);
            _statusText = l10n.globalAiReceiving;
          });
        },
        onError: (e) {
          stopwatch.stop();
          if (!mounted) return;
          setState(() {
            _testing = false;
            _success = false;
            _elapsedMs = stopwatch.elapsedMilliseconds;
            _statusText = '${l10n.globalAiTestFailed} $e';
          });
        },
        onDone: () {
          stopwatch.stop();
          if (!mounted) return;
          setState(() {
            _testing = false;
            _success = true;
            _elapsedMs = stopwatch.elapsedMilliseconds;
            _statusText = l10n.globalAiTestSuccess;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _success = false;
        _elapsedMs = stopwatch.elapsedMilliseconds;
        _statusText = '${l10n.globalAiTestFailed} $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final pId = AiSettingsStore.activeProviderId;
    final mId = AiSettingsStore.activeModelId;
    final providers = AiSettingsStore.providers;
    final currentProvider = providers.where((p) => p.id == pId).firstOrNull;
    final currentModel = currentProvider?.models
        .where((m) => m.modelId == mId)
        .firstOrNull;

    final protocolText = currentModel != null
        ? (currentModel.protocol == AiProtocolType.responses
              ? 'Responses'
              : 'Completions')
        : '-';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.globalAiTestConnection,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.globalAiTargetLabel(
                  currentProvider?.name ?? '-',
                  '${mId ?? "-"} ($protocolText)',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // 1. 上文本区：请求输入框（无描边）
              Text(
                l10n.globalAiTestRequestLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _requestController,
                  minLines: 2,
                  maxLines: 4,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(10),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. 下文本区：响应内容（无描边）
              Text(
                l10n.globalAiTestResponseLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _outputBuffer.isEmpty
                          ? (_testing ? l10n.globalAiWaitingFirstToken : '')
                          : _outputBuffer.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              if (_statusText.isNotEmpty)
                Row(
                  children: [
                    if (_success == true)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      )
                    else if (_success == false)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      )
                    else if (_testing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _elapsedMs > 0
                            ? '$_statusText (${l10n.globalAiTestDuration(_elapsedMs)})'
                            : _statusText,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_testing)
                    TextButton(
                      onPressed: _cancelTest,
                      child: Text(l10n.globalAiCancel),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.globalAiClose),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _testing ? null : _startTest,
                    child: Text(
                      _testing
                          ? l10n.globalAiTesting
                          : (_success != null
                                ? l10n.globalAiRetry
                                : l10n.globalAiTestStart),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
