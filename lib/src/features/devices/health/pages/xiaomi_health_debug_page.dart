import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

class XiaomiHealthDebugPage extends ConsumerStatefulWidget {
  const XiaomiHealthDebugPage({super.key});

  @override
  ConsumerState<XiaomiHealthDebugPage> createState() =>
      _XiaomiHealthDebugPageState();
}

class _XiaomiHealthDebugPageState extends ConsumerState<XiaomiHealthDebugPage> {
  final _log = getLogger('HealthDebugPage');
  List<HealthActivityBatch> _snapshots = const [];
  String? _error;
  String? _exportingSnapshotId;
  bool _loading = false;
  bool _filterCurrentDeviceOnly = true;
  bool get _busy => _loading || _exportingSnapshotId != null;

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
      final snapshots = await HealthStore.listActivityBatches();
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _error = null;
      });
    } catch (error, stack) {
      _log.warning('Health activity operation failed', error, stack);
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.appDataLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(HealthActivityBatch snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _exportingSnapshotId = snapshot.id;
      _error = null;
    });
    try {
      final bytes = await HealthStore.exportActivityBatch(snapshot.id);
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.deviceHealthDebugExport,
        fileName:
            'activity-files-${snapshot.capturedAt.millisecondsSinceEpoch}.zip',
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (!mounted) return;
      if (saved == null) return;
      _log.info(
        'Exported activity files ${snapshot.id} (${snapshot.files.length} files) to $saved',
      );
      appScaffoldMessengerOf(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.deviceHealthDebugExported(
              saved.scheme == 'file' ? saved.toFilePath() : saved.toString(),
            ),
          ),
        ),
      );
    } catch (error, stack) {
      _log.warning('Health activity export failed', error, stack);
      if (mounted) {
        setState(() {
          _error = l10n.appDataExportFailed;
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
      final snapshot = await HealthStore.importActivityBatch(bytes);
      _log.info(
        'Imported activity files ${snapshot.id} for device ${snapshot.deviceId} (${snapshot.files.length} files)',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final code = snapshot.deviceCode?.trim();
      appScaffoldMessengerOf(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.deviceHealthDebugImported(
              code == null || code.isEmpty ? '—' : code,
              snapshot.files.length,
            ),
          ),
        ),
      );
    } catch (error, stack) {
      _log.warning('Health activity import failed', error, stack);
      if (mounted) {
        setState(() {
          _error = l10n.appDataLoadFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(HealthActivityBatch snapshot) async {
    _log.info(
      'Deleting activity files ${snapshot.id} for device ${snapshot.deviceId}',
    );
    await _changeSnapshots(() => HealthStore.deleteActivityBatch(snapshot.id));
  }

  Future<void> _changeSnapshots(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (error, stack) {
      _log.warning('Health snapshot update failed', error, stack);
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.appDataUpdateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentDevice = ref.watch(deviceManagerProvider).currentDevice;
    final currentDeviceId = currentDevice?.addr;
    final visibleSnapshots = _filterCurrentDeviceOnly && currentDeviceId != null
        ? _snapshots.where((s) => s.deviceId == currentDeviceId).toList()
        : _snapshots;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.deviceHealthDebugSnapshots),
        actions: [
          if (currentDeviceId != null && _snapshots.isNotEmpty)
            TextButton(
              onPressed: () => setState(
                () => _filterCurrentDeviceOnly = !_filterCurrentDeviceOnly,
              ),
              child: Text(
                _filterCurrentDeviceOnly
                    ? l10n.all
                    : (currentDevice?.name ??
                          currentDevice?.addr ??
                          l10n.pairedDevices),
              ),
            ),
        ],
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(l10n.deviceHealthDebugImport),
                description: Text(l10n.deviceHealthDebugImportDescription),
                enabled: !_busy,
                onPressed: (_) => _importSnapshot(),
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
            tiles: visibleSnapshots.isEmpty
                ? [
                    CustomSegmentedTile(
                      child: (_) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyStateView(
                          compact: true,
                          icon: Icons.inbox_outlined,
                          title: l10n.deviceHealthDebugNoSnapshots,
                          message: l10n.deviceHealthDebugSnapshotsDescription,
                        ),
                      ),
                    ),
                  ]
                : visibleSnapshots.map(_snapshotTile).toList(growable: false),
          ),
        ],
      ),
    );
  }

  AbstractSegmentedTile _snapshotTile(HealthSnapshotSummary snapshot) {
    final l10n = AppLocalizations.of(context)!;
    final exporting = _exportingSnapshotId == snapshot.id;
    final busy = _busy;
    final storedDeviceCode = snapshot.deviceCode?.trim();
    final deviceCode = storedDeviceCode?.isNotEmpty == true
        ? storedDeviceCode
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
