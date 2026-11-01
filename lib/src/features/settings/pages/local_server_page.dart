import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';

import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/local_server/local_server_protocol.dart';
import 'package:oronbox/src/local_server/local_server_provider.dart';

class LocalServerPage extends ConsumerWidget {
  const LocalServerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(localServerProvider);
    final controller = ref.read(localServerProvider.notifier);

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.localServerTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            title: _SectionTitle(
              icon: Icons.warning_amber_outlined,
              text: l10n.localServerSecurityNotice,
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
                title: Text(l10n.localServerEnable),
                description: Text(l10n.localServerEnableDescription),
              ),
            ],
          ),
          if (value.error != null)
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(l10n.localServerStartFailed),
                  description: Text(value.error!),
                  enabled: false,
                ),
              ],
            ),
          if (value.isRunning && value.info != null) ...[
            SegmentedSection(
              title: Text(l10n.localServerEndpoint),
              tiles: [
                for (final address in value.addresses)
                  _endpointTile(context, l10n, address),
                SegmentedTile(
                  leading: const Icon(Icons.fingerprint_outlined),
                  title: Text(l10n.localServerFingerprint),
                  description: SelectableText(value.info!.fingerprint),
                  enabled: false,
                ),
              ],
            ),
            SegmentedSection(
              title: Text(l10n.localServerPendingClients),
              tiles: [
                if (value.pendingPairings.isEmpty)
                  _emptyTile(l10n.localServerNoPendingClients)
                else
                  for (final pairing in value.pendingPairings)
                    _pairingTile(
                      pairing,
                      actionLabel: l10n.localServerApprove,
                      onAction: controller.approvePairing,
                      actionIcon: Icons.check_outlined,
                      secondaryActionLabel: l10n.localServerReject,
                      onSecondaryAction: controller.rejectPairing,
                      secondaryActionIcon: Icons.close_outlined,
                    ),
              ],
            ),
            SegmentedSection(
              title: Text(l10n.localServerAuthorizedClients),
              tiles: [
                if (value.authorizedClients.isEmpty)
                  _emptyTile(l10n.localServerNoAuthorizedClients)
                else
                  for (final client in value.authorizedClients)
                    _clientTile(
                      client,
                      actionLabel: l10n.localServerRevoke,
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
    final endpoint = '$address/v1/info';
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

  SegmentedTile _pairingTile(
    LocalServerPairingRequest pairing, {
    required String actionLabel,
    required Future<void> Function(String pairingId) onAction,
    required IconData actionIcon,
    String? secondaryActionLabel,
    Future<void> Function(String pairingId)? onSecondaryAction,
    IconData? secondaryActionIcon,
  }) {
    return SegmentedTile.navigation(
      leading: const Icon(Icons.phonelink_ring_outlined),
      title: Text(pairing.clientName),
      description: SelectableText(pairing.fingerprint),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secondaryActionLabel != null && secondaryActionIcon != null)
            IconButton(
              onPressed: () => onSecondaryAction!(pairing.pairingId),
              tooltip: secondaryActionLabel,
              icon: Icon(secondaryActionIcon),
            ),
          IconButton.filledTonal(
            onPressed: () => onAction(pairing.pairingId),
            tooltip: actionLabel,
            icon: Icon(actionIcon),
          ),
        ],
      ),
      onPressed: null,
    );
  }

  SegmentedTile _clientTile(
    LocalAuthorizedClient client, {
    required String actionLabel,
    required Future<void> Function(String fingerprint) onAction,
    required IconData actionIcon,
  }) {
    return SegmentedTile.navigation(
      leading: const Icon(Icons.computer_outlined),
      title: Text(client.displayName),
      description: SelectableText(client.fingerprint),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
