import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';

class CreatorDeviceSelectionDialog extends StatefulWidget {
  const CreatorDeviceSelectionDialog({
    super.key,
    required this.devices,
    required this.initialSelection,
    required this.blockedMoves,
  });

  final List<CreatorDevice> devices;
  final Set<String> initialSelection;
  final Map<String, String> blockedMoves;

  @override
  State<CreatorDeviceSelectionDialog> createState() =>
      _CreatorDeviceSelectionDialogState();
}

class _CreatorDeviceSelectionDialogState
    extends State<CreatorDeviceSelectionDialog> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.creatorSelectDevices),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selected.isEmpty
                  ? l10n.creatorNoDevicesSelected
                  : l10n.creatorSelectedDeviceCount(_selected.length),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final device in widget.devices)
                      Builder(
                        builder: (context) {
                          final selected = _selected.contains(device.id);
                          final owner = widget.blockedMoves[device.id];
                          final canUnselect = !selected || _selected.length > 1;
                          final enabled = owner == null && canUnselect;
                          final chip = FilterChip(
                            label: Text(
                              device.name.isEmpty ? device.id : device.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: selected,
                            showCheckmark: true,
                            onSelected: enabled
                                ? (checked) => setState(() {
                                    if (checked) {
                                      _selected.add(device.id);
                                    } else {
                                      _selected.remove(device.id);
                                    }
                                  })
                                : null,
                          );
                          return owner == null
                              ? chip
                              : Tooltip(
                                  message: l10n.creatorDeviceMoveBlocked(owner),
                                  child: chip,
                                );
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (_selected.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.creatorAtLeastOneDevice,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop({..._selected}),
          child: Text(l10n.creatorDeviceSelectionDone),
        ),
      ],
    );
  }
}
