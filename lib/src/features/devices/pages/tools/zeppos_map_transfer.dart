import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_map_upload_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_map_preview.dart';

Future<void> showZeppOsMapTransfer(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final selection = await pickFileData(
    dialogTitle: l10n.zeppOsMapSelectPackage,
    type: FileType.custom,
    allowedExtensions: const ['zip', 'img'],
    loadBytes: true,
  );
  if (!context.mounted || selection == null) return;
  final file = selection;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  if (bytes == null) {
    await _showMapError(context, l10n.zeppOsMapReadFailed);
    return;
  }
  late final ZeppOsPreparedMap prepared;
  try {
    prepared = ZeppOsMapPackage.prepare(bytes, fileName: file.name);
  } catch (error) {
    if (context.mounted) {
      await _showMapError(context, localizedErrorMessage(l10n, error));
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _MapTransferDialog(prepared: prepared, sourceFileName: file.name),
  );
}

Future<void> _showMapError(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          icon: const Icon(Icons.error_outline),
          title: Text(l10n.zeppOsMapConversionFailed),
          content: SingleChildScrollView(child: SelectableText(message)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.announcementAcknowledge),
            ),
          ],
        );
      },
    );

class _MapTransferDialog extends ConsumerStatefulWidget {
  const _MapTransferDialog({
    required this.prepared,
    required this.sourceFileName,
  });

  final ZeppOsPreparedMap prepared;
  final String sourceFileName;

  @override
  ConsumerState<_MapTransferDialog> createState() => _MapTransferDialogState();
}

class _MapTransferDialogState extends ConsumerState<_MapTransferDialog> {
  bool _uploading = false;
  bool _completed = false;
  double _progress = 0;
  Object? _error;

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .uploadZeppOsMap(
            widget.prepared.bytes,
            fileName: widget.prepared.fileName,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress.clamp(0, 1));
            },
          );
      if (mounted) {
        setState(() {
          _uploading = false;
          _completed = true;
          _progress = 1;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final package = widget.prepared.package;
    final usingBtbr =
        ref.watch(deviceManagerProvider).currentDevice?.connectType == 'spp';
    final previewTiles = package.tiles
        .map((tile) => (x: tile.x, y: tile.y, url: tile.openStreetMapUrl))
        .toList();
    return PopScope(
      canPop: !_uploading,
      child: AlertDialog(
        icon: Icon(
          _completed ? Icons.check_circle_outline : Icons.map_outlined,
        ),
        title: Text(
          _completed
              ? l10n.zeppOsMapTransferComplete
              : l10n.zeppOsMapTransferTitle,
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (package.isGarminImg) ...[
                  Text(
                    l10n.zeppOsMapGarminDetected(
                      widget.sourceFileName,
                      package.garminImgName ?? '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.zeppOsMapGarminNoPreview),
                ] else ...[
                  Text(
                    l10n.zeppOsMapTileSummary(
                      widget.sourceFileName,
                      package.tiles.length,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ZeppOsMapPreview(tiles: previewTiles, maxWidth: 420),
                ],
                const SizedBox(height: 12),
                _InfoText(
                  text: usingBtbr
                      ? l10n.zeppOsMapBtClassicHint
                      : l10n.zeppOsMapBleHint,
                ),
                if (_uploading || _completed) ...[
                  const SizedBox(height: 20),
                  SmoothLinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(
                    _completed
                        ? l10n.zeppOsMapTransferComplete
                        : '${l10n.zeppOsMapTransferringBluetooth} '
                              '${(_progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    localizedErrorMessage(l10n, error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!_uploading && !_completed)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          if (!_uploading && !_completed)
            FilledButton(
              onPressed: _upload,
              child: Text(l10n.zeppOsMapStartTransfer),
            ),
          if (_completed)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.announcementAcknowledge),
            ),
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 18,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );
}
