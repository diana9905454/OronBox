import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_music_upload_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class DeviceMusicUploadPage extends ConsumerStatefulWidget {
  const DeviceMusicUploadPage({super.key, this.xiaomi = false});

  final bool xiaomi;

  @override
  ConsumerState<DeviceMusicUploadPage> createState() =>
      _DeviceMusicUploadPageState();
}

class _DeviceMusicUploadPageState extends ConsumerState<DeviceMusicUploadPage> {
  final _pendingFiles = <_PendingMusicFile>[];
  int _selectedFileIndex = -1;
  int _activeFileIndex = -1;
  final _title = TextEditingController();
  final _artist = TextEditingController();
  bool _artistInitialized = false;
  bool _uploading = false;
  bool _loadingLibrary = false;
  double _progress = 0;
  double _bytesPerSecond = 0;
  LinkTrafficMeter? _transferMeter;
  StreamSubscription<LinkTraffic>? _transferTrafficSubscription;
  int _lastProgressBytes = 0;
  String? _libraryError;
  String? _uploadError;
  DeviceMusicLibrary? _library;

  _PendingMusicFile? get _selectedFile =>
      _selectedFileIndex >= 0 && _selectedFileIndex < _pendingFiles.length
      ? _pendingFiles[_selectedFileIndex]
      : null;

  @override
  void initState() {
    super.initState();
    if (widget.xiaomi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
    }
  }

  Future<void> _loadLibrary() async {
    if (_loadingLibrary || !mounted) return;
    final ready =
        ref.read(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    if (!ready) return;
    setState(() {
      _loadingLibrary = true;
      _libraryError = null;
    });
    try {
      final library = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiMusicLibrary();
      if (mounted) {
        setState(() {
          _library = library;
          _libraryError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _library = null;
          _libraryError = AppLocalizations.of(context)!.deviceMusicLoadFailed(
            localizedErrorMessage(AppLocalizations.of(context)!, error),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loadingLibrary = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_artistInitialized) return;
    _artistInitialized = true;
    _artist.text = AppLocalizations.of(context)!.deviceMusicUnknownArtist;
  }

  Future<void> _chooseFile() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await pickFilesData(
      dialogTitle: l10n.deviceMusicChooseDialog,
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
      allowMultiple: true,
      loadBytes: true,
    );
    if (result.isEmpty) return;
    final maxBytes = widget.xiaomi
        ? 100 * 1024 * 1024
        : ZeppOsMusicUploadSystem.maxFileBytes;
    final additions = <_PendingMusicFile>[];
    for (final file in result) {
      final bytes = await file.readAsBytes();
      if (bytes == null) {
        setState(() => _uploadError = l10n.deviceMusicReadFailed);
        return;
      }
      if (bytes.isEmpty || bytes.length > maxBytes) {
        setState(
          () => _uploadError = l10n.deviceMusicSizeInvalid(
            maxBytes ~/ (1024 * 1024),
          ),
        );
        return;
      }
      final base = file.name.toLowerCase().endsWith('.mp3')
          ? file.name.substring(0, file.name.length - 4)
          : file.name;
      additions.add(
        _PendingMusicFile(
          bytes: bytes,
          fileName: file.name,
          title: base,
          artist: l10n.deviceMusicUnknownArtist,
        ),
      );
    }
    setState(() {
      final firstAdded = _pendingFiles.length;
      _pendingFiles.addAll(additions);
      _selectedFileIndex = firstAdded;
      _progress = 0;
      _uploadError = null;
    });
    _loadSelectedFileEditors();
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pendingFiles.isEmpty || _uploading) return;
    final files = List<_PendingMusicFile>.of(_pendingFiles);
    await _resetTransferMeter();
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _bytesPerSecond = 0;
      _uploadError = null;
    });
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final bytes = file.bytes;
        if (mounted) setState(() => _activeFileIndex = index);
        _lastProgressBytes = 0;
        void progress(double value) => _updateTransferProgress(
          value,
          bytes.length,
          queueIndex: index,
          queueLength: files.length,
        );
        if (widget.xiaomi) {
          await manager.uploadXiaomiMusic(
            bytes,
            title: file.title,
            artist: file.artist,
            onProgress: progress,
          );
        } else {
          await manager.uploadZeppOsMusic(
            bytes,
            fileName: file.fileName,
            title: file.title,
            artist: file.artist,
            onProgress: progress,
          );
        }
      }
      if (!mounted) return;
      setState(() => _progress = 1);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.deviceMusicTransferred)));
      if (widget.xiaomi) await _loadLibrary();
    } catch (error) {
      if (mounted) {
        setState(
          () => _uploadError = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _activeFileIndex = -1;
        });
      }
    }
  }

  Future<void> _resetTransferMeter() async {
    await _transferTrafficSubscription?.cancel();
    await _transferMeter?.dispose();
    _lastProgressBytes = 0;
    final meter = LinkTrafficMeter();
    _transferMeter = meter;
    _transferTrafficSubscription = meter.stream.listen((traffic) {
      if (mounted) {
        setState(() => _bytesPerSecond = traffic.uploadBytesPerSecond);
      }
    });
  }

  void _updateTransferProgress(
    double value,
    int totalBytes, {
    required int queueIndex,
    required int queueLength,
  }) {
    if (!mounted) return;
    final progress = value.clamp(0.0, 1.0);
    final sentBytes = (totalBytes * progress).round();
    final delta = sentBytes - _lastProgressBytes;
    if (delta > 0) _transferMeter?.addUpload(delta);
    _lastProgressBytes = sentBytes;
    setState(() => _progress = (queueIndex + progress) / queueLength);
  }

  void _loadSelectedFileEditors() {
    final file = _selectedFile;
    _title.text = file?.title ?? '';
    _artist.text = file?.artist ?? '';
  }

  void _selectPendingFile(int index) {
    if (_uploading) return;
    setState(() => _selectedFileIndex = index);
    _loadSelectedFileEditors();
  }

  void _removePendingFile(int index) {
    if (_uploading) return;
    setState(() {
      _pendingFiles.removeAt(index);
      if (_pendingFiles.isEmpty) {
        _selectedFileIndex = -1;
        _uploadError = null;
      } else {
        _selectedFileIndex = _selectedFileIndex.clamp(
          0,
          _pendingFiles.length - 1,
        );
      }
    });
    _loadSelectedFileEditors();
  }

  @override
  void dispose() {
    _transferTrafficSubscription?.cancel();
    _transferMeter?.dispose();
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(deviceManagerProvider.select((s) => s.protocolState), (
      previous,
      next,
    ) {
      if (widget.xiaomi &&
          next == proto.ProtocolState.ready &&
          _library == null &&
          !_loadingLibrary) {
        _loadLibrary();
      }
    });
    ref.listen(deviceManagerProvider.select((s) => s.currentDevice?.addr), (
      previous,
      next,
    ) {
      if (previous != null && next != previous) {
        if (mounted) {
          setState(() {
            _library = null;
            _libraryError = null;
            _pendingFiles.clear();
            _selectedFileIndex = -1;
            _uploadError = null;
          });
          if (widget.xiaomi) {
            _loadLibrary();
          }
        }
      }
    });

    final ready =
        ref.watch(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    final canTransfer = ready && (!widget.xiaomi || _library != null);
    final canChooseFile = canTransfer && !_uploading;
    final canSend = canTransfer && _pendingFiles.isNotEmpty && !_uploading;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: SysAppBar(
          secondary: true,
          title: Text(
            widget.xiaomi ? l10n.deviceMusicSync : l10n.deviceMusicUpload,
          ),
          actions: [
            if (widget.xiaomi)
              IconButton(
                tooltip: l10n.refresh,
                onPressed: (!ready || _loadingLibrary || _uploading)
                    ? null
                    : _loadLibrary,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            PageContainer(
              padding: EdgeInsets.fromLTRB(
                StyleConstants.pagePadding,
                8,
                StyleConstants.pagePadding,
                bottomContentPadding(context, extra: 24),
              ),
              child: Column(
                children: [
                  if (widget.xiaomi) ...[
                    _buildLibraryCard(context, l10n, ready: ready),
                    const SizedBox(height: StyleConstants.sectionSpacing),
                  ],
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(title: l10n.deviceMusicTransferTitle),
                        Text(
                          widget.xiaomi
                              ? l10n.deviceMusicVelaDescription
                              : l10n.deviceMusicZeppDescription,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        if (widget.xiaomi &&
                            ready &&
                            !_loadingLibrary &&
                            _library == null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: colors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _libraryError ??
                                      l10n.errorDeviceMusicUnsupported,
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: canChooseFile ? _chooseFile : null,
                          icon: const Icon(Icons.audio_file_outlined),
                          label: Text(
                            _pendingFiles.isEmpty
                                ? l10n.deviceMusicChooseMp3
                                : l10n.deviceMusicSelectedFiles(
                                    _pendingFiles.length,
                                  ),
                          ),
                        ),
                        if (_pendingFiles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (
                            var index = 0;
                            index < _pendingFiles.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                color: index == _selectedFileIndex
                                    ? Theme.of(context).useMaterial3
                                          ? colors.secondaryContainer
                                          : context.appSelectionContainer
                                    : colors.surfaceContainerHighest,
                                child: ListTile(
                                  onTap: () => _selectPendingFile(index),
                                  leading: const Icon(
                                    Icons.audio_file_outlined,
                                  ),
                                  title: Text(_pendingFiles[index].title),
                                  subtitle: Text(
                                    '${_pendingFiles[index].fileName} · '
                                    '${_formatBytes(_pendingFiles[index].bytes.length)}',
                                  ),
                                  trailing: IconButton(
                                    onPressed: _uploading
                                        ? null
                                        : () => _removePendingFile(index),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _title,
                            enabled: canTransfer && !_uploading,
                            decoration: InputDecoration(
                              labelText: l10n.deviceMusicSongTitle,
                              prefixIcon: const Icon(Icons.music_note),
                            ),
                            onChanged: (value) {
                              final file = _selectedFile;
                              if (file != null) file.title = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _artist,
                            enabled: canTransfer && !_uploading,
                            decoration: InputDecoration(
                              labelText: l10n.deviceMusicArtist,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            onChanged: (value) {
                              final file = _selectedFile;
                              if (file != null) file.artist = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.deviceMusicFileSize(
                              _formatBytes(_selectedFile?.bytes.length ?? 0),
                            ),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                        if (_uploading || _progress > 0) ...[
                          const SizedBox(height: 20),
                          SmoothLinearProgressIndicator(value: _progress),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                l10n.deviceMusicProgress(
                                  (_progress * 100).toStringAsFixed(1),
                                ),
                              ),
                              const Spacer(),
                              if (_bytesPerSecond > 0)
                                Text(
                                  l10n.deviceMusicTransferSpeed(
                                    _formatBytes(_bytesPerSecond.round()),
                                  ),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (_uploading && _activeFileIndex >= 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.deviceMusicQueueProgress(
                                _activeFileIndex + 1,
                                _pendingFiles.length,
                                _pendingFiles[_activeFileIndex].fileName,
                              ),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ],
                        if (_uploadError != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _uploadError!,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: canSend ? _upload : null,
                          icon: _uploading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _uploading
                                ? l10n.deviceMusicTransferring
                                : l10n.deviceMusicSend,
                          ),
                        ),
                      ],
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

  Widget _buildLibraryCard(
    BuildContext context,
    AppLocalizations l10n, {
    required bool ready,
  }) {
    final colors = Theme.of(context).colorScheme;
    final library = _library;
    return SectionCard(
      // spacing to the next card is handled by the SizedBox below
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.deviceMusicLibrary),
          Text(
            l10n.deviceMusicLibraryDescription,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (!ready) ...[
            const SizedBox(height: 16),
            EmptyStateView(
              compact: true,
              icon: Icons.bluetooth_disabled_outlined,
              title: l10n.deviceNotConnected,
            ),
          ] else if (_loadingLibrary && library == null) ...[
            const SizedBox(height: 24),
            const Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_libraryError != null && library == null) ...[
            const SizedBox(height: 16),
            ErrorStateView(
              compact: true,
              message: _libraryError!,
              onRetry: _loadLibrary,
            ),
          ] else if (library != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  l10n.deviceMusicPlaylists,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: l10n.deviceMusicPlaylistCreate,
                  onPressed:
                      library.playlistLimit > 0 &&
                          library.playlists.length >= library.playlistLimit
                      ? null
                      : () => _editPlaylist(),
                  icon: const Icon(Icons.playlist_add),
                ),
              ],
            ),
            if (library.playlistLimit > 0)
              Text(
                l10n.deviceMusicPlaylistLimit(library.playlistLimit),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (library.playlists.isEmpty)
              _EmptyMusicState(
                icon: Icons.queue_music,
                label: l10n.deviceMusicNoPlaylists,
              )
            else
              ...library.playlists.map(
                (playlist) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.queue_music),
                  title: Text(playlist.name),
                  subtitle: Text(l10n.deviceMusicSongCount(playlist.songCount)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'rename') {
                        _editPlaylist(playlist: playlist);
                      } else if (action == 'delete') {
                        _deletePlaylist(playlist);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.deviceMusicPlaylistRename),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              l10n.deviceMusicSongs,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              l10n.deviceMusicSongsTotal(library.songs.length),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (library.songs.isEmpty)
              _EmptyMusicState(
                icon: Icons.music_off_outlined,
                label: l10n.deviceMusicEmpty,
              )
            else
              ...library.songs.map(
                (song) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note),
                  title: Text(song.name),
                  subtitle: Text(_songDetails(l10n, song, library)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.deviceMusicManagePlaylists,
                        onPressed: library.playlists.isEmpty
                            ? null
                            : () => _manageSongPlaylists(song, library),
                        icon: const Icon(Icons.playlist_add_check),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        onPressed: () => _deleteSong(song),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _editPlaylist({DeviceMusicPlaylist? playlist}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: playlist?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          playlist == null
              ? l10n.deviceMusicPlaylistCreate
              : l10n.deviceMusicPlaylistRename,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.deviceMusicPlaylistName),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      if (playlist == null) {
        await manager.createXiaomiMusicPlaylist(name);
      } else {
        await manager.renameXiaomiMusicPlaylist(playlist.id, name);
      }
      await _loadLibrary();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deletePlaylist(DeviceMusicPlaylist playlist) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _confirm(
      l10n.deviceMusicDeletePlaylist,
      l10n.deviceMusicDeletePlaylistDescription,
    )) {
      return;
    }
    if (!mounted) return;
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .removeXiaomiMusicPlaylist(playlist.id);
      await _loadLibrary();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSong(DeviceMusicSong song) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _confirm(l10n.deviceMusicDeleteSong, song.name)) return;
    if (!mounted) return;
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .removeXiaomiMusicSong(song.id);
      await _loadLibrary();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _manageSongPlaylists(
    DeviceMusicSong song,
    DeviceMusicLibrary library,
  ) async {
    final manager = ref.read(deviceManagerProvider.notifier);
    final selected = song.playlistIds.toSet();
    final changed = await showDialog<Map<int, bool>>(
      context: context,
      builder: (context) {
        final values = {
          for (final playlist in library.playlists)
            playlist.id: selected.contains(playlist.id),
        };
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              AppLocalizations.of(context)!.deviceMusicPlaylistMembership,
            ),
            content: SizedBox(
              width: 360,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final playlist in library.playlists)
                    CheckboxListTile(
                      contentPadding: const EdgeInsetsDirectional.only(end: 12),
                      value: values[playlist.id],
                      title: Text(playlist.name),
                      onChanged: (value) => setDialogState(
                        () => values[playlist.id] = value ?? false,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, values),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        );
      },
    );
    if (changed == null || !mounted) return;
    try {
      for (final entry in changed.entries) {
        if (entry.value == selected.contains(entry.key)) continue;
        await manager.setXiaomiMusicSongInPlaylist(
          playlistId: entry.key,
          songId: song.id,
          included: entry.value,
        );
      }
      await _loadLibrary();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class _EmptyMusicState extends StatelessWidget {
  const _EmptyMusicState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      EmptyStateView(compact: true, icon: icon, title: label);
}

class _PendingMusicFile {
  _PendingMusicFile({
    required this.bytes,
    required this.fileName,
    required this.title,
    required this.artist,
  });

  final Uint8List bytes;
  final String fileName;
  String title;
  String artist;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _songDetails(
  AppLocalizations l10n,
  DeviceMusicSong song,
  DeviceMusicLibrary library,
) {
  final playlistNames = library.playlists
      .where((playlist) => song.playlistIds.contains(playlist.id))
      .map((playlist) => playlist.name)
      .join('、');
  return [
    song.artist,
    song.album,
    if (song.duration > 0) _formatDuration(song.duration),
    if (song.size > 0) _formatBytes(song.size),
    playlistNames.isEmpty ? l10n.deviceMusicNoPlaylist : playlistNames,
  ].where((value) => value.isNotEmpty).join(' · ');
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) return '${duration.inHours}:$minutes:$secs';
  return '${duration.inMinutes}:$secs';
}
