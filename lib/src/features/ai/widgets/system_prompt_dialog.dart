import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';

class SystemPromptDialog extends StatefulWidget {
  const SystemPromptDialog({super.key});

  @override
  State<SystemPromptDialog> createState() => _SystemPromptDialogState();
}

class _SystemPromptDialogState extends State<SystemPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: AiSettingsStore.systemPromptTemplate,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    AiSettingsStore.systemPromptTemplate = value;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.globalAiSystemPrompt),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.globalAiSystemPromptDescription),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 10,
                maxLines: 18,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.globalAiSystemPromptHint,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.globalAiSystemPromptPlaceholders),
              const SizedBox(height: 4),
              const SelectableText(
                '{{client_locale}}  {{client_language}}  '
                '{{wearable_reply_mode}}  {{wearable_markdown}}  '
                '{{reply_length}}  {{tool_policy}}  {{enabled_tools}}',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
