import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

Future<bool> confirmPluginInstall({
  required BuildContext context,
  required String name,
  required List<String> permissions,
  required bool updating,
  required bool legacy,
}) async {
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            updating
                ? l10n.pluginUpdateConfirmTitle
                : l10n.pluginInstallConfirmTitle,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                if (legacy) ...[
                  const SizedBox(height: 16),
                  const _LegacyWarning(),
                ],
                const SizedBox(height: 16),
                Text(l10n.pluginDeclaredPermissions),
                const SizedBox(height: 8),
                if (permissions.isEmpty)
                  Text(
                    l10n.pluginNoPermissions,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...permissions.map(
                    (permission) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 7),
                          const SizedBox(width: 8),
                          Expanded(child: Text(permission)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(updating ? l10n.update : l10n.install),
            ),
          ],
        ),
      ) ??
      false;
}

class _LegacyWarning extends StatelessWidget {
  const _LegacyWarning();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.history_toggle_off, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pluginLegacyWarningTitle,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: colors.onTertiaryContainer),
                  ),
                  Text(
                    l10n.pluginLegacyWarningMessage,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onTertiaryContainer),
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
