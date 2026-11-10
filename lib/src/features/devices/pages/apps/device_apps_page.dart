import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_setting_viewer_page.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class DeviceAppsPage extends ConsumerStatefulWidget {
  const DeviceAppsPage({super.key});

  @override
  ConsumerState<DeviceAppsPage> createState() => _DeviceAppsPageState();
}

class _DeviceAppsPageState extends ConsumerState<DeviceAppsPage> {
  bool _loading = false;
  String? _error;
  bool _showSystemApps = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(deviceManagerProvider.notifier).fetchApps();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppInfo> _filterApps(List<AppInfo> apps) {
    if (_showSystemApps) return apps;
    return apps
        .where((app) => !app.packageName.startsWith('com.xiaomi.miwear.'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final displayedApps = _filterApps(state.apps);

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.appManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: l10n.refresh,
          ),
          IconButton(
            icon: Icon(
              _showSystemApps
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () => setState(() => _showSystemApps = !_showSystemApps),
            tooltip: l10n.appManagementShowSystemApps,
          ),
        ],
      ),
      body: !ready
          ? EmptyStateView(
              icon: Icons.bluetooth_disabled_outlined,
              title: l10n.deviceNotConnected,
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorStateView(
              message: localizedErrorMessage(l10n, _error),
              onRetry: _refresh,
            )
          : displayedApps.isEmpty
          ? EmptyStateView(
              icon: Icons.apps_outlined,
              title: l10n.appManagementNone,
            )
          : PageContainer(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  StyleConstants.pagePadding,
                  8,
                  StyleConstants.pagePadding,
                  bottomContentPadding(context, extra: 16),
                ),
                itemCount: displayedApps.length,
                itemBuilder: (context, index) {
                  final app = displayedApps[index];
                  return SectionCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(app.appName),
                      subtitle: Text(app.packageName),
                      trailing: _AppActions(app: app, onRefresh: _refresh),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: StyleConstants.cardSpace),
              ),
            ),
    );
  }
}

class _AppActions extends StatelessWidget {
  const _AppActions({required this.app, required this.onRefresh});

  final AppInfo app;
  final VoidCallback onRefresh;

  int? get _zeppAppId {
    final value = app.packageName.toLowerCase();
    if (!value.startsWith('0x')) return null;
    return int.tryParse(value.substring(2), radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appId = _zeppAppId;

    return Consumer(
      builder: (context, ref, child) {
        return FutureBuilder<bool>(
          future: appId == null
              ? Future.value(false)
              : ZeppOsAppSideStorage().settingExists(appId),
          builder: (context, snapshot) => PopupMenuButton<String>(
            onSelected: (value) async {
              final manager = ref.read(deviceManagerProvider.notifier);
              try {
                switch (value) {
                  case 'open':
                    await manager.openApp(app);
                  case 'uninstall':
                    await manager.uninstallApp(app);
                    onRefresh();
                  case 'settings':
                    await showZeppOsAppSettings(
                      context,
                      appId: appId!,
                      title: app.appName,
                    );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizedErrorMessage(l10n, e))),
                );
              }
            },
            itemBuilder: (context) => [
              if (snapshot.data == true)
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.tune),
                      SizedBox(width: 8),
                      Text(l10n.settingsTab),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new),
                    const SizedBox(width: 8),
                    Text(l10n.open),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'uninstall',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline),
                    const SizedBox(width: 8),
                    Text(l10n.uninstall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
