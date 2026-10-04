import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/wasm/wasm_opus_decoder.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class ZeppOsXiaoAiPage extends ConsumerStatefulWidget {
  const ZeppOsXiaoAiPage({super.key});

  @override
  ConsumerState<ZeppOsXiaoAiPage> createState() => _ZeppOsXiaoAiPageState();
}

class _ZeppOsXiaoAiPageState extends ConsumerState<ZeppOsXiaoAiPage> {
  final _audio = SoLoud.instance;
  final _replyController = TextEditingController();
  final _opusFrames = <Uint8List>[];
  final _opusDurations = <int>[];
  final _pcmBytes = BytesBuilder(copy: false);
  final _waveform = <double>[];
  StreamSubscription<Uint8List>? _frameSubscription;
  WasmOpusDecoder? _decoder;
  AudioSource? _audioSource;
  bool _playback = true;
  bool _continuousCapture = false;
  int _assistantEndpoint = 0x0010;
  bool _ready = false;
  String? _error;
  int _frames = 0;
  int _opusBytes = 0;
  int _pcmSamples = 0;

  @override
  void initState() {
    super.initState();
    _frameSubscription = ref
        .read(deviceManagerProvider.notifier)
        .xiaoAiOpusFrames
        .listen(_onFrame);
    unawaited(_initializeAudio());
  }

  Future<void> _initializeAudio() async {
    final l10n = AppLocalizations.of(context)!;
    WasmOpusDecoder? decoder;
    try {
      decoder = await WasmOpusDecoder.create();
      if (!mounted) {
        decoder.dispose();
        return;
      }
      await _audio.init(channels: Channels.mono);
      if (!mounted) {
        decoder.dispose();
        _audio.deinit();
        return;
      }
      final source = _audio.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 5),
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.08,
        sampleRate: 16000,
        channels: Channels.mono,
        format: BufferType.f32le,
      );
      _audio.play(source);
      if (!mounted) {
        decoder.dispose();
        _audio.deinit();
        return;
      }
      _decoder = decoder;
      _audioSource = source;
      setState(() => _ready = true);
    } catch (error) {
      decoder?.dispose();
      if (_audio.isInitialized) _audio.deinit();
      if (mounted) {
        setState(() => _error = localizedErrorMessage(l10n, error));
      }
    }
  }

  void _onFrame(Uint8List frame) {
    final l10n = AppLocalizations.of(context)!;
    final decoder = _decoder;
    if (decoder == null) return;
    try {
      final pcm = decoder.decode(frame);
      final bytes = ByteData(pcm.length * 2);
      for (var i = 0; i < pcm.length; i += 1) {
        final sample = (pcm[i].clamp(-1.0, 1.0) * 32767).round();
        bytes.setInt16(i * 2, sample, Endian.little);
      }
      if (pcm.isNotEmpty) {
        const buckets = 3;
        final bucketSize = max(1, pcm.length ~/ buckets);
        for (var bucket = 0; bucket < buckets; bucket += 1) {
          final start = bucket * bucketSize;
          final end = min(pcm.length, start + bucketSize);
          var sumSquares = 0.0;
          for (var i = start; i < end; i += 1) {
            sumSquares += pcm[i] * pcm[i];
          }
          final rms = sqrt(sumSquares / max(1, end - start));
          _waveform.add((sqrt(rms) * 1.35).clamp(0.025, 1.0));
        }
        while (_waveform.length > 180) {
          _waveform.removeAt(0);
        }
      }
      _opusFrames.add(Uint8List.fromList(frame));
      _opusDurations.add(pcm.length * 3);
      _pcmBytes.add(bytes.buffer.asUint8List());
      final audioSource = _audioSource;
      if (_playback && pcm.isNotEmpty && audioSource != null) {
        _audio.addAudioDataStream(
          audioSource,
          pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
        );
      }
      if (!mounted) return;
      setState(() {
        _frames += 1;
        _opusBytes += frame.length;
        _pcmSamples += pcm.length;
        if (_error?.startsWith(l10n.voiceLabAudioProcessingFailedPrefix) ==
            true) {
          _error = null;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.voiceLabAudioProcessingFailed(
            localizedErrorMessage(l10n, error),
          ),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      await manager.setXiaoAiEndpoint(_assistantEndpoint);
      await manager.sendXiaoAiReply(_replyController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(deviceManagerProvider).xiaoAiActive
                  ? l10n.voiceLabReplyQueued
                  : l10n.voiceLabReplySent,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.sendFailed(localizedErrorMessage(l10n, error)),
        );
      }
    }
  }

  Future<void> _setContinuousCapture(bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      await manager.setXiaoAiEndpoint(_assistantEndpoint);
      await manager.setXiaoAiContinuousCapture(enabled);
      if (mounted) setState(() => _continuousCapture = enabled);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.voiceLabContinuousCaptureFailed(
            localizedErrorMessage(l10n, error),
          ),
        );
      }
    }
  }

  Future<void> _setAssistantEndpoint(int endpoint) async {
    final l10n = AppLocalizations.of(context)!;
    if (endpoint == _assistantEndpoint) return;
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setXiaoAiEndpoint(endpoint);
      if (_ready) {
        _decoder?.dispose();
        _decoder = null;
        final decoder = await WasmOpusDecoder.create();
        if (!mounted) {
          decoder.dispose();
          return;
        }
        _decoder = decoder;
      }
      if (mounted) {
        setState(() {
          _assistantEndpoint = endpoint;
          _continuousCapture = false;
          _waveform.clear();
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.voiceLabAssistantSwitchFailed(
            localizedErrorMessage(l10n, error),
          ),
        );
      }
    }
  }

  Future<void> _saveWav() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await FilePicker.saveFile(
        dialogTitle: l10n.voiceLabSaveRecording,
        fileName: 'xiaoai-${DateTime.now().millisecondsSinceEpoch}.wav',
        type: FileType.custom,
        allowedExtensions: const ['wav'],
        bytes: _wavFile(_pcmBytes.toBytes()),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.voiceLabExportWavFailed(
            localizedErrorMessage(l10n, error),
          ),
        );
      }
    }
  }

  Future<void> _saveOpus() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await FilePicker.saveFile(
        dialogTitle: l10n.voiceLabSaveOpus,
        fileName: 'xiaoai-${DateTime.now().millisecondsSinceEpoch}.opus',
        type: FileType.custom,
        allowedExtensions: const ['opus'],
        bytes: _oggOpusFile(_opusFrames, _opusDurations),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.voiceLabExportOpusFailed(
            localizedErrorMessage(l10n, error),
          ),
        );
      }
    }
  }

  void _clearCapture() {
    _opusFrames.clear();
    _opusDurations.clear();
    _pcmBytes.clear();
    _waveform.clear();
    setState(() {
      _frames = 0;
      _opusBytes = 0;
      _pcmSamples = 0;
    });
  }

  @override
  void dispose() {
    if (_continuousCapture) {
      unawaited(
        ref
            .read(deviceManagerProvider.notifier)
            .setXiaoAiContinuousCapture(false)
            .catchError((_) {}),
      );
    }
    unawaited(_frameSubscription?.cancel());
    _replyController.dispose();
    _decoder?.dispose();
    if (_audio.isInitialized) _audio.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final assistantName = _assistantEndpoint == 0x004a
        ? 'Zepp Flow'
        : l10n.voiceLabXiaoAi;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.voiceLabTitle)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              0,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final main = _SectionCard(
                  child: _buildSessionPanel(context, state, assistantName),
                );
                final side = _SectionCard(child: _buildCapturePanel(context));
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: main),
                          const SizedBox(width: 16),
                          Expanded(child: side),
                        ],
                      )
                    : Column(
                        children: [main, const SizedBox(height: 16), side],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPanel(
    BuildContext context,
    DeviceManagerState state,
    String assistantName,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final endpoint = _assistantEndpoint
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: Icon(
                state.xiaoAiActive ? Icons.graphic_eq : Icons.mic_none,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assistantName, style: theme.textTheme.headlineSmall),
                  Text(
                    state.xiaoAiActive
                        ? l10n.voiceLabReceivingAudio
                        : l10n.voiceLabWaiting,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(active: state.xiaoAiActive),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 0x0010,
              icon: Icon(Icons.watch),
              label: Text(l10n.voiceLabXiaoAi),
            ),
            ButtonSegment(
              value: 0x004a,
              icon: Icon(Icons.auto_awesome),
              label: Text('Zepp Flow'),
            ),
          ],
          selected: {_assistantEndpoint},
          onSelectionChanged: state.protocolState == proto.ProtocolState.ready
              ? (values) => _setAssistantEndpoint(values.first)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          'Endpoint 0x$endpoint · Opus 16 kHz Mono',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 20),
        Container(
          height: 156,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(
            painter: _AudioWaveformPainter(
              samples: List<double>.of(_waveform),
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.voiceLabContinuousCapture),
                subtitle: Text(l10n.voiceLabContinuousCaptureDescription),
                value: _continuousCapture,
                onChanged: state.protocolState == proto.ProtocolState.ready
                    ? _setContinuousCapture
                    : null,
              ),
            ),
            IconButton.filledTonal(
              tooltip: _playback
                  ? l10n.voiceLabDisableMonitoring
                  : l10n.voiceLabEnableMonitoring,
              onPressed: _ready
                  ? () => setState(() => _playback = !_playback)
                  : null,
              icon: Icon(_playback ? Icons.volume_up : Icons.volume_off),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _replyController,
          decoration: InputDecoration(
            labelText: l10n.voiceLabReplyLabel,
            hintText: l10n.voiceLabReplyHint,
            filled: true,
            suffixIcon: IconButton(
              tooltip: l10n.send,
              icon: const Icon(Icons.send),
              onPressed: _sendReply,
            ),
          ),
          onSubmitted: (_) => _sendReply(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCapturePanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.voiceLabCapturedData,
          leading: const Icon(Icons.analytics_outlined),
        ),
        const SizedBox(height: 16),
        _StatRow(
          label: l10n.voiceLabDecoder,
          value: _ready ? l10n.ready : l10n.initializing,
        ),
        _StatRow(label: l10n.voiceLabOpusFrames, value: '$_frames'),
        _StatRow(label: l10n.voiceLabDataSize, value: _formatBytes(_opusBytes)),
        _StatRow(label: l10n.voiceLabPcmSamples, value: '$_pcmSamples'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _frames == 0 ? null : _saveOpus,
            icon: const Icon(Icons.save_alt),
            label: Text(l10n.voiceLabExportOpus),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pcmSamples == 0 ? null : _saveWav,
            icon: const Icon(Icons.audio_file),
            label: Text(l10n.voiceLabExportWav),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _frames == 0 ? null : _clearCapture,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(l10n.voiceLabClearCapture),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card.filled(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(StyleConstants.pagePadding),
      child: child,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? context.appSelectionContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'LIVE' : 'IDLE',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active
              ? context.appSelectionForeground
              : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _AudioWaveformPainter extends CustomPainter {
  const _AudioWaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    if (samples.isEmpty) return;

    const preferredStep = 6.0;
    final maxBars = max(1, (size.width / preferredStep).floor());
    final visibleSamples = samples.length > maxBars
        ? samples.sublist(samples.length - maxBars)
        : samples;
    final step = size.width / maxBars;
    final barWidth = min(4.0, step * 0.62);
    final startX = size.width - visibleSamples.length * step + step / 2;
    final barPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (var i = 0; i < visibleSamples.length; i += 1) {
      final halfHeight = max(
        barWidth,
        visibleSamples[i] * max(0.0, center - 8),
      );
      final rect = Rect.fromCenter(
        center: Offset(startX + i * step, center),
        width: barWidth,
        height: halfHeight * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWaveformPainter oldDelegate) => true;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

Uint8List _wavFile(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(result);
  void ascii(int offset, String value) =>
      result.setRange(offset, offset + value.length, value.codeUnits);
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}

Uint8List _oggOpusFile(List<Uint8List> frames, List<int> durations) {
  final output = BytesBuilder(copy: false);
  const serial = 0x5a455050;
  var sequence = 0;
  var granule = 0;
  final head = Uint8List.fromList([
    ...'OpusHead'.codeUnits,
    1,
    1,
    0,
    0,
    0x80,
    0x3e,
    0,
    0,
    0,
    0,
    0,
  ]);
  final vendor = 'OronBox';
  final tags = BytesBuilder()
    ..add('OpusTags'.codeUnits)
    ..add(_le32(vendor.length))
    ..add(vendor.codeUnits)
    ..add(_le32(0));
  output.add(_oggPage(head, serial, sequence++, 0, 0x02));
  output.add(_oggPage(tags.toBytes(), serial, sequence++, 0, 0));
  for (var i = 0; i < frames.length; i += 1) {
    granule += durations[i];
    output.add(
      _oggPage(
        frames[i],
        serial,
        sequence++,
        granule,
        i == frames.length - 1 ? 0x04 : 0,
      ),
    );
  }
  return output.toBytes();
}

Uint8List _oggPage(
  Uint8List packet,
  int serial,
  int sequence,
  int granule,
  int headerType,
) {
  final segments = <int>[];
  var remaining = packet.length;
  while (remaining >= 255) {
    segments.add(255);
    remaining -= 255;
  }
  segments.add(remaining);
  final page = Uint8List(27 + segments.length + packet.length);
  final data = ByteData.sublistView(page);
  page.setRange(0, 4, 'OggS'.codeUnits);
  page[4] = 0;
  page[5] = headerType;
  data.setUint64(6, granule, Endian.little);
  data.setUint32(14, serial, Endian.little);
  data.setUint32(18, sequence, Endian.little);
  page[26] = segments.length;
  page.setRange(27, 27 + segments.length, segments);
  page.setRange(27 + segments.length, page.length, packet);
  data.setUint32(22, _oggCrc(page), Endian.little);
  return page;
}

int _oggCrc(Uint8List bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte << 24;
    for (var bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x80000000) != 0
          ? ((crc << 1) ^ 0x04c11db7) & 0xffffffff
          : (crc << 1) & 0xffffffff;
    }
  }
  return crc;
}

Uint8List _le32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
  return bytes;
}
