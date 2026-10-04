import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class XiaomiRecordingsPage extends ConsumerStatefulWidget {
  const XiaomiRecordingsPage({super.key});

  @override
  ConsumerState<XiaomiRecordingsPage> createState() =>
      _XiaomiRecordingsPageState();
}

class _XiaomiRecordingsPageState extends ConsumerState<XiaomiRecordingsPage> {
  List<DeviceRecording> _recordings = const [];
  bool _syncing = false;
  bool _cancelling = false;
  int _completed = 0;
  int _total = 0;
  String _currentFile = '';
  double _transferProgress = 0;
  String? _error;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _completed = 0;
      _total = 0;
      _currentFile = '';
      _transferProgress = 0;
      _error = null;
      _cancelling = false;
    });
    try {
      final result = await ref
          .read(deviceManagerProvider.notifier)
          .downloadXiaomiRecordings(
            onProgress: (completed, total, fileName) {
              if (!mounted) return;
              setState(() {
                _completed = completed;
                _total = total;
                _currentFile = fileName;
                _transferProgress = total == 0 ? 0 : completed / total;
              });
            },
            onDetailedProgress: (value) {
              if (!mounted) return;
              setState(() {
                _completed = value.currentIndex - 1;
                _total = value.totalFiles;
                _currentFile = value.fileName;
                _transferProgress = value.progress;
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _recordings = result;
        _completed = result.length;
        _total = result.length;
        _transferProgress = result.isEmpty ? 0 : 1;
      });
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

  Future<void> _save(DeviceRecording recording) async {
    final extension = _extension(recording.fileName);
    try {
      await FilePicker.saveFile(
        dialogTitle: AppLocalizations.of(context)!.deviceRecordingsSave,
        fileName: _safeFileName(recording.fileName, extension),
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: recording.data,
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ready =
        ref.watch(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_syncing,
      child: Scaffold(
        appBar: SysAppBar(
          secondary: true,
          title: Text(l10n.deviceRecordingsTitle),
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: StableExtendedFab(
          heroTag: 'xiaomi-recordings-sync',
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
              padding: const EdgeInsets.fromLTRB(
                StyleConstants.pagePadding,
                16,
                StyleConstants.pagePadding,
                StyleConstants.pagePadding + 88,
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
                            value: _total == 0 ? null : _transferProgress,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _total == 0
                                ? l10n.deviceRecordingsReading
                                : l10n.deviceRecordingsProgress(
                                    _completed.clamp(0, _total),
                                    _total,
                                    _currentFile,
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
                  if (_recordings.isEmpty && !_syncing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mic_none,
                            size: 48,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.deviceRecordingsEmpty),
                        ],
                      ),
                    )
                  else
                    ..._recordings.map(
                      (recording) => Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.graphic_eq),
                          title: Text(recording.fileName),
                          subtitle: Text(
                            [
                              if (recording.createdAt != null)
                                _formatDate(recording.createdAt!),
                              if (recording.durationSeconds != null)
                                _formatDuration(recording.durationSeconds!),
                              _formatBytes(recording.data.length),
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: l10n.deviceRecordingsSave,
                            onPressed: () => _save(recording),
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
      ),
    );
  }
}

String _extension(String fileName) {
  final index = fileName.lastIndexOf('.');
  if (index < 0 || index == fileName.length - 1) return 'opus';
  return fileName.substring(index + 1).toLowerCase();
}

String _safeFileName(String value, String extension) {
  final sanitized = value
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  final safe = sanitized.isEmpty ? 'recording' : sanitized;
  return safe.toLowerCase().endsWith('.$extension') ? safe : '$safe.$extension';
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes;
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$secs';
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
