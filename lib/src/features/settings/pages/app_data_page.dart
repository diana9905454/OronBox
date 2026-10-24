import 'app_data_backup_dialog.dart';

import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

import '../application/app_extension_backup.dart';

import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/features/devices/health/health_debug_snapshot_store.dart';

import '../application/app_data_inventory.dart';
import '../application/app_data_cleanup.dart';
import '../application/app_data_backup.dart';

import 'package:oronbox/src/app/utils/picked_file.dart';

class AppDataPage extends ConsumerStatefulWidget {
  const AppDataPage({super.key});
  @override
  ConsumerState<AppDataPage> createState() => _AppDataPageState();
}

class _AppDataPageState extends ConsumerState<AppDataPage> {
  List<AppDataUsage> _usage = const [];
  bool _busy = false;
  bool _pendingRecovery = false;
  Future<void> _maintenanceDone = Future.value();
  late final AppExtensionBackupStore _extensions;
  late final AppDataBackupService _backup;
  final _store = HealthDebugSnapshotStore();
  final _log = getLogger('AppDataPage');

  @override
  void initState() {
    super.initState();
    _extensions = AppExtensionBackupStore();
    _backup = AppDataBackupService(
      extensions: _extensions,
      maintenance: _withMaintenance,
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    unawaited(_maintenanceDone.then((_) => _extensions.close()));
    super.dispose();
  }

  Future<T> _withMaintenance<T>(Future<T> Function() action) async {
    final completion = Completer<void>();
    _maintenanceDone = completion.future;
    final host = ref.read(applicationHostProvider);
    try {
      final acquired = await host.execute(
        const OronBoxCommand(method: 'appdata.maintenance.begin'),
      );
      if (!acquired.ok || acquired.value is! String) {
        throw StateError('Unable to acquire data maintenance');
      }
      final token = acquired.value as String;
      var ended = false;
      Future<void> end() async {
        ended = true;
        final released = await host.execute(
          OronBoxCommand(
            method: 'appdata.maintenance.end',
            params: {'token': token},
          ),
        );
        if (!released.ok) {
          throw StateError('Unable to release data maintenance');
        }
      }

      try {
        final lease = await openAppDataDirectory(
          'storage/maintenance/app-data',
        );
        return await lease.exclusive(() async {
          final valid = await host.execute(
            OronBoxCommand(
              method: 'appdata.maintenance.validate',
              params: {'token': token},
            ),
          );
          if (!valid.ok || valid.value != true) {
            throw StateError('Data maintenance ownership changed');
          }
          try {
            return await action();
          } finally {
            await end();
          }
        });
      } finally {
        if (!ended) await end();
      }
    } finally {
      completion.complete();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
    });
    try {
      final usage = await collectAppDataInventory();
      final pending = await _backup.hasPendingRecovery;
      if (mounted) {
        setState(() {
          _usage = usage;
          _pendingRecovery = pending;
        });
      }
    } catch (error, stack) {
      _log.warning('Application data inventory failed', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanup({AppDataCategory? category}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _withMaintenance(
        category == null
            ? cleanupApplicationCache
            : () => cleanupApplicationDataCategory(category),
      );
      if (mounted) _message(l10n.appDataCacheCleared);
    } catch (error, stack) {
      _log.warning('Application cache cleanup failed', error, stack);
      if (mounted) _message(l10n.appDataUpdateFailed);
    } finally {
      if (mounted) await _refresh();
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final bytes = await _store.exportCollection();
      if (!mounted) return;
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.appDataExportSnapshots,
        fileName:
            'OronBox-Activity-Files-${DateTime.now().millisecondsSinceEpoch}.zip',
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (mounted && saved != null) {
        appScaffoldMessengerOf(context)
            .showSnackBar(SnackBar(content: Text(l10n.appDataExported)));
      }
    } catch (error, stack) {
      _log.warning('Health snapshot collection export failed', error, stack);
      if (mounted) {
        appScaffoldMessengerOf(context).showSnackBar(
          SnackBar(
            content: Text(
              error is SnapshotArchiveTooLarge
                  ? l10n.appDataArchiveTooLarge
                  : l10n.appDataExportFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async {
    final selection = await showBackupSelectionDialog(context);
    if (selection == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final bytes = await _backup.export(selection: selection);
      if (!mounted) return;
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.appDataBackup,
        fileName: 'OronBox-Backup-${DateTime.now().millisecondsSinceEpoch}.zip',
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (mounted && saved != null) _message(l10n.appDataExported);
    } catch (error, stack) {
      _log.warning('Application backup export failed', error, stack);
      if (mounted) _message(l10n.appDataExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      appScaffoldMessengerOf(context)
          .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final picked = await pickFileData(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        dialogTitle: l10n.appDataRestore,
        maxBytes: 128 * 1024 * 1024,
        loadBytes: true,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes == null) return;
      final backup = await _backup.inspect(bytes);
      if (!mounted) return;
      final selection = await showBackupSelectionDialog(
        context,
        backup: backup,
      );
      if (selection == null || !mounted) return;
      await _backup.restore(
        AppDataBackup(
          selection.settings ? backup.settings : const {},
          selection.health ? backup.health : const {},
          extensions: selection.extensions ? backup.extensions : const {},
          privateData: {
            if (selection.devices) 'devices': backup.privateData['devices'],
            if (selection.xiaomi) 'xiaomi': backup.privateData['xiaomi'],
          },
        ),
      );
      if (mounted) _message(l10n.appDataRestored);
    } catch (error, stack) {
      _log.warning('Application backup restore failed', error, stack);
      if (mounted) {
        _message(
          error is PickedFileTooLarge
              ? l10n.appDataArchiveTooLarge
              : error is ExtensionBackupTargetMissing
              ? l10n.appDataExtensionMissing
              : l10n.appDataRestoreFailed,
        );
      }
    } finally {
      if (mounted) await _refresh();
    }
  }

  Future<void> _recover() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appDataRecover),
        content: Text(l10n.appDataRecoverDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.appDataRecover),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backup.recover();
      if (mounted) _message(l10n.appDataRestored);
    } catch (error, stack) {
      _log.warning('Application backup rollback failed', error, stack);
      if (mounted) {
        _message(
          error is PickedFileTooLarge
              ? l10n.appDataArchiveTooLarge
              : error is ExtensionBackupTargetMissing
              ? l10n.appDataExtensionMissing
              : l10n.appDataRestoreFailed,
        );
      }
    } finally {
      if (mounted) await _refresh();
    }
  }

  Future<void> _confirmCategoryCleanup(AppDataCategory category) async {
    final removable = {
      AppDataCategory.health,
      AppDataCategory.snapshots,
      AppDataCategory.cache,
      AppDataCategory.images,
      AppDataCategory.downloads,
      AppDataCategory.models,
      AppDataCategory.documents,
    };
    if (!removable.contains(category)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appDataClearCategoryTitle(_title(category, l10n))),
        content: Text(switch (category) {
          AppDataCategory.health => l10n.appDataClearHealthDescription,
          AppDataCategory.snapshots => l10n.appDataClearRawDescription,
          AppDataCategory.models => l10n.appDataClearModelsDescription,
          _ => l10n.appDataClearCachedCategoryDescription,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _cleanup(category: category);
  }

  String _title(AppDataCategory category, AppLocalizations l10n) =>
      switch (category) {
        AppDataCategory.health => l10n.appDataHealth,
        AppDataCategory.snapshots => l10n.deviceHealthDebugSnapshots,
        AppDataCategory.plugins => l10n.appDataPlugins,
        AppDataCategory.zeppos => l10n.appDataZeppos,
        AppDataCategory.logs => l10n.settingsAboutLogs,
        AppDataCategory.recovery => l10n.appDataRecovery,
        AppDataCategory.downloads => l10n.appDataDownloads,
        AppDataCategory.cache => l10n.appDataPluginCache,
        AppDataCategory.images => l10n.appDataImageCache,
        AppDataCategory.models => l10n.appDataModels,
        AppDataCategory.tasks => l10n.appDataTasks,
        AppDataCategory.documents => l10n.appDataDocuments,
      };

  String _description(AppDataCategory category, AppLocalizations l10n) =>
      switch (category) {
        AppDataCategory.health => l10n.appDataHealthDescription,
        AppDataCategory.snapshots => l10n.appDataSnapshotDescription,
        AppDataCategory.plugins => l10n.appDataPluginDescription,
        AppDataCategory.zeppos => l10n.appDataZepposDescription,
        AppDataCategory.logs => l10n.appDataLogsDescription,
        AppDataCategory.recovery => l10n.appDataRecoveryDescription,
        AppDataCategory.downloads => l10n.appDataDownloadsDescription,
        AppDataCategory.cache => l10n.appDataPluginCacheDescription,
        AppDataCategory.images => l10n.appDataImagesDescription,
        AppDataCategory.models => l10n.appDataModelsDescription,
        AppDataCategory.tasks => l10n.appDataTasksDescription,
        AppDataCategory.documents => l10n.appDataDocumentsDescription,
      };

  Text _descriptionText(String text) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleUsage = _usage
        .where((usage) => (usage.bytes ?? 0) > 0)
        .toList();
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.appDataTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        sections: [
          if (visibleUsage.isNotEmpty)
            SegmentedSection(
              tiles: [
                for (final usage in visibleUsage)
                  SegmentedTile(
                    title: Text(_title(usage.category, l10n)),
                    description: _descriptionText(
                      _description(usage.category, l10n),
                    ),
                    trailing: Text(
                      usage.bytes == null ? '—' : _size(usage.bytes!),
                    ),
                    enabled: !_busy,
                    onPressed: (_) => _confirmCategoryCleanup(usage.category),
                  ),
              ],
            ),
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(l10n.appDataBackup),
                description: _descriptionText(l10n.appDataBackupDescription),
                enabled: !_busy && !_pendingRecovery,
                onPressed: (_) => _exportBackup(),
              ),
              SegmentedTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text(l10n.appDataRestore),
                description: _descriptionText(l10n.appDataImportDescription),
                enabled: !_busy && !_pendingRecovery,
                onPressed: (_) => _restoreBackup(),
              ),
              if (_pendingRecovery)
                SegmentedTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.appDataRecover),
                  description: _descriptionText(l10n.appDataRecoveryPending),
                  enabled: !_busy,
                  onPressed: (_) => _recover(),
                ),
            ],
          ),
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(l10n.appDataClearCache),
                description: _descriptionText(
                  l10n.appDataClearCacheDescription,
                ),
                enabled: !_busy,
                onPressed: (_) => _cleanup(),
              ),
              SegmentedTile.navigation(
                leading: const Icon(Icons.data_object),
                title: Text(l10n.deviceHealthDebugSnapshots),
                description: _descriptionText(l10n.appDataManageSnapshots),
                enabled: !_busy,
                onPressed: (_) async {
                  await context.push('/devices/velaos-health/debug');
                  if (mounted) await _refresh();
                },
              ),
              SegmentedTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(l10n.appDataExportSnapshots),
                description: _descriptionText(
                  l10n.appDataExportSnapshotsDescription,
                ),
                enabled:
                    !_busy &&
                    _usage.any(
                      (item) =>
                          item.category == AppDataCategory.snapshots &&
                          (item.bytes ?? 0) > 0,
                    ),
                onPressed: (_) => _export(),
              ),
              SegmentedTile.navigation(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.settingsAboutLogs),
                description: _descriptionText(
                  l10n.settingsAboutLogsDescription,
                ),
                onPressed: (_) => context.push('/settings/logs'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
