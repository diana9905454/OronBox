import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

import '../application/app_data_backup.dart';

Future<BackupSelection?> showBackupSelectionDialog(
  BuildContext context, {
  AppDataBackup? backup,
}) {
  final l10n = AppLocalizations.of(context)!;
  var settings = backup == null || backup.settings.isNotEmpty;
  var health = backup == null || backup.activityFiles.isNotEmpty;
  var extensions = backup == null || backup.extensions.isNotEmpty;
  var devices = false;
  var xiaomi = false;
  return showDialog<BackupSelection>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final selection = BackupSelection(
          settings: settings,
          health: health,
          extensions: extensions,
          devices: devices,
          xiaomi: xiaomi,
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
                    xiaomi,
                    backup == null || backup.privateData.containsKey('xiaomi'),
                    (v) => xiaomi = v,
                  ),
                  if (devices || xiaomi)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.appDataSensitiveBackup),
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
            FilledButton(
              onPressed: selection.any
                  ? () => Navigator.pop(context, selection)
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
