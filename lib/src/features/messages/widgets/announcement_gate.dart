import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class AnnouncementGate extends ConsumerStatefulWidget {
  const AnnouncementGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<AnnouncementGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    final clean = ref.read(appSettingsProvider).clean;
    if (!clean.announcementsEnabled) return;
    final isSignedIn = ref.read(hostAccountsProvider).bandbbs.isSignedIn;
    if (!isSignedIn) return;
    _checking = true;
    try {
      final host = ref.read(applicationHostProvider);
      final result = await host.execute(
        const OronBoxCommand(method: 'announcement.unread'),
      );
      if (!result.ok || !mounted) return;
      final root = (result.value as Map).cast<String, Object?>();
      final items = (root['announcements'] as List? ?? const [])
          .whereType<Map>();
      for (final raw in items) {
        if (!mounted) return;
        final item = raw.cast<String, Object?>();
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(item['title']?.toString() ?? ''),
            content: Text(item['body']?.toString() ?? ''),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.announcementAcknowledge,
                ),
              ),
            ],
          ),
        );
      }
      if (items.isNotEmpty) {
        await host.execute(const OronBoxCommand(method: 'announcement.read'));
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
