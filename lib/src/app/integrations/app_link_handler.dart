import 'package:oronbox/src/features/devices/widgets/device_import_dialog.dart';

import 'dart:async';

import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/window/desktop_window.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/devices/services/device_share_link.dart';

final initialDeepLinksProvider = Provider<List<String>>((ref) => const []);

class AppLinkHandler extends ConsumerStatefulWidget {
  const AppLinkHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLinkHandler> createState() => _AppLinkHandlerState();
}

/// Backwards compatibility alias
typedef DeviceDeepLinkHandler = AppLinkHandler;

class _AppLinkHandlerState extends ConsumerState<AppLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  final Set<String> _handledLinks = {};
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<List<String>>? _launchArgumentsSubscription;
  bool _handledInitialLinks = false;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri.toString());
    });
    _launchArgumentsSubscription = primaryLaunchArguments.listen((arguments) {
      for (final argument in arguments) {
        unawaited(_handleLink(argument));
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _launchArgumentsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialLinks) return;
    _handledInitialLinks = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      for (final link in ref.read(initialDeepLinksProvider)) {
        if (await _handleLink(link)) {
          return;
        }
      }
      final initialLink = await _appLinks.getInitialLinkString();
      if (initialLink != null) {
        await _handleLink(initialLink);
      }
    });
  }

  Future<bool> _handleLink(String link) async {
    if (!_handledLinks.add(link)) return false;
    final uri = Uri.tryParse(link);
    if (uri != null) {
      final handled = await _handleBandBbsCallback(uri);
      if (handled) return true;
    }
    final device = DeviceShareLink.parse(link);
    if (device == null) return false;
    await _showDeviceDialog(device);
    return true;
  }

  Future<bool> _handleBandBbsCallback(Uri uri) async {
    try {
      final handled = await ref
          .read(hostAccountsProvider.notifier)
          .handleBandBbsCallback(uri);
      if (!handled || !mounted) return handled;
      if (kIsWeb && uri.queryParameters['oauth'] == 'bandbbs') {
        context.go(uri.path.isEmpty ? '/' : uri.path);
      }
      final l10n = AppLocalizations.of(context)!;
      final state = ref.read(hostAccountsProvider).bandbbs;
      appScaffoldMessengerOf(context).showSnackBar(
        SnackBar(
          content: Text(
            state.isSignedIn
                ? l10n.settingsAccountBandBbsSignedIn
                : l10n.settingsAccountBandBbsLoginFailed,
          ),
        ),
      );
      return true;
    } catch (_) {
      if (!mounted) return true;
      final l10n = AppLocalizations.of(context)!;
      appScaffoldMessengerOf(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountBandBbsLoginFailed)),
      );
      return true;
    }
  }

  Future<void> _showDeviceDialog(MiWearState device) =>
      showSharedDeviceImportDialog(context, ref, device);

  @override
  Widget build(BuildContext context) => widget.child;
}
