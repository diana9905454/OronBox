import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_debug_snapshot_store.dart';

class XiaomiHealthDebugPage extends ConsumerStatefulWidget {
  const XiaomiHealthDebugPage({super.key});

  @override
  ConsumerState<XiaomiHealthDebugPage> createState() =>
      _XiaomiHealthDebugPageState();
}

class _XiaomiHealthDebugPageState extends ConsumerState<XiaomiHealthDebugPage> {
  final _store = HealthDebugSnapshotStore();
  List<XiaomiHealthRawSnapshot> _snapshots = const [];
  String? _error;
  String? _reloadingSnapshotId;
  String? _exportingSnapshotId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final snapshots = await _store.read();
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload(XiaomiHealthRawSnapshot snapshot) async {
    final manager = ref.read(deviceManagerProvider.notifier);
    setState(() {
      _reloadingSnapshotId = snapshot.id;
      _error = null;
    });
    try {
      await manager.replayXiaomiHealthSnapshot(
        snapshot.deviceId,
        snapshot.files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.deviceHealthDebugReloaded,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _reloadingSnapshotId = null);
    }
  }

  Future<void> _export(XiaomiHealthRawSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _exportingSnapshotId = snapshot.id;
      _error = null;
    });
    try {
      final bytes = snapshot.encodeArchive();
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.deviceHealthDebugExport,
        fileName: snapshot.exportFileName,
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (!mounted) return;
      if (saved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.deviceHealthDebugExported(
              saved.scheme == 'file' ? saved.toFilePath() : saved.toString(),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = l10n.deviceHealthDebugExportFailed(error.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _exportingSnapshotId = null);
    }
  }

  Future<void> _importSnapshot() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picked = await pickFileData(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        dialogTitle: l10n.deviceHealthDebugImport,
        loadBytes: true,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Selected file is empty');
      }
      final snapshot = await _store.import(bytes);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final code = snapshot.deviceCode?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.deviceHealthDebugImported(
              code == null || code.isEmpty ? '—' : code,
              snapshot.files.length,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = l10n.deviceHealthDebugImportFailed(error.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceHealthDebugClearAll),
        content: Text(l10n.deviceHealthDebugClearAllDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    if (mounted) setState(() => _snapshots = const []);
  }

  Future<void> _delete(XiaomiHealthRawSnapshot snapshot) async {
    await _store.delete(snapshot.id);
    if (mounted) {
      setState(() {
        _snapshots = _snapshots
            .where((item) => item.id != snapshot.id)
            .toList(growable: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.deviceHealthDebugSnapshots),
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
        sections: [
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: _loading
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                title: Text(l10n.deviceHealthDebugRefresh),
                description: Text(l10n.deviceHealthDebugRefreshDescription),
                enabled: !_loading,
                onPressed: (_) => _load(),
              ),
              SegmentedTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(l10n.deviceHealthDebugImport),
                description: Text(l10n.deviceHealthDebugImportDescription),
                enabled: !_loading,
                onPressed: (_) => _importSnapshot(),
              ),
              SegmentedTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(l10n.deviceHealthDebugClearAll),
                description: Text(l10n.deviceHealthDebugClearAllDescription),
                enabled: _snapshots.isNotEmpty,
                onPressed: (_) => _clearAll(),
              ),
            ],
          ),
          if (_error != null)
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(l10n.deviceHealthLoadFailed),
                  description: Text(_error!),
                  enabled: false,
                ),
              ],
            ),
          SegmentedSection(
            title: Text(l10n.deviceHealthDebugSnapshotList),
            tiles: _snapshots.isEmpty
                ? [
                    SegmentedTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text(l10n.deviceHealthDebugNoSnapshots),
                      description: Text(
                        l10n.deviceHealthDebugSnapshotsDescription,
                      ),
                      enabled: false,
                    ),
                  ]
                : _snapshots.map(_snapshotTile).toList(growable: false),
          ),
        ],
      ),
    );
  }

  AbstractSegmentedTile _snapshotTile(XiaomiHealthRawSnapshot snapshot) {
    final l10n = AppLocalizations.of(context)!;
    final reloading = _reloadingSnapshotId == snapshot.id;
    final exporting = _exportingSnapshotId == snapshot.id;
    final busy = reloading || exporting;
    final currentDevice = ref.watch(deviceManagerProvider).currentDevice;
    // Replay parses the captured bytes locally and writes the snapshot under
    // its original device id. It does not require the wearable to be online,
    // so an offline snapshot must not render a disabled replay button.
    final canReplay = snapshot.files.isNotEmpty;
    final storedDeviceCode = snapshot.deviceCode?.trim();
    final deviceCode = storedDeviceCode?.isNotEmpty == true
        ? storedDeviceCode
        : snapshot.deviceId == currentDevice?.addr
        ? currentDevice?.codename
        : null;
    return SegmentedTile(
      leading: const Icon(Icons.data_object_outlined),
      title: Text(deviceCode == null || deviceCode.isEmpty ? '—' : deviceCode),
      description: Text(
        '${_formatDateTime(snapshot.capturedAt)} · '
        '${l10n.deviceHealthDebugFiles(snapshot.files.length)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: snapshot.files.isEmpty || busy
                ? null
                : () => _export(snapshot),
            icon: exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            tooltip: l10n.deviceHealthDebugExportTooltip,
          ),
          IconButton(
            onPressed: !canReplay || busy ? null : () => _reload(snapshot),
            icon: reloading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay_outlined),
            tooltip: l10n.deviceHealthDebugReload,
          ),
          IconButton(
            onPressed: busy ? null : () => _delete(snapshot),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
