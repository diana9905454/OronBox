import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_voice_memos_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class ZeppOsVoiceMemosPage extends ConsumerStatefulWidget {
  const ZeppOsVoiceMemosPage({super.key});

  @override
  ConsumerState<ZeppOsVoiceMemosPage> createState() =>
      _ZeppOsVoiceMemosPageState();
}

class _ZeppOsVoiceMemosPageState extends ConsumerState<ZeppOsVoiceMemosPage> {
  List<ZeppOsVoiceMemo> _memos = const [];
  bool _syncing = false;
  bool _cancelling = false;
  int _completed = 0;
  int _total = 0;
  String? _error;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _completed = 0;
      _total = 0;
      _error = null;
      _cancelling = false;
    });
    try {
      final result = await ref
          .read(deviceManagerProvider.notifier)
          .downloadZeppOsVoiceMemos(
            onProgress: (completed, total) {
              if (!mounted) return;
              setState(() {
                _completed = completed;
                _total = total;
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _memos = result;
        _completed = result.length;
        _total = result.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty
                ? AppLocalizations.of(context)!.deviceRecordingsNoneOnWatch
                : AppLocalizations.of(context)!
                      .deviceRecordingsSynced(result.length),
          ),
        ),
      );
    } catch (error) {
      if (mounted && !_cancelling) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _cancel() async {
    if (!_syncing || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(deviceManagerProvider.notifier).cancelRecordingSync();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    }
  }

  Future<void> _save(ZeppOsVoiceMemo memo) async {
    final bytes = memo.bytes;
    if (bytes == null) return;
    try {
      await FilePicker.saveFile(
        dialogTitle: AppLocalizations.of(context)!.deviceRecordingsSave,
        fileName: _safeFilename(memo.filename),
        bytes: bytes,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!
              .deviceRecordingsSaveFailed(
                localizedErrorMessage(AppLocalizations.of(context)!, error),
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ready =
        ref.watch(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.deviceRecordingsTitle),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: StableExtendedFab(
        heroTag: 'zeppos-voice-memos-sync',
        onPressed: _syncing
            ? (_cancelling ? null : _cancel)
            : (ready ? _sync : null),
        icon: _syncing
            ? Icon(_cancelling ? Icons.hourglass_top : Icons.close)
            : const Icon(Icons.sync),
        label: Text(_syncing ? l10n.cancel : l10n.deviceRecordingsSync),
        animationKey: (_syncing, _cancelling),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            padding: EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              bottomContentPadding(context, extra: 80),
            ),
            child: Column(
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: l10n.deviceRecordingsDescription),
                      Text(
                        l10n.deviceRecordingsHint,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (_syncing) ...[
                        const SizedBox(height: 16),
                        SmoothLinearProgressIndicator(
                          value: _total == 0 ? null : _completed / _total,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _total == 0
                              ? l10n.deviceRecordingsReading
                              : l10n.deviceRecordingsProgressCount(
                                  _completed,
                                  _total,
                                ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: colors.error)),
                      ],
                    ],
                  ),
                ),
                if (_memos.isEmpty && !_syncing)
                  EmptyStateView(
                    compact: true,
                    icon: Icons.mic_none_outlined,
                    title: l10n.deviceRecordingsEmpty,
                  )
                else
                  ..._memos.map(
                    (memo) => Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.graphic_eq),
                        title: Text(memo.filename.replaceAll('.opus', '')),
                        subtitle: Text(
                          '${_formatDate(memo.timestamp)}  ·  '
                          '${_formatDuration(memo.durationMs)}  ·  '
                          '${_formatBytes(memo.size)}',
                        ),
                        trailing: IconButton(
                          tooltip: l10n.deviceRecordingsSave,
                          onPressed: memo.bytes == null
                              ? null
                              : () => _save(memo),
                          icon: const Icon(Icons.save_alt),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _safeFilename(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  final safe = sanitized.isEmpty ? 'voice-memo' : sanitized;
  return safe.toLowerCase().endsWith('.opus') ? safe : '$safe.opus';
}

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
