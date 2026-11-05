import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:segmented_list/segmented_list.dart';

import '../application/app_data_backup.dart';
import '../application/app_data_cleanup.dart';
import '../application/app_data_inventory.dart';
import '../application/app_data_maintenance.dart';
import '../application/app_extension_backup.dart';
import '../application/auto_backup_service.dart';
import '../services/public_backup_storage.dart';
import 'app_data_backup_dialog.dart';
import 'auto_backup_dialog.dart';

class AppDataPage extends ConsumerStatefulWidget {
  const AppDataPage({super.key});
  @override
  ConsumerState<AppDataPage> createState() => _AppDataPageState();
}

class _AppDataPageState extends ConsumerState<AppDataPage> {
  List<AppDataUsage> _usage = const [];
  bool _busy = false;
  bool _exporting = false;
  bool _decrypting = false;
  bool _restoring = false;
  bool _inventoryLoading = true;
  bool _inventoryFailed = false;
  bool _pendingRecovery = false;
  Future<void> _maintenanceDone = Future.value();
  late final AppExtensionBackupStore _extensions;
  late final AppDataBackupService _backup;
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
    try {
      return await runWithAppDataMaintenance(
        ref.read(applicationHostProvider),
        action,
      );
    } finally {
      completion.complete();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _inventoryLoading = true;
      _inventoryFailed = false;
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
    } catch (error) {
      _log.warning('Application data inventory failed', error);
      if (mounted) setState(() => _inventoryFailed = true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _inventoryLoading = false;
        });
      }
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
    } catch (error) {
      _log.warning('Application cache cleanup failed', error);
      if (mounted) _message(l10n.appDataUpdateFailed);
    } finally {
      if (mounted) await _refresh();
    }
  }

  String _formatBackupFileName(DateTime now) {
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return 'OronBox-ManualBackup-$year$month$day-$hour$minute$second.zip';
  }

  Future<void> _exportBackup() async {
    final selection = await showBackupSelectionDialog(context);
    if (selection == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _exporting = true;
    });
    _message(l10n.appDataExporting);
    try {
      final password = selection is BackupExportSelection
          ? selection.password
          : null;
      final saveToDocuments = selection is BackupExportSelection
          ? selection.saveToDocuments
          : true;
      final bytes = await _backup.export(
        selection: selection,
        password: password,
      );
      if (!mounted) return;
      final fileName = _formatBackupFileName(DateTime.now());
      if (saveToDocuments) {
        final path = await savePublicBackupFile(
          fileName: fileName,
          bytes: bytes,
        );
        if (mounted && path != null) {
          _message(l10n.backupSavedToDocuments);
        } else if (mounted) {
          _message(l10n.appDataExportFailed);
        }
      } else {
        final saved = await FilePicker.saveFile(
          dialogTitle: l10n.appDataBackup,
          fileName: fileName,
          mimeType: 'application/zip',
          bytes: bytes,
        );
        if (mounted && saved != null) _message(l10n.appDataExported);
      }
    } catch (error) {
      _log.warning('Application backup export failed', error);
      if (mounted) _message(l10n.appDataExportFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _exporting = false;
        });
      }
    }
  }

  void _message(String text) =>
      appScaffoldMessengerOf(context)
          .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      Uint8List? bytes;
      final publicFiles = await listPublicBackupFiles();
      if (publicFiles.isNotEmpty && mounted) {
        final publicZipFiles = publicFiles
            .where((f) => f.toLowerCase().endsWith('.zip'))
            .toList();
        if (publicZipFiles.isNotEmpty) {
          publicZipFiles.sort((a, b) => b.compareTo(a));
          final choice = await showPublicBackupPickerDialog(
            context,
            publicZipFiles,
          );
          if (choice == null || !mounted) return;
          if (!choice.pickExternal && choice.fileName != null) {
            setState(() => _decrypting = true);
            bytes = await readPublicBackupFile(choice.fileName!);
            if (bytes == null && mounted) {
              _message(l10n.appDataRestoreFailed);
              return;
            }
          }
        }
      }
      if (bytes == null) {
        if (!mounted) return;
        final picked = await pickFileData(
          type: FileType.custom,
          allowedExtensions: const ['zip'],
          dialogTitle: l10n.appDataRestore,
          maxBytes: 512 * 1024 * 1024,
          loadBytes: true,
        );
        if (picked == null) return;
        setState(() => _decrypting = true);
        bytes = await picked.readAsBytes();
        if (bytes == null) return;
      }
      if (!mounted) return;
      AppDataBackup backup;
      try {
        backup = await _backup.inspect(bytes);
      } on ArchivePasswordRequiredException {
        if (mounted) setState(() => _decrypting = false);
        if (!mounted) return;
        final password = await showBackupPasswordDialog(context);
        if (password == null || !mounted) return;
        if (mounted) {
          setState(() => _decrypting = true);
          _message(l10n.appDataDecrypting);
        }
        try {
          backup = await _backup.inspect(bytes, password: password);
        } on ArchiveWrongPasswordException {
          if (mounted) _message(l10n.backupPasswordIncorrect);
          return;
        }
      } on ArchiveWrongPasswordException {
        if (mounted) _message(l10n.backupPasswordIncorrect);
        return;
      }
      if (!mounted) return;
      setState(() => _decrypting = false);
      final selection = await showBackupSelectionDialog(
        context,
        backup: backup,
      );
      if (selection == null || !mounted) return;
      setState(() => _restoring = true);
      _message(l10n.appDataRestoring);
      await _backup.restore(
        AppDataBackup(
          settings: selectBackupSettings(
            backup.settings,
            includeSettings: selection.settings,
            includeAccounts: selection.accountCredentials,
          ),
          activityFiles: selection.health ? backup.activityFiles : const {},
          extensions: selection.extensions ? backup.extensions : const {},
          extensionFiles: selection.extensions
              ? backup.extensionFiles
              : const {},
          privateData: {
            if (selection.devices && backup.privateData.containsKey('devices'))
              'devices': backup.privateData['devices'],
            if (selection.accountCredentials) ...{
              if (backup.privateData.containsKey('xiaomi'))
                'xiaomi': backup.privateData['xiaomi'],
              if (backup.privateData.containsKey('huami'))
                'huami': backup.privateData['huami'],
            },
          },
        ),
      );
      if (mounted) _message(l10n.appDataRestored);
    } catch (error) {
      _log.warning('Application backup restore failed', error);
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
      if (mounted) {
        setState(() {
          _busy = false;
          _decrypting = false;
          _restoring = false;
        });
        await _refresh();
      }
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
    } catch (error) {
      _log.warning('Application backup rollback failed', error);
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
    final dataSections = <Widget>[
      if (_inventoryFailed && _usage.isEmpty)
        CustomSegmentedSection(child: Text(l10n.appDataLoadFailed)),
      if (visibleUsage.isNotEmpty)
        SegmentedSection(
          tiles: [
            for (final usage in visibleUsage)
              SegmentedTile(
                title: Text(_title(usage.category, l10n)),
                description: _descriptionText(
                  _description(usage.category, l10n),
                ),
                trailing: Text(usage.bytes == null ? '—' : _size(usage.bytes!)),
                enabled: !_busy,
                onPressed: (_) => _confirmCategoryCleanup(usage.category),
              ),
          ],
        ),
    ];
    final actionSections = <Widget>[
      SegmentedSection(
        tiles: [
          SegmentedTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.appDataBackup),
            description: _descriptionText(l10n.appDataBackupDescription),
            trailing: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_busy && !_pendingRecovery,
            onPressed: (_) => _exportBackup(),
          ),
          SegmentedTile(
            leading: const Icon(Icons.restore_outlined),
            title: Text(l10n.appDataRestore),
            description: _descriptionText(l10n.appDataImportDescription),
            trailing: (_decrypting || _restoring)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_busy && !_pendingRecovery,
            onPressed: (_) => _restoreBackup(),
          ),
          SegmentedTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.autoBackupTitle),
            description: _descriptionText(
              AutoBackupPreferences.enabled
                  ? l10n.autoBackupStatusDetail(
                      AutoBackupPreferences.intervalValue,
                      _autoBackupUnitLabel(
                        l10n,
                        AutoBackupPreferences.intervalUnit,
                      ),
                      AutoBackupPreferences.retention <= 0
                          ? l10n.autoBackupRetentionUnlimited
                          : l10n.autoBackupRetentionCount(
                              AutoBackupPreferences.retention,
                            ),
                    )
                  : l10n.autoBackupStatusDisabled,
            ),
            enabled: !_busy && !_pendingRecovery,
            onPressed: (_) async {
              final changed = await showAutoBackupConfigDialog(context);
              if (changed == true && mounted) setState(() {});
            },
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
            description: _descriptionText(l10n.appDataClearCacheDescription),
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
          SegmentedTile.navigation(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.settingsAboutLogs),
            description: _descriptionText(l10n.settingsAboutLogsDescription),
            onPressed: (_) => context.push('/settings/logs'),
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.appDataTitle)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList.list(
              children: [
                for (final section in dataSections)
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: StyleConstants.pageMaxWidth,
                      ),
                      child: section,
                    ),
                  ),
              ],
            ),
          ),
          if (_inventoryLoading && _usage.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          SliverPadding(
            padding: EdgeInsets.only(top: dataSections.isEmpty ? 8 : 0),
            sliver: SliverList.list(
              children: [
                for (final section in actionSections)
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: StyleConstants.pageMaxWidth,
                      ),
                      child: section,
                    ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
      ),
    );
  }

  String _autoBackupUnitLabel(AppLocalizations l10n, AutoBackupUnit unit) {
    switch (unit) {
      case AutoBackupUnit.day:
        return l10n.autoBackupUnitDay;
      case AutoBackupUnit.week:
        return l10n.autoBackupUnitWeek;
      case AutoBackupUnit.month:
        return l10n.autoBackupUnitMonth;
    }
  }
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
