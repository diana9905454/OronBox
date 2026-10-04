import 'dart:typed_data';

import 'package:segmented_list/segmented_list.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_setting_viewer_page.dart';

class ZeppOsAppSettingsPage extends StatefulWidget {
  const ZeppOsAppSettingsPage({super.key});

  @override
  State<ZeppOsAppSettingsPage> createState() => _ZeppOsAppSettingsPageState();
}

class _ZeppOsAppSettingsPageState extends State<ZeppOsAppSettingsPage> {
  final _storage = ZeppOsAppSideStorage();
  late Future<List<_Item>> _items = _load();

  Future<List<_Item>> _load() async {
    final result = <_Item>[];
    for (final appId in await _storage.listAppIds()) {
      result.add(
        _Item(
          appId: appId,
          name: await _storage.readAppName(appId),
          hasAppSide: await _storage.exists(appId),
          hasSetting: await _storage.settingExists(appId),
        ),
      );
    }
    return result;
  }

  void _reload() => setState(() => _items = _load());

  Future<void> _supplement({_Item? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<_SupplementResult>(
      context: context,
      builder: (context) => _SupplementDialog(item: item),
    );
    if (result == null) return;
    try {
      if (result.appSide != null) {
        await _storage.save(result.appId, result.appSide!);
      }
      if (result.setting != null) {
        await _storage.saveSetting(
          result.appId,
          result.setting!,
          appName: result.name,
        );
      }
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.zeppOsAppCompatibilitySaved(_formatId(result.appId)),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
    }
  }

  Future<void> _open(_Item item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await showZeppOsAppSettings(
        context,
        appId: item.appId,
        title: item.name ?? _formatId(item.appId),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
    }
  }

  Future<void> _editStorage(_Item item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final coordinator = ZeppOsSettingsCoordinator.instance;
      final current = await coordinator.read(item.appId);
      if (!mounted) return;
      final updated = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _StorageEditorDialog(
          appId: item.appId,
          appName: item.name,
          initialValues: current,
        ),
      );
      if (updated == null) return;
      await coordinator.replace(item.appId, updated, origin: this);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.zeppOsAppStorageSaved(_formatId(item.appId))),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.zeppOsAppSettings),
        actions: [
          IconButton(
            onPressed: _supplement,
            icon: const Icon(Icons.add),
            tooltip: l10n.zeppOsAppSupplementFiles,
          ),
        ],
      ),
      body: FutureBuilder<List<_Item>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(localizedErrorMessage(l10n, snapshot.error)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: _supplement,
                icon: const Icon(Icons.add),
                label: Text(l10n.zeppOsAppSupplementCompatibility),
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageContainer(
                padding: const EdgeInsets.fromLTRB(
                  StyleConstants.pagePadding,
                  8,
                  StyleConstants.pagePadding,
                  0,
                ),
                child: SegmentedSection(
                  margin: const EdgeInsetsDirectional.only(
                    start: 0,
                    end: 0,
                    bottom: StyleConstants.pagePadding,
                  ),
                  tiles: [
                    for (final item in items)
                      SegmentedTile.navigation(
                        leading: Icon(
                          item.hasSetting
                              ? Icons.tune
                              : Icons.extension_outlined,
                        ),
                        title: Text(item.name ?? _formatId(item.appId)),
                        description: Text(
                          '${_formatId(item.appId)} · '
                          '${item.hasAppSide ? l10n.zeppOsAppSideAvailable : l10n.zeppOsAppSideMissing} · '
                          '${item.hasSetting ? l10n.zeppOsSettingAvailable : l10n.zeppOsSettingMissing}',
                        ),
                        onPressed: item.hasSetting ? (_) => _open(item) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _editStorage(item),
                              icon: const Icon(Icons.storage_outlined),
                              tooltip: l10n.zeppOsAppEditStorage,
                            ),
                            IconButton(
                              onPressed: () => _supplement(item: item),
                              icon: const Icon(Icons.upload_file_outlined),
                              tooltip: l10n.zeppOsAppReplaceCompatibility,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StorageEditorDialog extends StatefulWidget {
  const _StorageEditorDialog({
    required this.appId,
    required this.appName,
    required this.initialValues,
  });

  final int appId;
  final String? appName;
  final Map<String, String> initialValues;

  @override
  State<_StorageEditorDialog> createState() => _StorageEditorDialogState();
}

class _StorageEditorDialogState extends State<_StorageEditorDialog> {
  late final List<_StorageEntry> _entries = widget.initialValues.entries
      .map((entry) => _StorageEntry(entry.key, entry.value))
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() {
      _entries.add(_StorageEntry('', ''));
      _error = null;
    });
  }

  void _remove(int index) {
    setState(() {
      _entries.removeAt(index).dispose();
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      for (final entry in _entries) {
        entry.dispose();
      }
      _entries.clear();
      _error = null;
    });
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final result = <String, String>{};
    for (final entry in _entries) {
      final key = entry.key.text.trim();
      if (key.isEmpty) {
        setState(() => _error = l10n.zeppOsStorageKeyRequired);
        return;
      }
      if (result.containsKey(key)) {
        setState(() => _error = l10n.zeppOsStorageDuplicateKey(key));
        return;
      }
      result[key] = entry.value.text;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.appName ?? _formatId(widget.appId)),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatId(widget.appId)} · settingsStorage'),
            const SizedBox(height: 8),
            Text(l10n.zeppOsStorageDescription),
            const SizedBox(height: 12),
            Expanded(
              child: _entries.isEmpty
                  ? Center(child: Text(l10n.zeppOsStorageEmpty))
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: entry.key,
                                decoration: InputDecoration(
                                  labelText: l10n.zeppOsStorageKey,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: entry.value,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: l10n.zeppOsStorageValue,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _remove(index),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.delete,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _clear, child: Text(l10n.clear)),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(l10n.add),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

class _StorageEntry {
  _StorageEntry(String key, String value)
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _SupplementDialog extends StatefulWidget {
  const _SupplementDialog({this.item});

  final _Item? item;

  @override
  State<_SupplementDialog> createState() => _SupplementDialogState();
}

class _SupplementDialogState extends State<_SupplementDialog> {
  late final TextEditingController _appId = TextEditingController(
    text: widget.item == null
        ? ''
        : widget.item!.appId.toRadixString(16).padLeft(8, '0'),
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.item?.name ?? '',
  );
  Uint8List? _appSide;
  Uint8List? _setting;
  String? _appSideName;
  String? _settingName;
  String? _error;

  @override
  void dispose() {
    _appId.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool setting}) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await pickFileData(
      type: FileType.custom,
      allowedExtensions: const ['js'],
      loadBytes: true,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes == null) {
      setState(() => _error = l10n.selectedFileReadFailed);
      return;
    }
    setState(() {
      _error = null;
      if (setting) {
        _setting = bytes;
        _settingName = file.name;
      } else {
        _appSide = bytes;
        _appSideName = file.name;
      }
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    var value = _appId.text.trim().toLowerCase();
    if (value.startsWith('0x')) value = value.substring(2);
    final id = int.tryParse(value, radix: 16);
    if (id == null || id <= 0 || id > 0xffffffff) {
      setState(() => _error = l10n.zeppOsAppInvalidHexId);
      return;
    }
    if (_appSide == null && _setting == null) {
      setState(() => _error = l10n.zeppOsAppSelectCompatibilityFile);
      return;
    }
    Navigator.pop(
      context,
      _SupplementResult(
        appId: id,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        appSide: _appSide,
        setting: _setting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.item == null
            ? l10n.zeppOsAppSupplementCompatibility
            : l10n.zeppOsAppReplaceCompatibility,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _appId,
                enabled: widget.item == null,
                decoration: InputDecoration(
                  labelText: l10n.zeppOsAppHexId,
                  hintText: '000f9467',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.optionalDisplayName,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.javascript),
                title: const Text('app-side.js'),
                subtitle: Text(_appSideName ?? l10n.zeppOsAppSideUnchanged),
                trailing: OutlinedButton(
                  onPressed: () => _pick(setting: false),
                  child: Text(l10n.selectFile),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune),
                title: const Text('setting.js'),
                subtitle: Text(_settingName ?? l10n.zeppOsSettingUnchanged),
                trailing: OutlinedButton(
                  onPressed: () => _pick(setting: true),
                  child: Text(l10n.selectFile),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.zeppOsAppCompatibilityOverwriteHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _SupplementResult {
  const _SupplementResult({
    required this.appId,
    required this.name,
    required this.appSide,
    required this.setting,
  });

  final int appId;
  final String? name;
  final Uint8List? appSide;
  final Uint8List? setting;
}

class _Item {
  const _Item({
    required this.appId,
    required this.name,
    required this.hasAppSide,
    required this.hasSetting,
  });

  final int appId;
  final String? name;
  final bool hasAppSide;
  final bool hasSetting;
}

String _formatId(int value) => '0x${value.toRadixString(16).padLeft(8, '0')}';
