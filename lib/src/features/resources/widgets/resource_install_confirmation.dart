import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/core/watchface_install_policy.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';

enum _InstallDecision { cancel, selectedType, detectedType, forceDetectedType }

Future<bool> confirmAndEnqueueResourceFile({
  required BuildContext context,
  required WidgetRef ref,
  required XFile file,
  LocalDeviceInstallType? selectedType,
}) async {
  final fileName = file.name;
  final fileLength = await file.length();
  final probe = await file
      .openRead(0, math.min(fileLength, 4096))
      .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
  final isZip = probe.length >= 2 && probe[0] == 0x50 && probe[1] == 0x4b;
  final bytes = isZip ? await file.readAsBytes() : Uint8List.fromList(probe);
  final service = ResourceInstallService();
  final analysis = service.analyzePayload(
    fileName: fileName,
    bytes: bytes,
    hint: selectedType,
    source: 'manual-picker',
  );
  if (!context.mounted) return false;
  final isWatchface =
      analysis?.type == LocalDeviceInstallType.watchface ||
      selectedType == LocalDeviceInstallType.watchface;
  if (isWatchface) {
    final restrictedId = restrictedWatchfaceIdFor(
      payload: analysis?.payload ?? bytes,
      analyzedIdentifier: analysis?.identifier,
    );
    if (restrictedId != null) {
      await _showRestrictedWatchfaceDialog(context);
      return false;
    }
  }
  final decision = await _confirmInstall(
    context,
    ref,
    analysis,
    selectedType: selectedType,
    fileName: fileName,
    fileSize: _formatFileSize(fileLength),
  );
  if (!context.mounted || decision == _InstallDecision.cancel) return false;

  final effectiveType = switch (decision) {
    _InstallDecision.selectedType => selectedType ?? analysis!.type,
    _InstallDecision.detectedType ||
    _InstallDecision.forceDetectedType => analysis!.type,
    _InstallDecision.cancel => selectedType ?? analysis!.type,
  };
  final installMode = switch (decision) {
    _InstallDecision.selectedType => ResourceInstallMode.forceType,
    _InstallDecision.forceDetectedType => ResourceInstallMode.forcePlatform,
    _InstallDecision.detectedType => ResourceInstallMode.automatic,
    _InstallDecision.cancel => ResourceInstallMode.automatic,
  };
  await ref
      .read(installQueueProvider.notifier)
      .enqueueConfirmedLocalFile(
        file,
        type: effectiveType,
        installMode: installMode,
        identifier: analysis!.identifier,
      );
  return true;
}

Future<void> _showRestrictedWatchfaceDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.watchfaceRestrictedTitle),
      content: Text(l10n.watchfaceRestrictedMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

Future<_InstallDecision> _confirmInstall(
  BuildContext context,
  WidgetRef ref,
  ResourcePayloadAnalysis? analysis, {
  LocalDeviceInstallType? selectedType,
  required String fileName,
  required String fileSize,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final device = ref.read(deviceManagerProvider).currentDevice;
  final deviceKind = device == null
      ? null
      : DeviceRegistry.resolveIdentity(
          name: device.name,
          codename: device.codename,
        ).kind;
  final selectedLabel = selectedType == null
      ? ''
      : _typeLabel(
          l10n,
          selectedType,
          platform: deviceKind == DeviceKind.zepp
              ? ResourcePlatform.zeppOs
              : ResourcePlatform.vela,
        );
  if (analysis == null) {
    if (selectedType == null) {
      // Opened externally (e.g. "open with OronBox"): nobody picked a type,
      // so there is nothing to fall back to, just report the unknown file.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.resourceTypeUnknownTitle),
          content: Text(l10n.resourceTypeUnknownNoType),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.resourceInstallCancel),
            ),
          ],
        ),
      );
      return _InstallDecision.cancel;
    }
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeUnknownTitle),
            content: Text(l10n.resourceTypeUnknownMessage(selectedLabel)),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallCancel),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallAsSelected(selectedLabel)
                    : l10n.resourceInstallAsSelectedCountdown(
                        selectedLabel,
                        seconds,
                      ),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.selectedType),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  final resourceKind = analysis.platform == ResourcePlatform.zeppOs
      ? DeviceKind.zepp
      : DeviceKind.xiaomi;
  if (device != null && deviceKind != resourceKind) {
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeErrorTitle),
            content: Text(
              l10n.resourcePlatformMismatchMessage(
                _platformLabel(analysis.platform),
                _typeLabel(l10n, analysis.type, platform: analysis.platform),
                device.name,
                deviceKind == DeviceKind.zepp ? 'ZeppOS' : 'VelaOS',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallAcknowledge),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallForce
                    : l10n.resourceInstallForceCountdown(seconds),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.forceDetectedType),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  if (selectedType != null && analysis.type != selectedType) {
    final detectedLabel = _typeLabel(
      l10n,
      analysis.type,
      platform: analysis.platform,
    );
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeErrorTitle),
            content: Text(
              l10n.resourceTypeMismatchMessage(detectedLabel, selectedLabel),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallCancel),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallAsSelected(selectedLabel)
                    : l10n.resourceInstallAsSelectedCountdown(
                        selectedLabel,
                        seconds,
                      ),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.selectedType),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.detectedType),
                child: Text(l10n.resourceInstallAsDetected(detectedLabel)),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  return await showDialog<_InstallDecision>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            l10n.resourceInstallConfirmTitle(
              _typeLabel(l10n, analysis.type, platform: analysis.platform),
            ),
          ),
          content: Text(l10n.resourceInstallConfirmMessage(fileName, fileSize)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _InstallDecision.cancel),
              child: Text(l10n.resourceInstallCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _InstallDecision.detectedType),
              child: Text(l10n.resourceInstallConfirm),
            ),
          ],
        ),
      ) ??
      _InstallDecision.cancel;
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _platformLabel(ResourcePlatform platform) => switch (platform) {
  ResourcePlatform.vela => 'VelaOS',
  ResourcePlatform.zeppOs => 'ZeppOS',
};

String _typeLabel(
  AppLocalizations l10n,
  LocalDeviceInstallType type, {
  required ResourcePlatform platform,
}) => switch (type) {
  LocalDeviceInstallType.app =>
    platform == ResourcePlatform.vela
        ? l10n.resourceTypeQuickApp
        : l10n.resourceTypeApp,
  LocalDeviceInstallType.watchface => l10n.resourceTypeWatchface,
  LocalDeviceInstallType.firmware => l10n.resourceTypeFirmware,
};

class _DelayedInstallButton extends StatefulWidget {
  const _DelayedInstallButton({required this.label, required this.onPressed});

  final String Function(int seconds) label;
  final VoidCallback onPressed;

  @override
  State<_DelayedInstallButton> createState() => _DelayedInstallButtonState();
}

class _DelayedInstallButtonState extends State<_DelayedInstallButton> {
  static const _delaySeconds = 3;
  Timer? _timer;
  int _remaining = _delaySeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _remaining == 0 ? widget.onPressed : null,
      child: Text(widget.label(_remaining)),
    );
  }
}
