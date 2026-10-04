import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class DeviceWatchfacesPage extends ConsumerStatefulWidget {
  const DeviceWatchfacesPage({super.key});

  @override
  ConsumerState<DeviceWatchfacesPage> createState() =>
      _DeviceWatchfacesPageState();
}

class _DeviceWatchfacesPageState extends ConsumerState<DeviceWatchfacesPage> {
  bool _loading = false;
  String? _error;

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
      await ref.read(deviceManagerProvider.notifier).fetchWatchfaces();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.watchfaceManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: !ready
          ? Center(child: Text(l10n.deviceNotConnected))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(localizedErrorMessage(l10n, _error)))
          : state.watchfaces.isEmpty
          ? Center(child: Text(l10n.watchfaceManagementNone))
          : PageContainer(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  StyleConstants.pagePadding,
                  8,
                  StyleConstants.pagePadding,
                  16,
                ),
                itemCount: state.watchfaces.length,
                itemBuilder: (context, index) {
                  final watchface = state.watchfaces[index];
                  return SectionCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(watchface.name),
                      subtitle: watchface.isCurrent
                          ? Text(
                              'ID: ${watchface.id} · ${l10n.currentWatchface}',
                            )
                          : Text('ID: ${watchface.id}'),
                      trailing: _WatchfaceActions(
                        watchface: watchface,
                        onRefresh: _refresh,
                      ),
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

class _WatchfaceActions extends StatelessWidget {
  const _WatchfaceActions({required this.watchface, required this.onRefresh});

  final WatchfaceInfo watchface;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, child) {
        return PopupMenuButton<String>(
          onSelected: (value) async {
            final manager = ref.read(deviceManagerProvider.notifier);
            if (value == 'enable') {
              await manager.setWatchface(watchface);
              onRefresh();
            } else if (value == 'uninstall') {
              await manager.uninstallWatchface(watchface);
              onRefresh();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'enable',
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  Text(l10n.enable),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'uninstall',
              enabled: watchface.canRemove,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline),
                  const SizedBox(width: 8),
                  Text(l10n.uninstall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
