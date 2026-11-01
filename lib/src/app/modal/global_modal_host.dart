import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/app/widgets/dialog_helper.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

import 'global_modal_coordinator.dart';
import 'global_modal_models.dart';

class GlobalModalHost extends ConsumerStatefulWidget {
  const GlobalModalHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalModalHost> createState() => _GlobalModalHostState();
}

class _GlobalModalHostState extends ConsumerState<GlobalModalHost> {
  StreamSubscription<CommandEvent>? _commandEventSub;
  bool _isShowing = false;
  String? _currentShowingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initEventListener();
      final active = ref.read(globalModalCoordinatorProvider).activeModal;
      if (active != null) {
        _presentModal(active);
      }
    });
  }

  void _initEventListener() {
    final host = ref.read(applicationHostProvider);
    _commandEventSub = host.events.listen(_handleCommandEvent);
  }

  void _handleCommandEvent(CommandEvent event) {
    if (event.event == XiaomiWifiPasswordRequested.commandEvent) {
      final deviceId = event.data['deviceId']?.toString() ?? '';
      final ssid = event.data['ssid']?.toString() ?? '';
      final authMode = (event.data['authMode'] as num?)?.toInt() ?? 0;
      final frequency = (event.data['frequency'] as num?)?.toInt() ?? 0;

      ref
          .read(globalModalCoordinatorProvider.notifier)
          .showDeviceWifiPrompt(
            deviceId: deviceId,
            ssid: ssid,
            authMode: authMode,
            frequency: frequency,
            onConnect: (password) {
              final host = ref.read(applicationHostProvider);
              unawaited(
                host.execute(
                  OronBoxCommand(
                    method: 'device.xiaomi.wifi.respond',
                    params: {
                      'deviceId': deviceId,
                      'ssid': ssid,
                      'authMode': authMode,
                      'frequency': frequency,
                      'password': password,
                    },
                  ),
                ),
              );
            },
            onCancel: () {
              final host = ref.read(applicationHostProvider);
              unawaited(
                host.execute(
                  OronBoxCommand(
                    method: 'device.xiaomi.wifi.respond',
                    params: {
                      'deviceId': deviceId,
                      'ssid': ssid,
                      'authMode': authMode,
                      'frequency': frequency,
                      'password': '',
                    },
                  ),
                ),
              );
            },
          );
    }
  }

  void _presentModal(GlobalModalRequest modal) {
    if (_isShowing) {
      if (_currentShowingId == modal.id) return;
      final navigator = rootNavigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
      return;
    }

    final context =
        rootNavigatorKey.currentContext ??
        OronBoxDialog.observer.currentContext;
    if (context == null || !context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentModal(modal);
      });
      return;
    }

    _isShowing = true;
    _currentShowingId = modal.id;

    var handled = false;
    void markHandled() {
      handled = true;
    }

    showDialog<void>(
          context: context,
          barrierDismissible: false,
          routeSettings: RouteSettings(name: 'GlobalModal_${modal.id}'),
          builder: (dialogContext) =>
              _buildModalContent(dialogContext, modal, onComplete: markHandled),
        )
        .then((_) {
          if (!handled) {
            _handleDismiss(modal);
          }
          _isShowing = false;
          _currentShowingId = null;
          ref.read(globalModalCoordinatorProvider.notifier).dismiss(modal.id);
        })
        .catchError((_) {
          _isShowing = false;
          _currentShowingId = null;
          ref.read(globalModalCoordinatorProvider.notifier).dismiss(modal.id);
        });
  }

  void _handleDismiss(GlobalModalRequest request) {
    if (request is LocalServerPairingModalRequest) {
      request.onReject();
    } else if (request is DeviceWifiPasswordModalRequest) {
      request.onCancel();
    } else if (request is AnnouncementModalRequest) {
      request.onAcknowledge();
    }
  }

  Widget _buildModalContent(
    BuildContext context,
    GlobalModalRequest request, {
    required VoidCallback onComplete,
  }) {
    if (request is LocalServerPairingModalRequest) {
      return _LocalServerPairingDialog(modal: request, onComplete: onComplete);
    }
    if (request is DeviceWifiPasswordModalRequest) {
      return _DeviceWifiPasswordDialog(modal: request, onComplete: onComplete);
    }
    if (request is AnnouncementModalRequest) {
      return _AnnouncementDialog(modal: request, onComplete: onComplete);
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _commandEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GlobalModalState>(globalModalCoordinatorProvider, (
      previous,
      next,
    ) {
      final active = next.activeModal;
      if (active != null && active.id != _currentShowingId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _presentModal(active);
        });
      }
    });

    return widget.child;
  }
}

class _LocalServerPairingDialog extends StatefulWidget {
  const _LocalServerPairingDialog({
    required this.modal,
    required this.onComplete,
  });

  final LocalServerPairingModalRequest modal;
  final VoidCallback onComplete;

  @override
  State<_LocalServerPairingDialog> createState() =>
      _LocalServerPairingDialogState();
}

class _LocalServerPairingDialogState extends State<_LocalServerPairingDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final modal = widget.modal;

    return AlertDialog(
      title: Text(l10n.localServerPairingTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.localServerPairingDescription(modal.clientName)),
            const SizedBox(height: 14),
            Text(
              l10n.localServerPairingFingerprint,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              _formatFingerprint(modal.fingerprint),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                letterSpacing: 0.6,
                height: 1.4,
              ),
            ),
            if (modal.scopes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.localServerPairingScopes,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                modal.scopes.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? true),
              title: Text(l10n.localServerPairingAlwaysAllow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onComplete();
            widget.modal.onReject();
            Navigator.of(context).pop();
          },
          child: Text(l10n.localServerPairingDeny),
        ),
        FilledButton(
          onPressed: () {
            widget.onComplete();
            widget.modal.onApprove(_remember);
            Navigator.of(context).pop();
          },
          child: Text(l10n.localServerPairingAllow),
        ),
      ],
    );
  }
}

class _DeviceWifiPasswordDialog extends StatefulWidget {
  const _DeviceWifiPasswordDialog({
    required this.modal,
    required this.onComplete,
  });

  final DeviceWifiPasswordModalRequest modal;
  final VoidCallback onComplete;

  @override
  State<_DeviceWifiPasswordDialog> createState() =>
      _DeviceWifiPasswordDialogState();
}

class _DeviceWifiPasswordDialogState extends State<_DeviceWifiPasswordDialog> {
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onComplete();
    widget.modal.onConnect(_passwordController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modal = widget.modal;

    return AlertDialog(
      title: Text(l10n.xiaomiWifiPasswordRequestTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.xiaomiWifiPasswordRequestMessage(modal.ssid)),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.wifiPasswordInputPlaceholder,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onComplete();
            widget.modal.onCancel();
            Navigator.of(context).pop();
          },
          child: Text(l10n.wifiCancelButton),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.wifiConnectButton)),
      ],
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.modal, required this.onComplete});

  final AnnouncementModalRequest modal;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(modal.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: SingleChildScrollView(child: SelectableText(modal.body)),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            onComplete();
            modal.onAcknowledge();
            Navigator.of(context).pop();
          },
          child: Text(l10n.announcementAcknowledge),
        ),
      ],
    );
  }
}

String _formatFingerprint(String hex) {
  final clean = hex.replaceAll(':', '').toUpperCase();
  final chunks = <String>[];
  for (var i = 0; i < clean.length; i += 2) {
    chunks.add(clean.substring(i, i + 2));
  }
  return chunks.join(':');
}
