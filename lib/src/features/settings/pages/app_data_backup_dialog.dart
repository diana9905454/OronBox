import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

import '../application/app_data_backup.dart';

class BackupExportSelection extends BackupSelection {
  const BackupExportSelection({
    super.settings,
    super.health,
    super.extensions,
    super.devices,
    super.xiaomi,
    super.accounts,
    this.password,
    this.saveToDocuments = true,
  });
  final String? password;
  final bool saveToDocuments;
}

Future<BackupSelection?> showBackupSelectionDialog(
  BuildContext context, {
  AppDataBackup? backup,
}) {
  final l10n = AppLocalizations.of(context)!;
  var settings =
      backup == null || backup.settings.keys.any(backupPreferenceKeys.contains);
  var health = backup == null || backup.activityFiles.isNotEmpty;
  var extensions = backup == null || backup.extensions.isNotEmpty;
  var devices = backup == null || backup.privateData.containsKey('devices');
  var accounts = false;
  var password = '';
  return showDialog<BackupSelection>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        BackupExportSelection buildExportSelection({
          required bool saveToDocuments,
        }) => BackupExportSelection(
          settings: settings,
          health: health,
          extensions: extensions,
          devices: devices,
          accounts: accounts,
          password: password.trim().isEmpty ? null : password.trim(),
          saveToDocuments: saveToDocuments,
        );
        final selection = backup == null
            ? buildExportSelection(saveToDocuments: true)
            : BackupSelection(
                settings: settings,
                health: health,
                extensions: extensions,
                devices: devices,
                accounts: accounts,
              );
        Widget option(
          String title,
          String description,
          bool value,
          bool enabled,
          void Function(bool) changed,
        ) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          value: value,
          onChanged: enabled ? (v) => update(() => changed(v ?? false)) : null,
        );
        return AlertDialog(
          title: Text(
            backup == null ? l10n.appDataBackup : l10n.appDataRestore,
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backup == null
                        ? l10n.appDataSelectBackup
                        : l10n.appDataRestoreDescription,
                  ),
                  option(
                    l10n.appDataSettings,
                    l10n.appDataSettingsDescription,
                    settings,
                    backup == null || backup.settings.isNotEmpty,
                    (v) => settings = v,
                  ),
                  option(
                    l10n.appDataHealth,
                    l10n.appDataHealthDescription,
                    health,
                    backup == null || backup.activityFiles.isNotEmpty,
                    (v) => health = v,
                  ),
                  option(
                    l10n.appDataExtensionSettings,
                    l10n.appDataExtensionSettingsDescription,
                    extensions,
                    backup == null || backup.extensions.isNotEmpty,
                    (v) => extensions = v,
                  ),
                  option(
                    l10n.appDataDeviceKeys,
                    l10n.appDataDeviceKeysDescription,
                    devices,
                    backup == null || backup.privateData.containsKey('devices'),
                    (v) => devices = v,
                  ),
                  option(
                    l10n.appDataXiaomiAccount,
                    l10n.appDataXiaomiAccountDescription,
                    accounts,
                    backup == null ||
                        backup.privateData.containsKey('xiaomi') ||
                        backup.privateData.containsKey('huami') ||
                        backup.settings.keys.any(
                          backupAccountPreferenceKeys.contains,
                        ),
                    (v) => accounts = v,
                  ),
                  if (accounts)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.appDataSensitiveBackup),
                    ),
                  if (backup == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: l10n.exportBackupPasswordOptional,
                          hintText: l10n.exportBackupPasswordPlaceholder,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => password = v,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            if (backup == null)
              TextButton(
                onPressed: selection.any
                    ? () => Navigator.pop(
                        context,
                        buildExportSelection(saveToDocuments: false),
                      )
                    : null,
                child: Text(l10n.backupTargetCustom),
              ),
            FilledButton(
              onPressed: selection.any
                  ? () => Navigator.pop(
                      context,
                      backup == null
                          ? buildExportSelection(saveToDocuments: true)
                          : selection,
                    )
                  : null,
              child: Text(
                backup == null ? l10n.appDataBackup : l10n.appDataRestore,
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<String?> showBackupPasswordDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  var password = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.backupPasswordDialogTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupPasswordDialogMessage),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.autoBackupPassword,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => password = v,
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, password),
          child: Text(l10n.appDataRestore),
        ),
      ],
    ),
  );
}

class RestoreSourceSelection {
  const RestoreSourceSelection.public(this.fileName) : pickExternal = false;
  const RestoreSourceSelection.external()
    : fileName = null,
      pickExternal = true;

  final String? fileName;
  final bool pickExternal;
}

class _ParsedBackupInfo {
  const _ParsedBackupInfo({
    required this.typeLabel,
    required this.formattedTime,
    required this.isAutoBackup,
  });

  final String typeLabel;
  final String formattedTime;
  final bool isAutoBackup;
}

_ParsedBackupInfo _parseBackupFileName(String fileName, AppLocalizations l10n) {
  final autoMatch = RegExp(
    r'^OronBox-AutoBackup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})',
  ).firstMatch(fileName);
  if (autoMatch != null) {
    final formatted =
        '${autoMatch[1]}-${autoMatch[2]}-${autoMatch[3]} ${autoMatch[4]}:${autoMatch[5]}:${autoMatch[6]}';
    return _ParsedBackupInfo(
      typeLabel: l10n.backupTypeAuto,
      formattedTime: formatted,
      isAutoBackup: true,
    );
  }

  final manualMatch = RegExp(
    r'^OronBox-(?:Manual)?Backup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})',
  ).firstMatch(fileName);
  if (manualMatch != null) {
    final formatted =
        '${manualMatch[1]}-${manualMatch[2]}-${manualMatch[3]} ${manualMatch[4]}:${manualMatch[5]}:${manualMatch[6]}';
    return _ParsedBackupInfo(
      typeLabel: l10n.backupTypeManual,
      formattedTime: formatted,
      isAutoBackup: false,
    );
  }

  final legacyMatch = RegExp(r'^OronBox-Backup-(\d+)\.zip$')
      .firstMatch(fileName);
  if (legacyMatch != null) {
    final millis = int.tryParse(legacyMatch[1]!);
    if (millis != null && millis > 1000000000000) {
      final date = DateTime.fromMillisecondsSinceEpoch(millis);
      final formatted =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      return _ParsedBackupInfo(
        typeLabel: l10n.backupTypeManual,
        formattedTime: formatted,
        isAutoBackup: false,
      );
    }
  }

  return _ParsedBackupInfo(
    typeLabel: l10n.appDataBackup,
    formattedTime: '',
    isAutoBackup: false,
  );
}

Future<RestoreSourceSelection?> showPublicBackupPickerDialog(
  BuildContext context,
  List<String> files,
) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<RestoreSourceSelection>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.restoreFromDocumentsTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final fileName in files) ...[
                Builder(
                  builder: (context) {
                    final info = _parseBackupFileName(fileName, l10n);
                    final theme = Theme.of(context);
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pop(
                          context,
                          RestoreSourceSelection.public(fileName),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    info.typeLabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (info.formattedTime.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      info.formattedTime,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                fileName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(
                    context,
                    const RestoreSourceSelection.external(),
                  ),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(l10n.restorePickExternalFile),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}
