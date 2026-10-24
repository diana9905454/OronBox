import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_benchmark.dart';
import 'package:oronbox/src/core/asr/asr_model_store.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/voice/application/voice_recognition_controller.dart';

import 'voice_recognition_controls.dart';

class VoiceReplayPanel extends ConsumerStatefulWidget {
  const VoiceReplayPanel({
    super.key,
    required this.recording,
    required this.opus,
  });
  final Uint8List Function() recording;
  final List<Uint8List> Function() opus;
  @override
  ConsumerState<VoiceReplayPanel> createState() => _VoiceReplayPanelState();
}

class _VoiceReplayPanelState extends ConsumerState<VoiceReplayPanel> {
  bool _busy = false;
  AsrBenchmarkReport? _report;
  AsrBackend? _backend;
  String? _error;
  Future<void> _run({required bool imported}) async {
    setState(() {
      _busy = true;
      _report = null;
      _error = null;
    });
    try {
      Float32List pcm;
      if (imported) {
        final picked = await pickFileData(
          type: FileType.custom,
          allowedExtensions: const ['wav'],
          maxBytes: 2 * 16000 * 60 + 65536,
          loadBytes: true,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes == null) return;
        pcm = decodePcm16Wave(bytes);
      } else {
        pcm = decodePcm16(widget.recording());
      }
      if (!mounted) return;
      final state = ref.read(voiceRecognitionProvider);
      if (ref.read(deviceManagerProvider).xiaoAiActive ||
          state.running ||
          state.preparing) {
        throw const AsrFailure('busy');
      }
      _backend = state.backend;
      final report = await ref
          .read(voiceRecognitionProvider.notifier)
          .replay(pcm, opus: imported ? null : widget.opus());
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AsrFailure
              ? error.code
              : error is PickedFileTooLarge
              ? 'audio_format'
              : 'connection',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null) return;
    try {
      await FilePicker.saveFile(
        fileName: 'OronBox-ASR-${DateTime.now().millisecondsSinceEpoch}.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert({
              ...report.toJson(),
              'backend': _backend?.name,
              'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
              if (_backend == AsrBackend.native || _backend == AsrBackend.wasm)
                'modelRevision': AsrModelStore.revision,
            }),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'report_export');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voiceRecognitionProvider);
    final enabled =
        !_busy &&
        !state.preparing &&
        !state.running &&
        state.backend != AsrBackend.manual &&
        !ref.watch(deviceManagerProvider.select((state) => state.xiaoAiActive));
    final report = _report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.voiceAsrReplayDescription),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: enabled ? () => _run(imported: false) : null,
              child: Text(l10n.voiceAsrReplayRecording),
            ),
            OutlinedButton(
              onPressed: enabled && state.backend != AsrBackend.wetype
                  ? () => _run(imported: true)
                  : null,
              child: Text(l10n.voiceAsrImportWave),
            ),
            if (_busy)
              TextButton(
                onPressed: () =>
                    ref.read(voiceRecognitionProvider.notifier).cancel(),
                child: Text(l10n.cancel),
              ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (report != null) ...[
          const SizedBox(height: 8),
          SelectableText(report.text),
          Text(
            l10n.voiceAsrReplayMetrics(
              '${report.elapsedMilliseconds}',
              '${report.firstResultMilliseconds ?? '-'}',
              report.realTimeFactor.toStringAsFixed(2),
            ),
          ),
          TextButton(
            onPressed: _export,
            child: Text(l10n.voiceAsrExportReport),
          ),
        ],
        if (_error != null)
          Text(
            voiceAsrError(l10n, _error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
