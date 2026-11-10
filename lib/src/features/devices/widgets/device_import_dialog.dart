import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_service.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

const _wearableLogChannel = MethodChannel('oronbox/wearable_log');

Future<List<MiCloudDevice>?> _scanOhosWearableLogs() async {
  final uris = await _wearableLogChannel.invokeListMethod<String>('pickLogs');
  if (uris == null || uris.isEmpty) return null;
  final inputs = <({String name, Uint8List bytes})>[];
  var remainingBytes = maxWearableLogBatchBytes;
  for (final uri in uris) {
    final name = Uri.tryParse(uri)?.pathSegments.lastOrNull;
    if (name == null || !isWearableLogInput(name)) continue;
    final fileLimit = isWearableLogArchive(name)
        ? maxWearableLogArchiveBytes
        : maxWearableLogFileBytes;
    final limit = fileLimit < remainingBytes ? fileLimit : remainingBytes;
    if (limit == 0) break;
    try {
      final bytes = await _wearableLogChannel.invokeMethod<Uint8List>(
        'readLog',
        {'uri': uri, 'maxBytes': limit},
      );
      if (bytes == null || bytes.isEmpty || bytes.length > limit) continue;
      inputs.add((name: name, bytes: bytes));
      remainingBytes -= bytes.length;
    } on PlatformException {
      // A file that was deleted or cannot be read must not block the batch.
    }
  }
  if (inputs.isEmpty) throw const FormatException('No readable wearable logs');
  return compute(extractMiDevicesFromWearableLogs, inputs);
}

Future<List<MiCloudDevice>> _scanLatestWearableLog() async {
  final value = await _wearableLogChannel.invokeMapMethod<String, Object?>(
    'scanLatest',
  );
  final bytes = switch (value?['bytes']) {
    Uint8List value => value,
    List value => Uint8List.fromList(
      value.whereType<num>().map((item) => item.toInt()).toList(),
    ),
    _ => null,
  };
  if (bytes == null) throw const FormatException('Missing wearable log data');
  return compute(extractMiDevicesFromWearableLogZip, bytes);
}

Future<void> showWearableLogSyncDialog(BuildContext context, WidgetRef ref) =>
    _showDeviceImportDialog(context, ref);

Future<void> showSharedDeviceImportDialog(
  BuildContext context,
  WidgetRef ref,
  MiWearState device,
) => _showDeviceImportDialog(context, ref, sharedDevice: device);

Future<void> _showDeviceImportDialog(
  BuildContext context,
  WidgetRef ref, {
  MiWearState? sharedDevice,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final isOhos = defaultTargetPlatform == TargetPlatform.ohos;
  List<MiCloudDevice>? devices = sharedDevice == null
      ? null
      : [
          MiCloudDevice(
            name: sharedDevice.name,
            model: sharedDevice.codename ?? '',
            mac: sharedDevice.addr,
            authKey: sharedDevice.authkey ?? '',
            firmwareVersion: '',
            serialNumber: '',
          ),
        ];
  var scanning = false;
  var importing = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> scan() async {
          setDialogState(() {
            scanning = true;
            error = null;
          });
          try {
            final found = isOhos
                ? await _scanOhosWearableLogs()
                : await _scanLatestWearableLog();
            if (!dialogContext.mounted) return;
            if (found == null) {
              setDialogState(() => scanning = false);
              return;
            }
            found.sort((a, b) => a.name.compareTo(b.name));
            setDialogState(() {
              scanning = false;
              devices = found;
              error = found.isEmpty ? l10n.settingsMiAccountLogNoDevices : null;
            });
          } on PlatformException catch (exception) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              scanning = false;
              if (exception.code != 'CANCELLED') {
                error = l10n.settingsMiAccountLogInvalid;
              }
            });
          } catch (_) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              scanning = false;
              error = l10n.settingsMiAccountLogInvalid;
            });
          }
        }

        Future<void> importDevice(MiCloudDevice device) async {
          if (importing) return;
          setDialogState(() {
            importing = true;
            error = null;
          });
          try {
            final manager = ref.read(deviceManagerProvider.notifier);
            if (sharedDevice != null) {
              await manager.importSharedDevice(sharedDevice);
            } else {
              final count = await manager.importMiCloudDevices([device]);
              if (count == 0) return;
            }
            if (!dialogContext.mounted) return;
            appScaffoldMessengerOf(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.settingsWearableLogImportedDevice(
                    device.name.isEmpty ? device.model : device.name,
                  ),
                ),
              ),
            );
          } catch (exception) {
            if (dialogContext.mounted) {
              setDialogState(
                () => error = localizedErrorMessage(l10n, exception),
              );
            }
          } finally {
            if (dialogContext.mounted) setDialogState(() => importing = false);
          }
        }

        return AlertDialog(
          title: Text(
            sharedDevice == null
                ? l10n.settingsWearableLogSync
                : l10n.deviceImportTitle,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 460,
              maxWidth: 460,
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: devices == null
                ? SingleChildScrollView(
                    child: Text(
                      error ??
                          (isOhos
                              ? l10n.settingsWearableLogGuideOhos
                              : l10n.settingsWearableLogGuide),
                      style: error == null
                          ? null
                          : TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.settingsWearableLogFound(devices!.length)),
                      const SizedBox(height: 12),
                      if (error != null && devices!.isNotEmpty)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (devices!.isEmpty)
                        Text(
                          error ?? l10n.settingsMiAccountLogNoDevices,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: devices!.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = devices![index];
                              return InkWell(
                                onTap: importing
                                    ? null
                                    : () => importDevice(device),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name.isEmpty
                                            ? device.model
                                            : device.name,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (device.model.isNotEmpty)
                                            device.model,
                                          device.mac,
                                        ].join('\n'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: scanning || importing
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            if (sharedDevice == null)
              FilledButton(
                style: const ButtonStyle(elevation: WidgetStatePropertyAll(0)),
                onPressed: scanning || importing ? null : scan,
                child: scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isOhos ? l10n.settingsWearableLogGet : l10n.scan),
              ),
          ],
        );
      },
    ),
  );
}
