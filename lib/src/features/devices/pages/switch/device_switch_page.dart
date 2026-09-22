import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/models/device.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/domain/device_connection_endpoint.dart';
import 'package:oronbox/src/features/devices/utils/device_address.dart';
import 'package:oronbox/src/features/devices/widgets/device_connection_text.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_fitness_logo.dart';
import 'package:oronbox/src/features/devices/services/device_share_link.dart';
import 'package:oronbox/src/features/devices/providers/pending_shared_device_provider.dart';
import 'package:oronbox/src/features/settings/pages/about_software_page.dart';
import 'package:oronbox/src/features/settings/pages/settings_page.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

List<BTDeviceInfo> _visibleScannedDevices(DeviceManagerState state) {
  final visible = <BTDeviceInfo>[];
  final seenZeppDevices = <String>{};
  final scans = [...state.scannedDevices]
    ..sort((a, b) {
      final aBle = a.connectType.toLowerCase() == ConnectType.ble.name ? 0 : 1;
      final bBle = b.connectType.toLowerCase() == ConnectType.ble.name ? 0 : 1;
      return aBle.compareTo(bBle);
    });

  // CoreBluetooth exposes a macOS UUID, while VelaOS SPP requires the
  // classic address returned by the native inquiry. Once that classic result
  // exists, hide the UUID duplicate so the user cannot select the wrong
  // transport. Keep this platform-specific because Android can expose a
  // usable BLE address directly.
  final macClassicXiaomi = defaultTargetPlatform == TargetPlatform.macOS
      ? scans
            .where(
              (scan) => scan.connectType.toLowerCase() == ConnectType.spp.name,
            )
            .map((scan) => normalizeXiaomiWearableIdentity(scan.name))
            .whereType<XiaomiWearableIdentity>()
            .map((identity) => identity.codename)
            .toSet()
      : const <String>{};

  for (final scan in scans) {
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        scan.connectType.toLowerCase() == ConnectType.ble.name) {
      final identity = normalizeXiaomiWearableIdentity(scan.name);
      if (identity != null && macClassicXiaomi.contains(identity.codename)) {
        continue;
      }
    }
    final scanIdentity = zeppOsDeviceForBluetoothName(scan.name);
    final alreadyPaired = state.pairedDevices.any((paired) {
      if (deviceAddressEquals(scan.addr, paired.addr)) return true;
      final pairedIdentity = zeppOsDeviceForBluetoothName(paired.name);
      return scanIdentity != null && pairedIdentity?.id == scanIdentity.id;
    });
    if (alreadyPaired) continue;
    if (scanIdentity != null && !seenZeppDevices.add(scanIdentity.id)) continue;
    visible.add(scan);
  }
  return visible;
}

class DeviceSwitchPage extends ConsumerStatefulWidget {
  const DeviceSwitchPage({super.key});

  @override
  ConsumerState<DeviceSwitchPage> createState() => _DeviceSwitchPageState();
}

class _DeviceSwitchPageState extends ConsumerState<DeviceSwitchPage> {
  String? _lastErrorToast;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted && !kIsWeb) {
        ref.read(deviceManagerProvider.notifier).startBluetoothScan();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = ref.read(pendingSharedDeviceProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingSharedDeviceProvider.notifier).set(null);
        _showPendingDeviceDialog(pending);
      });
    }
  }

  Future<void> _showPendingDeviceDialog(MiWearState device) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(deviceManagerProvider.notifier).importSharedDevice(device);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deviceActionsShareQR),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name),
            const SizedBox(height: 4),
            Text(
              device.addr,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.deviceConnect),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final currentAddr = state.protocolState == proto.ProtocolState.ready
        ? state.currentDevice?.addr
        : null;

    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      if (next.error == null) _lastErrorToast = null;
      final wasConnecting = previous?.connecting ?? false;
      final isReady = next.protocolState == proto.ProtocolState.ready;
      final connectedTarget = next.connectionTargetAddr;
      final justBecameReady =
          isReady &&
          wasConnecting &&
          !next.connecting &&
          connectedTarget != null &&
          previous?.connectionTargetAddr == connectedTarget &&
          next.currentDevice?.addr == connectedTarget;
      if (wasConnecting && justBecameReady) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deviceConnected)));
        if (context.mounted) {
          context.pop();
        }
      } else if (next.error != null &&
          !next.connecting &&
          (next.connectStatus == 3 || !wasConnecting) &&
          (next.error != previous?.error ||
              (wasConnecting && next.connectStatus == 3))) {
        // The same failure can surface twice with different wording (daemon
        // state push vs. command wrapper); toast once per distinct message.
        final message = localizedErrorMessage(l10n, next.error);
        if (message != _lastErrorToast) {
          _lastErrorToast = message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    });

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.switchDeviceTitle)),
      body: !kIsWeb
          ? _buildLayout(context, ref, state, currentAddr)
          : _buildWebLayout(context, ref, state, currentAddr),
    );
  }

  Widget _buildLayout(
    BuildContext context,
    WidgetRef ref,
    DeviceManagerState state,
    String? currentAddr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = useWideLayout(constraints.maxWidth);
        final savedList = _SavedDeviceList(
          selectedAddr: currentAddr,
          onComplete: () {
            if (mounted) setState(() {});
          },
          onMiAccountLogin: () =>
              SettingsPage.showMiAccountLoginDialog(context, ref),
          onWearableLogImport: () => showWearableLogSyncDialog(context, ref),
        );
        final scanList = _ScanDeviceList(
          onComplete: () {
            if (mounted) setState(() {});
          },
        );

        if (isWide) {
          return PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              0,
            ),
            child: Column(
              children: [
                AnimatedOpacity(
                  opacity: state.scanning ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const LinearProgressIndicator(minHeight: 2),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ListWrapper(isFirst: true, child: savedList),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: _ListWrapper(isFirst: false, child: scanList),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.fromLTRB(
                    StyleConstants.pagePadding,
                    8,
                    StyleConstants.pagePadding,
                    0,
                  ),
                  child: AnimatedOpacity(
                    opacity: state.scanning ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  child: _SectionHeader(
                    title: AppLocalizations.of(context)!.savedDevices,
                    trailing: state.pairedDevices.isEmpty
                        ? null
                        : _DeviceImportButton(
                            onMiAccountLogin: () =>
                                SettingsPage.showMiAccountLoginDialog(
                                  context,
                                  ref,
                                ),
                            onWearableLogImport: () =>
                                showWearableLogSyncDialog(context, ref),
                          ),
                  ),
                ),
              ),
              _SliverSavedDeviceList(
                selectedAddr: currentAddr,
                onComplete: () {
                  if (mounted) setState(() {});
                },
                onMiAccountLogin: () =>
                    SettingsPage.showMiAccountLoginDialog(context, ref),
                onWearableLogImport: () =>
                    showWearableLogSyncDialog(context, ref),
              ),
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                    vertical: 12,
                  ),
                  child: const Divider(height: 1),
                ),
              ),
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  child: _ScanSectionHeader(
                    onComplete: () {
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
              _SliverScanDeviceList(
                onComplete: () {
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    WidgetRef ref,
    DeviceManagerState state,
    String? currentAddr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = useWideLayout(constraints.maxWidth);
        final savedList = _SavedDeviceList(
          selectedAddr: currentAddr,
          onComplete: () {
            if (mounted) setState(() {});
          },
          onMiAccountLogin: () =>
              SettingsPage.showMiAccountLoginDialog(context, ref),
          onWearableLogImport: () => showWearableLogSyncDialog(context, ref),
        );

        if (isWide) {
          return PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ListWrapper(isFirst: true, child: savedList)),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
                ),
                const Expanded(
                  child: _ListWrapper(isFirst: false, child: _WebSerialHint()),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.fromLTRB(
                    StyleConstants.pagePadding,
                    8,
                    StyleConstants.pagePadding,
                    0,
                  ),
                  child: _SectionHeader(
                    title: AppLocalizations.of(context)!.savedDevices,
                    trailing: state.pairedDevices.isEmpty
                        ? null
                        : _DeviceImportButton(
                            onMiAccountLogin: () =>
                                SettingsPage.showMiAccountLoginDialog(
                                  context,
                                  ref,
                                ),
                            onWearableLogImport: () =>
                                showWearableLogSyncDialog(context, ref),
                          ),
                  ),
                ),
              ),
              if (state.pairedDevices.isEmpty)
                SliverToBoxAdapter(
                  child: PageContainer(
                    safeArea: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: StyleConstants.pagePadding,
                    ),
                    child: Column(
                      children: [
                        _DeviceImportActions(
                          onMiAccountLogin: () =>
                              SettingsPage.showMiAccountLoginDialog(
                                context,
                                ref,
                              ),
                          onWearableLogImport: () =>
                              showWearableLogSyncDialog(context, ref),
                        ),
                        const SizedBox(
                          height: 96,
                          child: _EmptyState(message: ''),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: state.pairedDevices.length * 2 - 1,
                  itemBuilder: (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: StyleConstants.cardSpace);
                    }
                    final device = state.pairedDevices[index ~/ 2];
                    return PageContainer(
                      safeArea: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: StyleConstants.pagePadding,
                      ),
                      child: _DeviceCard(
                        key: ValueKey('web-saved-${device.addr}'),
                        device: device,
                        saved: true,
                      ),
                    );
                  },
                ),
              // 鸿蒙端提示：手环需重新打开配对新设备。
              if (defaultTargetPlatform == TargetPlatform.ohos &&
                  state.pairedDevices.isNotEmpty)
                SliverToBoxAdapter(
                  child: PageContainer(
                    safeArea: false,
                    padding: const EdgeInsets.fromLTRB(
                      StyleConstants.pagePadding,
                      4,
                      StyleConstants.pagePadding,
                      0,
                    ),
                    child: Text(
                      '鸿蒙可能需要在手环上面重新打开配对新设备',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                    vertical: 12,
                  ),
                  child: const Divider(height: 1),
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: PageContainer(
                  safeArea: false,
                  padding: EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  child: _WebSerialHint(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListWrapper extends StatelessWidget {
  const _ListWrapper({required this.child, required this.isFirst});

  final Widget child;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isFirst ? 0 : 20, right: isFirst ? 20 : 0),
      child: child,
    );
  }
}

class _WebSerialHint extends StatelessWidget {
  const _WebSerialHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cable, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            l10n.webSerialTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.webSerialHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showWebSerialConnectDialog(context),
            icon: const Icon(Icons.link),
            label: Text(l10n.deviceConnect),
          ),
        ],
      ),
    );
  }

  Future<void> _showWebSerialConnectDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context, listen: false);
    final authController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.webSerialConnectDialogTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.webSerialConnectDialogHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: authController,
                  decoration: InputDecoration(
                    labelText: l10n.authkeyPrompt,
                    hintText: l10n.authkeyPlaceholder,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final authKey = authController.text.trim();
                if (authKey.isEmpty) {
                  return;
                }
                final saved = _buildWebSerialSavedDevice(authKey: authKey);
                Navigator.of(context).pop();
                final manager = container.read(deviceManagerProvider.notifier);
                await manager.connect(
                  saved.addr,
                  saved.name,
                  authKey,
                  connectType: saved.connectType,
                );
              },
              child: Text(l10n.deviceConnect),
            ),
          ],
        );
      },
    );
    authController.dispose();
  }

  MiWearState _buildWebSerialSavedDevice({required String authKey}) {
    final addr = _webSerialStorageId(authKey);
    return MiWearState(
      name: 'Web Serial',
      addr: addr,
      connectType: ConnectType.spp.name,
      authkey: authKey,
      disconnected: true,
    );
  }

  String _webSerialStorageId(String authKey) {
    final normalized = authKey.trim().toLowerCase();
    final suffix = normalized.length <= 8
        ? normalized
        : normalized.substring(0, 8);
    return 'web-serial:$suffix';
  }
}

class _DeviceImportActions extends StatelessWidget {
  const _DeviceImportActions({
    required this.onMiAccountLogin,
    required this.onWearableLogImport,
  });

  final VoidCallback onMiAccountLogin;
  final VoidCallback onWearableLogImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_supportsMiAccountDeviceImport)
            _DeviceImportActionCard(
              leading: const MiLogo(),
              title: l10n.deviceSwitchMiAccountImport,
              onTap: onMiAccountLogin,
            ),
          if (_supportsWearableLogDeviceImport)
            _DeviceImportActionCard(
              leading: const XiaomiFitnessLogo(),
              title: l10n.deviceSwitchWearableLogImport,
              onTap: onWearableLogImport,
            ),
        ],
      ),
    );
  }
}

bool get _supportsMiAccountDeviceImport =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };

bool get _supportsWearableLogDeviceImport =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class _DeviceImportButton extends StatelessWidget {
  const _DeviceImportButton({
    required this.onMiAccountLogin,
    required this.onWearableLogImport,
  });

  final VoidCallback onMiAccountLogin;
  final VoidCallback onWearableLogImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_supportsMiAccountDeviceImport && !_supportsWearableLogDeviceImport) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.add),
      tooltip: l10n.add,
      onPressed: () => _showDeviceImportSheet(
        context,
        onMiAccountLogin: onMiAccountLogin,
        onWearableLogImport: onWearableLogImport,
      ),
    );
  }
}

Future<void> _showDeviceImportSheet(
  BuildContext context, {
  required VoidCallback onMiAccountLogin,
  required VoidCallback onWearableLogImport,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.deviceSwitchAddDevice,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _DeviceImportActions(
                onMiAccountLogin: () {
                  Navigator.of(sheetContext).pop();
                  onMiAccountLogin();
                },
                onWearableLogImport: () {
                  Navigator.of(sheetContext).pop();
                  onWearableLogImport();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DeviceImportActionCard extends StatelessWidget {
  const _DeviceImportActionCard({
    required this.leading,
    required this.title,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: SizedBox(
            width: 24,
            height: 32,
            child: Center(child: leading),
          ),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _SavedDeviceList extends ConsumerWidget {
  const _SavedDeviceList({
    required this.selectedAddr,
    required this.onComplete,
    required this.onMiAccountLogin,
    required this.onWearableLogImport,
  });

  final String? selectedAddr;
  final VoidCallback onComplete;
  final VoidCallback onMiAccountLogin;
  final VoidCallback onWearableLogImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final currentAddr = state.currentDevice?.addr;
    final sorted = [...state.pairedDevices]
      ..sort((a, b) {
        final aCurrent = a.addr == currentAddr ? 0 : 1;
        final bCurrent = b.addr == currentAddr ? 0 : 1;
        return aCurrent.compareTo(bCurrent);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.savedDevices,
          hiddenOnMobile: true,
          trailing: sorted.isEmpty
              ? null
              : _DeviceImportButton(
                  onMiAccountLogin: onMiAccountLogin,
                  onWearableLogImport: onWearableLogImport,
                ),
        ),
        if (sorted.isEmpty) ...[
          _DeviceImportActions(
            onMiAccountLogin: onMiAccountLogin,
            onWearableLogImport: onWearableLogImport,
          ),
          const Flexible(
            child: SizedBox(height: 240, child: _EmptyState(message: '')),
          ),
        ] else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final device = sorted[index];
                return _DeviceCard(
                  key: ValueKey('saved-${device.addr}'),
                  device: device,
                  saved: true,
                  onComplete: onComplete,
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: StyleConstants.cardSpace),
            ),
          ),
      ],
    );
  }
}

class _ScanDeviceList extends ConsumerStatefulWidget {
  const _ScanDeviceList({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_ScanDeviceList> createState() => _ScanDeviceListState();
}

class _ScanDeviceListState extends ConsumerState<_ScanDeviceList> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    // Already-paired devices show up on the left; don't list them again here.
    final visibleDevices = _visibleScannedDevices(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.scanAndAdd,
          trailing: IconButton(
            icon: AnimatedRotation(
              turns: state.scanning ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: const Icon(Icons.refresh),
            ),
            onPressed: state.scanning
                ? null
                : () => ref
                      .read(deviceManagerProvider.notifier)
                      .startBluetoothScan(),
            tooltip: l10n.refresh,
          ),
        ),
        if (!state.scanning && visibleDevices.isEmpty)
          const Flexible(
            child: SizedBox(height: 240, child: _EmptyState(message: '')),
          )
        else if (state.scanning && visibleDevices.isEmpty)
          const Flexible(
            child: SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: visibleDevices.length,
              itemBuilder: (context, index) {
                final device = visibleDevices[index];
                return _DeviceCard(
                  key: ValueKey('scan-${device.addr}'),
                  device: MiWearState(
                    name: device.name,
                    addr: device.addr,
                    connectType: device.connectType,
                    disconnected: true,
                  ),
                  saved: false,
                  onComplete: widget.onComplete,
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: StyleConstants.cardSpace),
            ),
          ),
      ],
    );
  }
}

class _SliverSavedDeviceList extends ConsumerWidget {
  const _SliverSavedDeviceList({
    required this.selectedAddr,
    required this.onComplete,
    required this.onMiAccountLogin,
    required this.onWearableLogImport,
  });

  final String? selectedAddr;
  final VoidCallback onComplete;
  final VoidCallback onMiAccountLogin;
  final VoidCallback onWearableLogImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceManagerProvider);
    final currentAddr = state.currentDevice?.addr;
    final sorted = [...state.pairedDevices]
      ..sort((a, b) {
        final aCurrent = a.addr == currentAddr ? 0 : 1;
        final bCurrent = b.addr == currentAddr ? 0 : 1;
        return aCurrent.compareTo(bCurrent);
      });

    if (sorted.isEmpty) {
      return SliverToBoxAdapter(
        child: PageContainer(
          safeArea: false,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: Column(
            children: [
              _DeviceImportActions(
                onMiAccountLogin: onMiAccountLogin,
                onWearableLogImport: onWearableLogImport,
              ),
              const SizedBox(height: 240, child: _EmptyState(message: '')),
            ],
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: sorted.length * 2 - 1,
      itemBuilder: (context, index) {
        if (index.isOdd) {
          return const SizedBox(height: StyleConstants.cardSpace);
        }
        final device = sorted[index ~/ 2];
        return PageContainer(
          safeArea: false,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: _DeviceCard(
            key: ValueKey('saved-${device.addr}'),
            device: device,
            saved: true,
            onComplete: onComplete,
          ),
        );
      },
    );
  }
}

class _ScanSectionHeader extends ConsumerWidget {
  const _ScanSectionHeader({required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    return _SectionHeader(
      title: l10n.scanAndAdd,
      trailing: IconButton(
        icon: AnimatedRotation(
          turns: state.scanning ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: const Icon(Icons.refresh),
        ),
        onPressed: state.scanning
            ? null
            : () =>
                  ref.read(deviceManagerProvider.notifier).startBluetoothScan(),
        tooltip: l10n.refresh,
      ),
    );
  }
}

class _SliverScanDeviceList extends ConsumerStatefulWidget {
  const _SliverScanDeviceList({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_SliverScanDeviceList> createState() =>
      _SliverScanDeviceListState();
}

class _SliverScanDeviceListState extends ConsumerState<_SliverScanDeviceList> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);
    // Already-paired devices show up in the saved list; don't repeat them.
    final visibleDevices = _visibleScannedDevices(state);

    if (!state.scanning && visibleDevices.isEmpty) {
      return SliverToBoxAdapter(
        child: PageContainer(
          safeArea: false,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: const SizedBox(height: 240, child: _EmptyState(message: '')),
        ),
      );
    }
    if (state.scanning && visibleDevices.isEmpty) {
      return SliverToBoxAdapter(
        child: PageContainer(
          safeArea: false,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: visibleDevices.length * 2 - 1,
      itemBuilder: (context, index) {
        if (index.isOdd) {
          return const SizedBox(height: StyleConstants.cardSpace);
        }
        final device = visibleDevices[index ~/ 2];
        return PageContainer(
          safeArea: false,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: _DeviceCard(
            key: ValueKey('scan-${device.addr}'),
            device: MiWearState(
              name: device.name,
              addr: device.addr,
              connectType: device.connectType,
              disconnected: true,
            ),
            saved: false,
            onComplete: widget.onComplete,
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.hiddenOnMobile = false,
  });

  final String title;
  final Widget? trailing;
  final bool hiddenOnMobile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWide = useWideLayout(MediaQuery.sizeOf(context).width);
    if (hiddenOnMobile && !isWide) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SizedBox(
        // Fixed height so a header with a trailing action (scan refresh)
        // and a header without one stay visually aligned.
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({
    super.key,
    required this.device,
    this.saved = false,
    this.onComplete,
  });

  final MiWearState device;
  final bool saved;
  final VoidCallback? onComplete;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _showInput = false;
  bool _showConnectionError = false;
  bool _connectInitiated = false;
  late final TextEditingController _authController;
  late String _connectType;

  @override
  void initState() {
    super.initState();
    _authController = TextEditingController(text: widget.device.authkey ?? '');
    final profile = DeviceRegistry.resolveIdentity(
      name: widget.device.name,
      codename: widget.device.codename,
    );
    _connectType = _initialConnectType(profile);
  }

  @override
  void didUpdateWidget(covariant _DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.addr != widget.device.addr ||
        oldWidget.saved != widget.saved) {
      _showInput = false;
      _showConnectionError = false;
      _authController.text = widget.device.authkey ?? '';
      final profile = DeviceRegistry.resolveIdentity(
        name: widget.device.name,
        codename: widget.device.codename,
      );
      _connectType = _initialConnectType(profile);
    } else if (oldWidget.device.authkey != widget.device.authkey &&
        !_showInput) {
      _authController.text = widget.device.authkey ?? '';
    }
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final authKey = _authController.text;
    final endpoint = _connectionEndpointFor(
      _connectType,
      ref.read(deviceManagerProvider),
    );
    if (endpoint == null) {
      _showMissingEndpoint(_connectType);
      return;
    }
    setState(() {
      _showInput = false;
      _showConnectionError = false;
      _connectInitiated = true;
    });
    await ref
        .read(deviceManagerProvider.notifier)
        .connect(
          endpoint.addr,
          endpoint.name,
          authKey,
          connectType: _connectType,
        );
    if (!mounted) return;
    widget.onComplete?.call();
    if (mounted) {
      final state = ref.read(deviceManagerProvider);
      final connectedThisDevice =
          state.protocolState == proto.ProtocolState.ready &&
          state.currentDevice?.addr == endpoint.addr;
      if (connectedThisDevice) {
        if (context.canPop()) {
          context.pop();
        }
      }
    }
  }

  String _initialConnectType(DeviceProfile profile) {
    if (!widget.saved && profile.id != DeviceRegistry.unknown.id) {
      return profile.preferredConnectType.name;
    }
    final stored = widget.device.connectType.toLowerCase();
    if (stored == ConnectType.ble.name || stored == ConnectType.spp.name) {
      return stored;
    }
    return profile.preferredConnectType.name;
  }

  ({String addr, String name})? _connectionEndpointFor(
    String connectType,
    DeviceManagerState state,
  ) {
    return resolveDeviceConnectionEndpoint(
      device: widget.device,
      saved: widget.saved,
      connectType: connectType,
      scannedDevices: state.scannedDevices,
    );
  }

  void _showMissingEndpoint(String connectType) {
    if (!mounted) return;
    final target = connectType == ConnectType.spp.name ? 'SPP' : 'BLE';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.deviceEndpointUnavailable(target),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(deviceManagerProvider);
    final manager = ref.read(deviceManagerProvider.notifier);
    final connected = manager.connectedAddresses.contains(widget.device.addr);
    final isCurrent = state.currentDevice?.addr == widget.device.addr;
    final isActive =
        isCurrent &&
        state.protocolState == proto.ProtocolState.ready &&
        !widget.device.disconnected;
    final profile = DeviceRegistry.resolveIdentity(
      name: widget.device.name,
      codename: widget.device.codename,
    );
    final isUnrecognized =
        !widget.saved && profile.id == DeviceRegistry.unknown.id;
    final zeppDevice = zeppOsDeviceForBluetoothName(widget.device.name);
    final supportsBtbr =
        zeppDevice != null &&
        zeppDevice.connectionCapability != ZeppOsConnectionCapability.ble;
    final transportLabel = _connectType == ConnectType.spp.name
        ? l10n.deviceTransportSpp
        : l10n.deviceTransportBle;
    final isConnectionTarget = state.connectionTargetAddr == widget.device.addr;
    final isConnectingThisDevice = state.connecting && isConnectionTarget;

    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      final failedThisDevice =
          (previous?.connecting ?? false) &&
          !next.connecting &&
          next.connectStatus == 3 &&
          next.connectionTargetAddr == widget.device.addr;
      if (failedThisDevice && _connectInitiated && mounted) {
        setState(() {
          _showInput = true;
          _showConnectionError = true;
        });
      }
      if (!next.connecting) _connectInitiated = false;
    });

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: connected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: connected && !isActive
                ? () => manager.connect(
                    widget.device.addr,
                    widget.device.name,
                    widget.device.authkey ?? '',
                    connectType: _connectType,
                  )
                : connected
                ? null
                : () => setState(() => _showInput = !_showInput),
            borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isUnrecognized)
                    Icon(
                      Icons.warning_rounded,
                      size: 32,
                      color: colorScheme.onSurfaceVariant,
                    )
                  else
                    SvgPicture.asset(
                      widget.device.illustrationAsset(),
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.device.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          isUnrecognized
                              ? '${formatDeviceAddress(widget.device.addr)}${widget.saved ? ' · $transportLabel' : ''} · '
                                    '${l10n.deviceCompatibilityUnknown}'
                              : widget.saved
                              ? '${formatDeviceAddress(widget.device.addr)} · $transportLabel'
                              : formatDeviceAddress(widget.device.addr),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnectingThisDevice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.cancel,
                          onPressed: () => ref
                              .read(deviceManagerProvider.notifier)
                              .cancelConnect(),
                        ),
                      ],
                    )
                  else if (widget.saved)
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        final manager = ref.read(
                          deviceManagerProvider.notifier,
                        );
                        if (value == 'delete') {
                          await manager.removeDevice(widget.device.addr);
                        } else if (value == 'disconnect') {
                          await manager.disconnect(widget.device.addr);
                        } else if (value == 'share') {
                          await Future.delayed(
                            const Duration(milliseconds: 50),
                          );
                          if (context.mounted) {
                            await _showQrDialog(context, widget.device);
                          }
                        } else if (value == 'connect_ble' ||
                            value == 'connect_btbr') {
                          final selected = value == 'connect_btbr'
                              ? ConnectType.spp.name
                              : ConnectType.ble.name;
                          final endpoint = _connectionEndpointFor(
                            selected,
                            state,
                          );
                          if (endpoint == null) {
                            _showMissingEndpoint(selected);
                            return;
                          }
                          setState(() => _connectType = selected);
                          await manager.connect(
                            endpoint.addr,
                            endpoint.name,
                            widget.device.authkey ?? '',
                            connectType: selected,
                          );
                        }
                        if (mounted) widget.onComplete?.call();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsDelete),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'disconnect',
                          enabled: connected,
                          child: Row(
                            children: [
                              const Icon(Icons.power_off_outlined),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsDisconnect),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          enabled: widget.device.authkey?.isNotEmpty ?? false,
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_2),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsShareQR),
                            ],
                          ),
                        ),
                        if (supportsBtbr) ...[
                          PopupMenuItem(
                            value: 'connect_ble',
                            enabled:
                                !state.connecting &&
                                (widget.device.authkey?.isNotEmpty ?? false),
                            child: Row(
                              children: [
                                Icon(Icons.bluetooth_outlined),
                                SizedBox(width: 8),
                                Text(l10n.deviceConnectBle),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'connect_btbr',
                            enabled:
                                !state.connecting &&
                                (widget.device.authkey?.isNotEmpty ?? false),
                            child: Row(
                              children: [
                                Icon(Icons.cable_outlined),
                                SizedBox(width: 8),
                                Text(l10n.deviceConnectBtClassic),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showInput || isConnectingThisDevice
                ? Padding(
                    padding: isConnectingThisDevice && !_showInput
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          )
                        : const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showInput && supportsBtbr) ...[
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'ble',
                                icon: Icon(Icons.bluetooth_outlined),
                                label: Text('BLE'),
                              ),
                              ButtonSegment(
                                value: 'spp',
                                icon: Icon(Icons.cable_outlined),
                                label: Text('BT Classic'),
                              ),
                            ],
                            selected: {_connectType},
                            onSelectionChanged: state.connecting
                                ? null
                                : (selection) => setState(
                                    () => _connectType = selection.single,
                                  ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_showInput)
                          TextField(
                            controller: _authController,
                            enabled: !state.connecting && !connected,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: l10n.authkeyPrompt,
                              hintText: l10n.authkeyPlaceholder,
                              errorText: _showConnectionError
                                  ? l10n.connectFailed
                                  : null,
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: colorScheme.error,
                                  width: 2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: colorScheme.error,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: state.connecting ? null : _connect,
                              ),
                            ),
                          ),
                        if (isConnectingThisDevice)
                          Text(
                            deviceConnectionPhaseText(
                              l10n,
                              state,
                              fallbackDeviceName: widget.device.name,
                              connectType: _connectType,
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _showQrDialog(BuildContext context, MiWearState device) async {
    final l10n = AppLocalizations.of(context)!;
    var compatibleMode = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final link =
              (compatibleMode
                      ? DeviceShareLink.buildAstroBoxCompatible(device)
                      : DeviceShareLink.build(device))
                  .toString();
          return AlertDialog(
            title: Text(l10n.deviceActionsShareQR),
            content: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    link,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setDialogState(() => compatibleMode = !compatibleMode);
                    },
                    icon: Icon(compatibleMode ? Icons.link : Icons.swap_horiz),
                    label: Text(
                      compatibleMode
                          ? l10n.deviceShareOronBoxCode
                          : l10n.deviceShareAstroBoxCompatibleCode,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.copied)));
                },
                child: Text(l10n.copy),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          if (message != null && message!.isNotEmpty)
            Text(
              message!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
