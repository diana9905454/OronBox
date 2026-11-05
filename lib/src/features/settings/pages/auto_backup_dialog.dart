import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

import '../application/auto_backup_service.dart';

Future<bool?> showAutoBackupConfigDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  var enabled = AutoBackupPreferences.enabled;
  var intervalValue = AutoBackupPreferences.intervalValue;
  var intervalUnit = AutoBackupPreferences.intervalUnit;
  var retention = AutoBackupPreferences.retention;
  var password = AutoBackupPreferences.password;
  var scopeSettings = AutoBackupPreferences.scopeSettings;
  var scopeHealth = AutoBackupPreferences.scopeHealth;
  var scopeExtensions = AutoBackupPreferences.scopeExtensions;
  var scopeDevices = AutoBackupPreferences.scopeDevices;
  var scopeXiaomi = AutoBackupPreferences.scopeXiaomi;

  final intervalController = TextEditingController(
    text: intervalValue.toString(),
  );
  final retentionController = TextEditingController(text: retention.toString());
  final passwordController = TextEditingController(text: password);
  var obscurePassword = true;

  String unitLabel(AutoBackupUnit unit) {
    switch (unit) {
      case AutoBackupUnit.day:
        return l10n.autoBackupUnitDay;
      case AutoBackupUnit.week:
        return l10n.autoBackupUnitWeek;
      case AutoBackupUnit.month:
        return l10n.autoBackupUnitMonth;
    }
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Widget scopeTile(
          String title,
          String subtitle,
          bool value,
          ValueChanged<bool?> onChanged,
        ) {
          return CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: value,
            onChanged: onChanged,
          );
        }

        return AlertDialog(
          title: Text(l10n.autoBackupTitle),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.autoBackupEnabled),
                    subtitle: Text(l10n.autoBackupDescription),
                    value: enabled,
                    onChanged: (val) => setState(() => enabled = val),
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          l10n.autoBackupInterval,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          l10n.autoBackupEvery,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: TextField(
                            controller: intervalController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v) ?? 1;
                              intervalValue = parsed < 1 ? 1 : parsed;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<AutoBackupUnit>(
                          value: intervalUnit,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final u in AutoBackupUnit.values)
                              DropdownMenuItem(
                                value: u,
                                child: Text(
                                  unitLabel(u),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                          ],
                          onChanged: (u) {
                            if (u != null) setState(() => intervalUnit = u);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          l10n.autoBackupRetentionLabel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 48,
                          child: TextField(
                            controller: retentionController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              hintText: l10n.autoBackupRetentionInputHint,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v) ?? 0;
                              retention = parsed < 0 ? 0 : parsed;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.autoBackupRetentionUnit,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: l10n.exportBackupPasswordOptional,
                        hintText: l10n.exportBackupPasswordPlaceholder,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      onChanged: (v) => password = v,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.autoBackupScope,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    scopeTile(
                      l10n.appDataSettings,
                      l10n.appDataSettingsDescription,
                      scopeSettings,
                      (v) => setState(() => scopeSettings = v ?? true),
                    ),
                    scopeTile(
                      l10n.appDataHealth,
                      l10n.appDataHealthDescription,
                      scopeHealth,
                      (v) => setState(() => scopeHealth = v ?? true),
                    ),
                    scopeTile(
                      l10n.appDataExtensionSettings,
                      l10n.appDataExtensionSettingsDescription,
                      scopeExtensions,
                      (v) => setState(() => scopeExtensions = v ?? true),
                    ),
                    scopeTile(
                      l10n.appDataDeviceKeys,
                      l10n.appDataDeviceKeysDescription,
                      scopeDevices,
                      (v) => setState(() => scopeDevices = v ?? false),
                    ),
                    scopeTile(
                      l10n.appDataXiaomiAccount,
                      l10n.appDataXiaomiAccountDescription,
                      scopeXiaomi,
                      (v) => setState(() => scopeXiaomi = v ?? false),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.autoBackupStorageLocationDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final trimmedPassword = passwordController.text.trim();
                final parsedRetention =
                    int.tryParse(retentionController.text.trim()) ?? 0;
                AutoBackupPreferences.enabled = enabled;
                AutoBackupPreferences.intervalValue = intervalValue;
                AutoBackupPreferences.intervalUnit = intervalUnit;
                AutoBackupPreferences.retention = parsedRetention < 0
                    ? 0
                    : parsedRetention;
                AutoBackupPreferences.passwordProtected =
                    trimmedPassword.isNotEmpty;
                AutoBackupPreferences.password = trimmedPassword;
                AutoBackupPreferences.scopeSettings = scopeSettings;
                AutoBackupPreferences.scopeHealth = scopeHealth;
                AutoBackupPreferences.scopeExtensions = scopeExtensions;
                AutoBackupPreferences.scopeDevices = scopeDevices;
                AutoBackupPreferences.scopeXiaomi = scopeXiaomi;
                Navigator.pop(context, true);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}
