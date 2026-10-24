import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/features/voice/application/voice_recognition_controller.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

class VoiceRecognitionControls extends ConsumerStatefulWidget {
  const VoiceRecognitionControls({super.key});
  @override
  ConsumerState<VoiceRecognitionControls> createState() =>
      _VoiceRecognitionControlsState();
}

class _VoiceRecognitionControlsState
    extends ConsumerState<VoiceRecognitionControls> {
  final _accepted = <AsrBackend>{};
  Future<void> _select(AsrBackend backend) async {
    final l10n = AppLocalizations.of(context)!;
    if ((backend == AsrBackend.wetype || backend == AsrBackend.doubao) &&
        !_accepted.contains(backend)) {
      final provider = backend == AsrBackend.wetype
          ? l10n.voiceAsrWeType
          : l10n.voiceAsrDoubao;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(provider),
          content: Text(l10n.voiceAsrCloudConsent(provider)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.agree),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _accepted.add(backend);
    }
    await ref.read(voiceRecognitionProvider.notifier).select(backend);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voiceRecognitionProvider);
    final controller = ref.read(voiceRecognitionProvider.notifier);
    final local =
        state.backend == AsrBackend.native || state.backend == AsrBackend.wasm;
    final busy =
        state.running ||
        state.preparing ||
        state.downloadProgress != null ||
        ref.watch(deviceManagerProvider.select((state) => state.xiaoAiActive));
    final options = {
      AsrBackend.manual: l10n.voiceAsrManual,
      if (!kIsWeb) AsrBackend.native: l10n.voiceAsrLocal,
      AsrBackend.wetype: l10n.voiceAsrWeType,
      if (!kIsWeb) AsrBackend.doubao: l10n.voiceAsrDoubao,
      if (kIsWeb) AsrBackend.wasm: l10n.voiceAsrWasm,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<AsrBackend>(
          key: ValueKey(state.backend),
          initialValue: state.backend,
          decoration: InputDecoration(
            labelText: l10n.voiceAsrMethod,
            filled: true,
          ),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) _select(value);
                },
        ),
        if (state.backend == AsrBackend.wetype ||
            state.backend == AsrBackend.doubao)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.voiceAsrReconnect),
                          content: Text(l10n.voiceAsrReconnectDescription),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.creatorConfirm),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await controller.resetCloudIdentity();
                      }
                    },
              child: Text(l10n.voiceAsrReconnect),
            ),
          ),
        if (local) ...[
          const SizedBox(height: 12),
          Text(
            state.modelInstalled
                ? l10n.voiceAsrModelReady
                : l10n.voiceAsrModelDescription,
          ),
          const SizedBox(height: 8),
          if (state.downloadProgress != null) ...[
            LinearProgressIndicator(value: state.downloadProgress),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.cancelDownload,
                child: Text(l10n.cancel),
              ),
            ),
          ] else
            Wrap(
              spacing: 8,
              children: [
                if (!state.modelInstalled)
                  FilledButton.tonalIcon(
                    onPressed: state.running || state.preparing
                        ? null
                        : controller.downloadModel,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.voiceAsrDownloadModel),
                  ),
                if (state.modelInstalled)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(l10n.voiceAsrDeleteModel),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await controller.removeModel();
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.voiceAsrDeleteModel),
                  ),
              ],
            ),
        ],
        if (state.preparing || state.running || state.completed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.preparing
                  ? l10n.voiceAsrPreparing
                  : state.finishing
                  ? l10n.voiceAsrFinishing
                  : state.running
                  ? l10n.voiceAsrRecognizing
                  : l10n.voiceAsrFinished,
            ),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              voiceAsrError(l10n, state.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

String voiceAsrError(AppLocalizations l10n, String code) => switch (code) {
  'audio_format' => l10n.voiceAsrWaveFormat,
  'busy' => l10n.voiceAsrReplayBusy,
  'report_export' => l10n.appDataExportFailed,
  'model_missing' => l10n.voiceAsrModelMissing,
  'model_checksum' => l10n.voiceAsrModelDamaged,
  'model_download' => l10n.voiceAsrDownloadFailed,
  'storage_full' => l10n.voiceAsrStorageFull,
  'identity_reset' => l10n.voiceAsrReconnectFailed,
  'model_storage' => l10n.appDataUpdateFailed,
  'registration' => l10n.voiceAsrRegistrationFailed,
  'service_rejected' => l10n.voiceAsrServiceRejected,
  'timeout' => l10n.voiceAsrTimeout,
  'opus_format' => l10n.voiceAsrOpusUnsupported,
  'unsupported' => l10n.voiceAsrUnsupported,
  'slow' => l10n.voiceAsrTooSlow,
  'empty' => l10n.voiceAsrNoSpeech,
  'protocol' || 'service_ended' => l10n.voiceAsrInvalidResponse,
  'local_inference' => l10n.voiceAsrInferenceFailed,
  'cancelled' => l10n.voiceAsrCancelled,
  _ => l10n.voiceAsrConnectionFailed,
};
