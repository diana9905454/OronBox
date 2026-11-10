import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';

class WearableAiSettingsDialog extends StatefulWidget {
  const WearableAiSettingsDialog({super.key});

  @override
  State<WearableAiSettingsDialog> createState() =>
      _WearableAiSettingsDialogState();
}

class _WearableAiSettingsDialogState extends State<WearableAiSettingsDialog> {
  late WearableReplyLength _replyLength;
  late AiToolPolicy _toolPolicy;
  late AiConfirmationMode _confirmMode;

  @override
  void initState() {
    super.initState();
    _replyLength = AiSettingsStore.replyLength;
    _toolPolicy = AiSettingsStore.toolPolicy;
    _confirmMode = AiSettingsStore.confirmationMode;
  }

  void _save() {
    AiSettingsStore.replyLength = _replyLength;
    AiSettingsStore.toolPolicy = _toolPolicy;
    AiSettingsStore.confirmationMode = _confirmMode;
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
                l10n.globalAiWearableAdvancedSettings,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. 回复长度
                      Text(
                        l10n.globalAiWearableReplyLength,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RadioGroup<WearableReplyLength>(
                        groupValue: _replyLength,
                        onChanged: (v) {
                          if (v != null) setState(() => _replyLength = v);
                        },
                        child: Column(
                          children: [
                            _buildRadioTile<WearableReplyLength>(
                              value: WearableReplyLength.short,
                              title: l10n.globalAiWearableLengthShort,
                              theme: theme,
                            ),
                            _buildRadioTile<WearableReplyLength>(
                              value: WearableReplyLength.medium,
                              title: l10n.globalAiWearableLengthMedium,
                              theme: theme,
                            ),
                            _buildRadioTile<WearableReplyLength>(
                              value: WearableReplyLength.long,
                              title: l10n.globalAiWearableLengthLong,
                              theme: theme,
                            ),
                            _buildRadioTile<WearableReplyLength>(
                              value: WearableReplyLength.unlimited,
                              title: l10n.globalAiWearableLengthUnlimited,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. 工具调用策略
                      Text(
                        l10n.globalAiWearableToolPolicy,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RadioGroup<AiToolPolicy>(
                        groupValue: _toolPolicy,
                        onChanged: (v) {
                          if (v != null) setState(() => _toolPolicy = v);
                        },
                        child: Column(
                          children: [
                            _buildRadioTile<AiToolPolicy>(
                              value: AiToolPolicy.disabled,
                              title: l10n.globalAiToolPolicyDisabled,
                              theme: theme,
                            ),
                            _buildRadioTile<AiToolPolicy>(
                              value: AiToolPolicy.readOnly,
                              title: l10n.globalAiToolPolicyReadOnly,
                              theme: theme,
                            ),
                            _buildRadioTile<AiToolPolicy>(
                              value: AiToolPolicy.readWrite,
                              title: l10n.globalAiToolPolicyReadWrite,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      // 3. 确认方式（工具调用为禁用时隐藏）
                      if (_toolPolicy != AiToolPolicy.disabled) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.globalAiConfirmationMode,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RadioGroup<AiConfirmationMode>(
                          groupValue: _confirmMode,
                          onChanged: (v) {
                            if (v != null) setState(() => _confirmMode = v);
                          },
                          child: Column(
                            children: [
                              _buildRadioTile<AiConfirmationMode>(
                                value: AiConfirmationMode.wearableVoice,
                                title: l10n.globalAiConfirmModeWearableVoice,
                                theme: theme,
                              ),
                              _buildRadioTile<AiConfirmationMode>(
                                value: AiConfirmationMode.clientManual,
                                title: l10n.globalAiConfirmModeManual,
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.globalAiCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n.globalAiSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile<T>({
    required T value,
    required String title,
    required ThemeData theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (value is WearableReplyLength) {
          setState(() => _replyLength = value as WearableReplyLength);
        } else if (value is AiToolPolicy) {
          setState(() => _toolPolicy = value as AiToolPolicy);
        } else if (value is AiConfirmationMode) {
          setState(() => _confirmMode = value as AiConfirmationMode);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Radio<T>(value: value),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
