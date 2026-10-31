import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

class DeviceInfoPage extends ConsumerStatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  ConsumerState<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends ConsumerState<DeviceInfoPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final manager = ref.read(deviceManagerProvider.notifier);
      try {
        await manager.refreshDeviceData();
      } catch (_) {
        // Saved device metadata is still useful when the watch is disconnected.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final device = state.currentDevice;
    final unavailable = l10n.deviceValueUnavailable;
    String shown(String value) => value.trim().isEmpty ? unavailable : value;
    String shownCodename(String? value) {
      if (value == null || value.trim().isEmpty) return '-';
      return value.startsWith('zepp:')
          ? value.substring('zepp:'.length)
          : value;
    }

    final items = <Widget>[
      if (device != null)
        _InfoGroup(
          title: l10n.deviceInfoGroupDevice,
          children: [
            _InfoRow(label: l10n.fieldName, value: device.name),
            _InfoRow(label: l10n.fieldAddress, value: device.addr),
            _InfoRow(label: l10n.fieldAuthkey, value: device.authkey ?? '-'),
            _InfoRow(
              label: l10n.fieldConnectionType,
              value: device.connectType,
            ),
            _InfoRow(
              label: l10n.fieldCodename,
              value: shownCodename(device.codename),
            ),
          ],
        ),
      if (state.systemInfo != null)
        _InfoGroup(
          title: l10n.deviceInfoGroupSystem,
          children: [
            _InfoRow(
              label: l10n.fieldModel,
              value: shown(state.systemInfo!.model),
            ),
            if (state.systemInfo!.imei.trim().isNotEmpty)
              _InfoRow(label: l10n.fieldImei, value: state.systemInfo!.imei),
            _InfoRow(
              label: l10n.fieldSerial,
              value: shown(state.systemInfo!.serialNumber),
            ),
          ],
        ),
    ];

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(AppLocalizations.of(context)!.deviceAboutTitle),
      ),
      body: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: StyleConstants.sectionSpacing),
        itemBuilder: (context, index) => PageContainer(
          safeArea: false,
          padding: EdgeInsets.fromLTRB(
            StyleConstants.pagePadding,
            index == 0 ? 8 : 0,
            StyleConstants.pagePadding,
            index == items.length - 1
                ? bottomContentPadding(context, extra: 0)
                : 0,
          ),
          child: items[index],
        ),
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.copied),
                    ),
                  );
                },
                child: Text(
                  value,
                  textAlign: TextAlign.start,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
