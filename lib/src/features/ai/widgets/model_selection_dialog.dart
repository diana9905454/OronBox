import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';

class ModelSelectionDialog extends StatefulWidget {
  const ModelSelectionDialog({super.key});

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  late String? _selectedProviderId;
  late String? _selectedModelId;
  late List<AiProviderConfig> _providers;

  @override
  void initState() {
    super.initState();
    _providers = AiSettingsStore.providers;
    _selectedProviderId = AiSettingsStore.activeProviderId;
    _selectedModelId = AiSettingsStore.activeModelId;
  }

  void _onSelect(String providerId, String modelId) {
    setState(() {
      _selectedProviderId = providerId;
      _selectedModelId = modelId;
    });
    AiSettingsStore.activeProviderId = providerId;
    AiSettingsStore.activeModelId = modelId;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.globalAiSelectActiveModel,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_providers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      l10n.globalAiNoModelsPrompt,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _providers.length,
                    itemBuilder: (context, pIdx) {
                      final p = _providers[pIdx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              p.name,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...p.models.map((m) {
                            final isSelected =
                                _selectedProviderId == p.id &&
                                _selectedModelId == m.modelId;
                            final imagesText = m.supportImages
                                ? ' · ${l10n.globalAiSupportImages}'
                                : '';
                            final audioText = m.supportAudio
                                ? ' · ${l10n.globalAiSupportAudio}'
                                : '';
                            final protocolLabel =
                                m.protocol == AiProtocolType.responses
                                ? 'Responses'
                                : 'Completions';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.4)
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                title: Text(
                                  m.modelId,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '$protocolLabel · ${l10n.globalAiContextLength} ${m.contextLength}$imagesText$audioText',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: theme.colorScheme.primary,
                                      )
                                    : null,
                                onTap: () => _onSelect(p.id, m.modelId),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.globalAiCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
