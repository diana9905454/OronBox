import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/device_location_service.dart';

class AppPermissionsPage extends ConsumerStatefulWidget {
  const AppPermissionsPage({super.key});

  @override
  ConsumerState<AppPermissionsPage> createState() => _AppPermissionsPageState();
}

class _AppPermissionsPageState extends ConsumerState<AppPermissionsPage>
    with WidgetsBindingObserver {
  LocationPermission? _permission;
  bool _precise = false;
  bool _serviceEnabled = false;
  bool _supported = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _supported = DeviceLocationService().isSupported;
    if (_supported) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _supported) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final location = OronboxLocation.instance;
      final permission = await location.checkPermission();
      final precise = await location.isPreciseLocationEnabled();
      final enabled = await location.isLocationServiceEnabled();
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _precise = precise;
        _serviceEnabled = enabled;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await OronboxLocation.instance.openLocationSettings();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _requestOrOpenSettings() async {
    try {
      if (_permission == LocationPermission.denied) {
        await OronboxLocation.instance.requestPermission();
      } else {
        await OronboxLocation.instance.openSettings();
      }
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _requestBackgroundPermission() async {
    try {
      if (_permission == LocationPermission.always) {
        await OronboxLocation.instance.openSettings();
      } else {
        await OronboxLocation.instance.requestBackgroundPermission();
      }
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.settingsPermissionsTitle),
      ),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: SegmentedList(
          maxWidth: StyleConstants.pageMaxWidth,
          contentPadding: EdgeInsets.only(
            top: 8,
            bottom: bottomContentPadding(context, extra: 16),
          ),
          sections: [
            if (!_supported)
              SegmentedSection(
                tiles: [
                  SegmentedTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.phoneLocationMobileOnly),
                  ),
                ],
              )
            else if (_failed)
              SegmentedSection(
                tiles: [
                  SegmentedTile(
                    leading: Icon(
                      Icons.warning_amber_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(l10n.phoneLocationUnavailable),
                    onPressed: (_) => _refresh(),
                  ),
                ],
              )
            else
              SegmentedSection(
                title: Text(l10n.phoneLocationPermissionsSection),
                tiles: [
                  SegmentedTile.navigation(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(l10n.phoneLocationServiceEnabled),
                    description: Text(
                      _serviceEnabled
                          ? l10n.phoneLocationEnabledText
                          : l10n.phoneLocationDisabledText,
                    ),
                    onPressed: (_) => _openLocationSettings(),
                  ),
                  SegmentedTile.navigation(
                    leading: const Icon(Icons.gps_fixed_outlined),
                    title: Text(l10n.phoneLocationPreciseTitle),
                    description: Text(
                      _precise
                          ? l10n.phoneLocationPreciseGranted
                          : l10n.phoneLocationPreciseDenied,
                    ),
                    onPressed: (_) => _requestOrOpenSettings(),
                  ),
                  SegmentedTile.navigation(
                    leading: const Icon(Icons.security_outlined),
                    title: Text(l10n.phoneLocationBackgroundTitle),
                    description: Text(
                      _permission == LocationPermission.always
                          ? l10n.phoneLocationBackgroundAlways
                          : (_permission == LocationPermission.whileInUse
                                ? l10n.phoneLocationBackgroundWhileInUse
                                : l10n.phoneLocationBackgroundDenied),
                    ),
                    onPressed: (_) => _requestBackgroundPermission(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
