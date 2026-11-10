import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;
import 'package:oronbox/src/device/xiaomi/systems/media_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/services/device_recordings_storage.dart';
import 'package:segmented_list/segmented_list.dart';

class XiaomiRecordingsPage extends ConsumerStatefulWidget {
  const XiaomiRecordingsPage({super.key});

  @override
  ConsumerState<XiaomiRecordingsPage> createState() =>
      _XiaomiRecordingsPageState();
}

class _XiaomiRecordingsPageState extends ConsumerState<XiaomiRecordingsPage> {
  List<MediaFileDescriptor> _recordings = const [];
  Set<String> _savedFileNames = const {};
  bool _loadingList = false;
  bool _syncing = false;
  bool _cancelling = false;
  int _completed = 0;
  int _total = 0;
  String _currentFile = '';
  double _transferProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_loadList);
  }

  Future<void> _loadList() async {
    if (_syncing || _loadingList) return;
    final ready =
        ref.read(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    if (!ready) return;

    setState(() {
      _loadingList = true;
      _error = null;
    });

    try {
      final listFuture = ref
          .read(deviceManagerProvider.notifier)
          .fetchXiaomiRecordingList();
      final savedFuture = listSavedDeviceRecordings();
      final results = await Future.wait([listFuture, savedFuture]);

      if (!mounted) return;
      setState(() {
        _recordings = results[0] as List<MediaFileDescriptor>;
        _savedFileNames = (results[1] as List<String>).toSet();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordings = const [];
          _error = localizedErrorMessage(AppLocalizations.of(context)!, error);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _exportFiles(List<MediaFileDescriptor> targets) async {
    if (_syncing || targets.isEmpty) return;
    setState(() {
      _syncing = true;
      _completed = 0;
      _total = targets.length;
      _currentFile = '';
      _transferProgress = 0;
      _error = null;
      _cancelling = false;
    });

    try {
      final result = await ref
          .read(deviceManagerProvider.notifier)
          .downloadSelectedXiaomiRecordings(
            files: targets,
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

      final updatedSaved = Set<String>.from(_savedFileNames);
      String? lastSavedPath;
      for (final item in result) {
        final path = await saveDeviceRecording(
          fileName: item.fileName,
          bytes: item.data,
        );
        if (path != null) {
          updatedSaved.add(item.fileName);
          lastSavedPath = path;
        }
      }

      if (!mounted) return;
      setState(() {
        _savedFileNames = updatedSaved;
        _completed = targets.length;
        _total = targets.length;
        _transferProgress = targets.isEmpty ? 0 : 1;
      });

      final l10n = AppLocalizations.of(context)!;
      final message = (targets.length == 1 && lastSavedPath != null)
          ? l10n.deviceRecordingsExported(lastSavedPath)
          : (targets.length == 1)
          ? l10n.deviceRecordingsSaveSuccess
          : l10n.deviceRecordingsSynced(result.length);
      appScaffoldMessengerOf(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted && !_cancelling) {
        final l10n = AppLocalizations.of(context)!;
        final errorMsg = localizedErrorMessage(l10n, error);
        appScaffoldMessengerOf(context).showSnackBar(
          SnackBar(content: Text(l10n.deviceRecordingsSaveFailed(errorMsg))),
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
        final l10n = AppLocalizations.of(context)!;
        appScaffoldMessengerOf(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l10n, error))),
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
    final showList =
        ready && !_loadingList && _error == null && _recordings.isNotEmpty;

    return PopScope(
      canPop: !_syncing,
      child: Scaffold(
        appBar: SysAppBar(
          secondary: true,
          title: Text(l10n.deviceRecordingsTitle),
          actions: [
            IconButton(
              tooltip: l10n.deviceRecordingsRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: (_syncing || _loadingList || !ready)
                  ? null
                  : _loadList,
            ),
          ],
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: showList
            ? StableExtendedFab(
                heroTag: 'xiaomi-recordings-sync',
                onPressed: _syncing
                    ? (_cancelling ? null : _cancel)
                    : () => _exportFiles(_recordings),
                icon: _syncing
                    ? Icon(_cancelling ? Icons.hourglass_top : Icons.close)
                    : const Icon(Icons.sync),
                label: Text(_syncing ? l10n.cancel : l10n.deviceRecordingsSync),
                animationKey: (_syncing, _cancelling),
              )
            : null,
        body: showList
            ? SegmentedList(
                maxWidth: StyleConstants.pageMaxWidth,
                contentPadding: EdgeInsets.only(
                  top: 8,
                  bottom: bottomContentPadding(context, extra: 80),
                ),
                sections: [
                  CustomSegmentedSection(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildHeaderCard(context, l10n, colors),
                    ),
                  ),
                  SegmentedSection(
                    tiles: [
                      for (final recording in _recordings)
                        _buildRecordingTile(context, l10n, colors, recording),
                    ],
                  ),
                ],
              )
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: StyleConstants.pageMaxWidth,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildHeaderCard(context, l10n, colors),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildStatusView(l10n, ready),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.deviceRecordingsLibrary),
          Text(
            l10n.deviceRecordingsLibraryDescription,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (_syncing) ...[
            const SizedBox(height: 16),
            SmoothLinearProgressIndicator(
              value: _total == 0 ? null : _transferProgress,
            ),
            const SizedBox(height: 6),
            Text(
              _total == 0
                  ? l10n.deviceRecordingsReading
                  : l10n.deviceRecordingsProgress(
                      _completed.clamp(0, _total),
                      _total,
                      _currentFile,
                    ),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusView(AppLocalizations l10n, bool ready) {
    if (!ready) {
      return EmptyStateView(
        icon: Icons.bluetooth_disabled_outlined,
        title: l10n.deviceNotConnected,
      );
    }
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _loadList);
    }
    return EmptyStateView(
      icon: Icons.mic_none_outlined,
      title: l10n.deviceRecordingsNoneOnWatch,
    );
  }

  AbstractSegmentedTile _buildRecordingTile(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
    MediaFileDescriptor recording,
  ) {
    final isSaved = _savedFileNames.contains(recording.name);
    final isDownloadingThis = _syncing && _currentFile == recording.name;

    return SegmentedTile(
      key: ValueKey(recording.name),
      leading: Icon(
        isSaved ? Icons.check_circle_outline : Icons.graphic_eq,
        color: isSaved ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(
        recording.name.replaceFirst(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      description: Text(
        [
          if (recording.createdAtMs != null)
            _formatDate(
              DateTime.fromMillisecondsSinceEpoch(recording.createdAtMs!),
            ),
          if (recording.durationSecs != null)
            _formatDuration(recording.durationSecs!),
          if (recording.size != null) _formatBytes(recording.size!),
        ].join(' · '),
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      trailing: isDownloadingThis
          ? const IconButton(
              onPressed: null,
              icon: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : isSaved
          ? IconButton(
              icon: Icon(Icons.done, color: colors.primary),
              tooltip: l10n.deviceRecordingsSave,
              onPressed: _syncing ? null : () => _exportFiles([recording]),
            )
          : IconButton(
              tooltip: l10n.deviceRecordingsSave,
              icon: const Icon(Icons.download_outlined),
              onPressed: _syncing ? null : () => _exportFiles([recording]),
            ),
    );
  }
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
