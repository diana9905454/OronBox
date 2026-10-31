import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';

import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/debug_server/debug_server_auth.dart';
import 'package:oronbox/src/debug_server/debug_server_provider.dart';

class DebugServerPage extends ConsumerWidget {
  const DebugServerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(debugServerProvider);
    final controller = ref.read(debugServerProvider.notifier);

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.debugServerTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 24),
        ),
        sections: [
          SegmentedSection(
            title: _SectionTitle(
              icon: Icons.warning_amber_outlined,
              text: l10n.debugServerSecurityNotice,
            ),
            tiles: [
              SegmentedTile.switchTile(
                initialValue: value.isRunning,
                onToggle: (enabled) {
                  if (enabled == true) {
                    controller.start();
                  } else {
                    controller.stop();
                  }
                },
                enabled: !value.isBusy,
                leading: const Icon(Icons.lan_outlined),
                title: Text(l10n.debugServerEnable),
                description: Text(l10n.debugServerEnableDescription),
              ),
            ],
          ),
          if (value.error != null)
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(l10n.debugServerStartFailed),
                  description: Text(value.error!),
                  enabled: false,
                ),
              ],
            ),
          if (value.isRunning && value.info != null) ...[
            SegmentedSection(
              title: Text(l10n.debugServerEndpoint),
              tiles: [
                for (final address in value.addresses)
                  _endpointTile(context, l10n, address),
                SegmentedTile(
                  leading: const Icon(Icons.fingerprint_outlined),
                  title: Text(l10n.debugServerFingerprint),
                  description: SelectableText(value.info!.fingerprint),
                  enabled: false,
                ),
              ],
            ),
            SegmentedSection(
              title: Text(l10n.debugServerPendingClients),
              tiles: [
                if (value.pendingClients.isEmpty)
                  _emptyTile(l10n.debugServerNoPendingClients)
                else
                  for (final client in value.pendingClients)
                    _clientTile(
                      client,
                      actionLabel: l10n.debugServerApprove,
                      onAction: controller.approve,
                      actionIcon: Icons.check_outlined,
                      secondaryActionLabel: l10n.debugServerReject,
                      onSecondaryAction: controller.reject,
                      secondaryActionIcon: Icons.close_outlined,
                    ),
              ],
            ),
            SegmentedSection(
              title: Text(l10n.debugServerAuthorizedClients),
              tiles: [
                if (value.authorizedClients.isEmpty)
                  _emptyTile(l10n.debugServerNoAuthorizedClients)
                else
                  for (final client in value.authorizedClients)
                    _clientTile(
                      client,
                      actionLabel: l10n.debugServerRevoke,
                      onAction: controller.revoke,
                      actionIcon: Icons.person_remove_outlined,
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  SegmentedTile _endpointTile(
    BuildContext context,
    AppLocalizations l10n,
    String address,
  ) {
    final endpoint = '$address/debug/v1/info';
    return SegmentedTile.navigation(
      leading: const Icon(Icons.link_outlined),
      title: SelectableText(endpoint),
      value: IconButton(
        onPressed: () => _copy(context, l10n, endpoint),
        tooltip: MaterialLocalizations.of(context).copyButtonLabel,
        icon: const Icon(Icons.copy_outlined),
      ),
      onPressed: (_) => _copy(context, l10n, endpoint),
    );
  }

  SegmentedTile _clientTile(
    DebugAuthorizedClient client, {
    required String actionLabel,
    required Future<void> Function(String fingerprint) onAction,
    required IconData actionIcon,
    String? secondaryActionLabel,
    Future<void> Function(String fingerprint)? onSecondaryAction,
    IconData? secondaryActionIcon,
  }) {
    return SegmentedTile.navigation(
      leading: const Icon(Icons.computer_outlined),
      title: Text(client.displayName),
      description: SelectableText(client.fingerprint),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secondaryActionLabel != null && secondaryActionIcon != null)
            IconButton(
              onPressed: () => onSecondaryAction!(client.fingerprint),
              tooltip: secondaryActionLabel,
              icon: Icon(secondaryActionIcon),
            ),
          IconButton.filledTonal(
            onPressed: () => onAction(client.fingerprint),
            tooltip: actionLabel,
            icon: Icon(actionIcon),
          ),
        ],
      ),
      onPressed: null,
    );
  }

  SegmentedTile _emptyTile(String text) => SegmentedTile(
    leading: const Icon(Icons.inbox_outlined),
    title: Text(text),
    enabled: false,
  );

  Future<void> _copy(
    BuildContext context,
    AppLocalizations l10n,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.copied)));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}
