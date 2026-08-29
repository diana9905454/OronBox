import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/window/window_launcher.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/plugins/domain/plugin_package.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_install_confirmation.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

import 'plugin_detail_page.dart';

class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  StreamSubscription<CommandEvent>? _events;
  var _plugins = <Map<String, Object?>>[];
  var _loading = true;
  var _query = '';
  var _section = 0;
  var _sources = <Map<String, Object?>>[];
  String? _marketSource;
  var _marketEntries = <Map<String, Object?>>[];
  var _marketLoading = false;
  Object? _marketError;
  final _installing = <String>{};
  String? _selectedPluginId;
  var _safeMode = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(applicationHostProvider).events.listen((event) {
      if (event.event == 'plugin.state') unawaited(_load());
    });
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _execute(
          OronBoxCommand(
            method: 'plugin.list',
            params: {'includeIcons': kIsWeb},
          ),
        ),
        _execute(const OronBoxCommand(method: 'plugin.safeMode.get')),
        _execute(const OronBoxCommand(method: 'plugin.repositories')),
      ]);
      if (!mounted) return;
      setState(() {
        _plugins = (values[0] as List)
            .whereType<Map>()
            .map((row) => row.cast<String, Object?>())
            .toList(growable: false);
        _safeMode = (values[1] as Map?)?['enabled'] == true;
        _sources = (values[2] as List)
            .whereType<Map>()
            .map((row) => row.cast<String, Object?>())
            .toList(growable: false);
        if (!_sources.any((source) => source['id'] == _marketSource)) {
          _marketSource = _sources
              .where((source) => source['id'] == 'oronbox')
              .firstOrNull?['id']
              ?.toString();
          _marketSource ??= _sources.firstOrNull?['id']?.toString();
        }
        final ids = _plugins.map((plugin) => plugin['id']?.toString()).toSet();
        if (!ids.contains(_selectedPluginId)) {
          _selectedPluginId = null;
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMarket({bool force = false}) async {
    final source = _marketSource;
    if (source == null || _marketLoading) return;
    if (!force && _marketEntries.isNotEmpty) return;
    setState(() {
      _marketLoading = true;
      _marketError = null;
    });
    try {
      final value = await _execute(
        OronBoxCommand(
          method: 'plugin.repository.catalog',
          params: {'source': source, 'force': force},
        ),
      );
      if (mounted) {
        setState(
          () => _marketEntries = (value as List)
              .whereType<Map>()
              .map((row) => row.cast<String, Object?>())
              .toList(growable: false),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _marketError = error);
    } finally {
      if (mounted) setState(() => _marketLoading = false);
    }
  }

  Future<void> _openInstalledPlugin(String id, {required bool wide}) async {
    await takePluginWindow(id);
    if (!mounted) return;
    if (wide) {
      setState(() => _selectedPluginId = id);
    } else {
      context.push('/plugins/$id');
    }
  }

  Future<Uint8List?> _pickPackage(List<String> extensions) async {
    final picked = await pickFileData(
      type: FileType.custom,
      allowedExtensions: extensions,
      loadBytes: true,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes == null) {
      _showError(StateError('Unable to read ${picked.name}'));
    }
    return bytes;
  }

  Future<void> _importPlugin() async {
    final bytes = await _pickPackage(const ['obp', 'abp', 'zip']);
    if (bytes == null) return;
    if (!mounted) return;
    try {
      final package = const PluginPackageReader().read(bytes);
      final manifest = package.manifest;
      final updating = _plugins.any(
        (plugin) => plugin['id']?.toString() == manifest.id,
      );
      if (!await confirmPluginInstall(
        context: context,
        name: manifest.name,
        permissions: manifest.permissions,
        updating: updating,
        legacy: manifest.runtime == PluginRuntimeType.legacy,
      )) {
        return;
      }
      await _execute(
        OronBoxCommand(
          method: 'plugin.install',
          params: {'bytes': base64Encode(bytes), 'includeIcon': false},
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _installMarketPlugin(Map<String, Object?> entry) async {
    final legacy = entry['legacy'] == true;
    if (!await confirmPluginInstall(
      context: context,
      name: entry['name']?.toString() ?? '',
      permissions: (entry['permissions'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      updating: entry['updateAvailable'] == true,
      legacy: legacy,
    )) {
      return;
    }
    final id = entry['id']?.toString() ?? '';
    setState(() => _installing.add(id));
    try {
      await _execute(
        OronBoxCommand(
          method: 'plugin.repository.install',
          params: {'source': entry['source']?.toString() ?? '', 'id': id},
        ),
      );
      await _load();
      await _loadMarket(force: true);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _installing.remove(id));
    }
  }

  Future<void> _uploadPlugin() async {
    final l10n = AppLocalizations.of(context)!;
    if (!ref.read(hostAccountsProvider).bandbbs.isSignedIn) {
      _showError(StateError(l10n.pluginLoginRequired));
      return;
    }
    final bytes = await _pickPackage(const ['obp', 'zip']);
    if (bytes == null) return;
    try {
      final package = const PluginPackageReader().read(bytes);
      final manifest = package.manifest;
      if (manifest.runtime == PluginRuntimeType.legacy) {
        _showError(const FormatException('Legacy plugins cannot be published'));
        return;
      }
      final existing = _marketEntries
          .where((entry) => entry['id']?.toString() == manifest.id)
          .firstOrNull;
      if (existing != null && existing['owned'] != true) {
        _showError(
          StateError('Plugin id is published by another user: ${manifest.id}'),
        );
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) =>
            _PluginPublishDialog(package: package, updating: existing != null),
      );
      if (confirmed != true) return;
      await _execute(
        OronBoxCommand(
          method: 'plugin.repository.upload',
          params: {'source': 'oronbox', 'bytes': base64Encode(bytes)},
        ),
      );
      await _loadMarket(force: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pluginSubmittedForReview)));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _takedownPlugin(Map<String, Object?> entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.pluginTakedown),
            content: Text(l10n.pluginTakedownConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.pluginTakedown),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _execute(
        OronBoxCommand(
          method: 'plugin.repository.remove',
          params: {'source': 'oronbox', 'id': entry['id']?.toString() ?? ''},
        ),
      );
      await _loadMarket(force: true);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _showMarketEntry(Map<String, Object?> entry) async {
    final l10n = AppLocalizations.of(context)!;
    final permissions = (entry['permissions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final installed = entry['installed'] == true;
    final updateAvailable = entry['updateAvailable'] == true;
    final owned = entry['owned'] == true;
    final state = entry['state']?.toString();
    final listed = state == null || state == 'listed';
    final stateLabel = switch (state) {
      'pending' => l10n.pluginStatePending,
      'rejected' => l10n.pluginStateRejected,
      'delisted' => l10n.pluginStateDelisted,
      _ => null,
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry['name']?.toString() ?? ''),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MarketIcon(iconUrl: entry['iconUrl']?.toString(), size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry['author'] ?? ''} · ${entry['version'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (entry['uploaderName'] != null)
                          Text(
                            entry['uploaderName'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (stateLabel != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      state == 'pending' ? Icons.schedule : Icons.error_outline,
                      size: 18,
                      color: state == 'pending'
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry['moderationReason']?.toString().isNotEmpty == true
                            ? '$stateLabel:${entry['moderationReason']}'
                            : stateLabel,
                      ),
                    ),
                  ],
                ),
              ],
              if (entry['description']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(entry['description'].toString()),
              ],
              const SizedBox(height: 16),
              Text(l10n.pluginDeclaredPermissions),
              const SizedBox(height: 8),
              if (permissions.isEmpty)
                Text(
                  l10n.pluginNoPermissions,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...permissions.map(
                  (permission) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 7),
                        const SizedBox(width: 8),
                        Expanded(child: Text(permission)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (owned) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _takedownPlugin(entry);
              },
              child: Text(l10n.pluginTakedown),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _uploadPlugin();
              },
              child: Text(l10n.update),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: installed || !listed
                ? null
                : () {
                    Navigator.pop(context);
                    _installMarketPlugin(entry);
                  },
            child: Text(
              updateAvailable
                  ? l10n.update
                  : installed
                  ? l10n.pluginUpToDate
                  : l10n.install,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exitSafeMode() async {
    await _execute(
      const OronBoxCommand(
        method: 'plugin.safeMode.set',
        params: {'enabled': false},
      ),
    );
    if (mounted) setState(() => _safeMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    bool matches(Iterable<Object?> values) => values.any(
      (value) => value?.toString().toLowerCase().contains(query) ?? false,
    );
    final visiblePlugins = query.isEmpty
        ? _plugins
        : _plugins
              .where(
                (plugin) => matches([
                  plugin['name'],
                  plugin['description'],
                  plugin['author'],
                ]),
              )
              .toList(growable: false);
    final visibleEntries = query.isEmpty
        ? _marketEntries
        : _marketEntries
              .where(
                (entry) => matches([
                  entry['name'],
                  entry['description'],
                  entry['author'],
                ]),
              )
              .toList(growable: false);
    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.pluginsTab),
        actions: [
          if (_section == 1) ...[
            _PluginSourceMenu(
              sources: _sources,
              selected: _marketSource,
              onSelected: (source) {
                setState(() {
                  _marketSource = source;
                  _marketEntries = const [];
                });
                _loadMarket();
              },
            ),
            if (_marketSource == 'oronbox')
              IconButton(
                onPressed: _uploadPlugin,
                icon: const Icon(Icons.upload_outlined),
                tooltip: l10n.pluginUpload,
              ),
          ],
          if (!(_section == 1 && _marketSource == 'oronbox'))
            IconButton(
              onPressed: _importPlugin,
              icon: const Icon(Icons.add_box_outlined),
              tooltip: l10n.pluginImport,
            ),
          IconButton(
            onPressed: _section == 0 ? _load : () => _loadMarket(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = useWideLayout(constraints.maxWidth);
          final catalog = _PluginCatalog(
            section: _section,
            loading: _loading,
            plugins: visiblePlugins,
            entries: visibleEntries,
            marketLoading: _marketLoading,
            marketError: _marketError,
            installing: _installing,
            selectedPluginId: wide ? _selectedPluginId : null,
            emptyText: l10n.pluginEmpty,
            marketUnavailableText: l10n.pluginMarketUnavailable,
            installedLabel: l10n.pluginInstalled,
            marketLabel: l10n.pluginMarket,
            onQueryChanged: (value) => setState(() => _query = value),
            onSectionChanged: (value) {
              setState(() => _section = value);
              if (value == 1) _loadMarket();
            },
            onRefreshMarket: () => _loadMarket(force: true),
            onInstall: _installMarketPlugin,
            onOpenEntry: _showMarketEntry,
            onOpen: (id) => _openInstalledPlugin(id, wide: wide),
          );
          return PageContainer(
            maxWidth: wide ? 1280 : 1000,
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              0,
              StyleConstants.pagePadding,
              0,
            ),
            child: Column(
              children: [
                if (_safeMode) ...[
                  _PluginSafeModeBanner(onExit: _exitSafeMode),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: Row(
                    children: [
                      if (wide)
                        SizedBox(width: 360, child: catalog)
                      else
                        Expanded(child: catalog),
                      if (wide) ...[
                        const SizedBox(width: 24),
                        Expanded(
                          child: _selectedPluginId == null
                              ? _PluginSelectionPlaceholder(
                                  text: l10n.pluginSelectHint,
                                )
                              : PluginDetailPage(
                                  key: ValueKey(_selectedPluginId),
                                  pluginId: _selectedPluginId!,
                                  embedded: true,
                                  onClose: () =>
                                      setState(() => _selectedPluginId = null),
                                  onRemoved: _load,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Object?> _execute(OronBoxCommand command) async {
    final result = await ref.read(applicationHostProvider).execute(command);
    if (!result.ok) {
      throw result.error!;
    }
    return result.value;
  }

  void _showError(Object error) {
    if (_isPluginPackageError(error)) {
      unawaited(_showPluginPackageCorruptedDialog());
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizedErrorMessage(l10n, error))));
  }

  Future<void> _showPluginPackageCorruptedDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginErrorTitle),
        content: Text(l10n.pluginPackageCorruptedMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  bool _isPluginPackageError(Object error) {
    final message = switch (error) {
      CommandError(:final message) => message,
      FormatException(:final message) => message,
      _ => error.toString(),
    };
    return message.contains('ABP manifest.json is missing') ||
        message.contains('ABP package') ||
        message.contains('ABP entry is missing');
  }
}

class _PluginSourceMenu extends StatelessWidget {
  const _PluginSourceMenu({
    required this.sources,
    required this.selected,
    required this.onSelected,
  });

  final List<Map<String, Object?>> sources;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = sources
        .where((source) => source['id'] == selected)
        .firstOrNull;
    return MenuAnchor(
      menuChildren: sources
          .map(
            (source) => MenuItemButton(
              trailingIcon: source['id'] == selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: source['id'] == selected
                  ? null
                  : () => onSelected(source['id'].toString()),
              child: Text(source['name']?.toString() ?? ''),
            ),
          )
          .toList(growable: false),
      builder: (context, controller, child) => TextButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current?['name']?.toString() ?? ''),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _PluginPublishDialog extends StatelessWidget {
  const _PluginPublishDialog({required this.package, required this.updating});

  final PluginPackage package;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final manifest = package.manifest;
    return AlertDialog(
      title: Text(l10n.pluginPublishTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PluginIcon(base64: package.installed().iconBase64, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manifest.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${manifest.author} · ${manifest.version}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        manifest.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (manifest.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(manifest.description),
            ],
            const SizedBox(height: 16),
            Text(l10n.pluginDeclaredPermissions),
            const SizedBox(height: 8),
            if (manifest.permissions.isEmpty)
              Text(
                l10n.pluginNoPermissions,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...manifest.permissions.map(
                (permission) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 7),
                      const SizedBox(width: 8),
                      Expanded(child: Text(permission)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              updating ? l10n.pluginPublishUpdate : l10n.pluginPublishNew,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(updating ? l10n.update : l10n.pluginUpload),
        ),
      ],
    );
  }
}

class _PluginSafeModeBanner extends StatelessWidget {
  const _PluginSafeModeBanner({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pluginSafeModeTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(l10n.pluginSafeModeDescription),
                ],
              ),
            ),
            TextButton(onPressed: onExit, child: Text(l10n.pluginSafeModeExit)),
          ],
        ),
      ),
    );
  }
}

class _PluginCatalog extends StatelessWidget {
  const _PluginCatalog({
    required this.section,
    required this.loading,
    required this.plugins,
    required this.entries,
    required this.marketLoading,
    required this.marketError,
    required this.installing,
    required this.selectedPluginId,
    required this.emptyText,
    required this.marketUnavailableText,
    required this.installedLabel,
    required this.marketLabel,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.onRefreshMarket,
    required this.onInstall,
    required this.onOpenEntry,
    required this.onOpen,
  });

  final int section;
  final bool loading;
  final List<Map<String, Object?>> plugins;
  final List<Map<String, Object?>> entries;
  final bool marketLoading;
  final Object? marketError;
  final Set<String> installing;
  final String? selectedPluginId;
  final String emptyText;
  final String marketUnavailableText;
  final String installedLabel;
  final String marketLabel;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSectionChanged;
  final VoidCallback onRefreshMarket;
  final ValueChanged<Map<String, Object?>> onInstall;
  final ValueChanged<Map<String, Object?>> onOpenEntry;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        SegmentedButton<int>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            iconSize: WidgetStatePropertyAll(18),
          ),
          segments: [
            ButtonSegment(
              value: 0,
              label: Text(
                installedLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              icon: const Icon(Icons.extension_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text(
                marketLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              icon: const Icon(Icons.storefront_outlined),
            ),
          ],
          selected: {section},
          onSelectionChanged: (value) => onSectionChanged(value.first),
        ),
        SizedBox(
          height: compact ? 10 : StyleConstants.pagePadding,
        ),
        SearchBar(
          constraints: BoxConstraints.tightFor(
            height: compact ? 48 : 56,
          ),
          elevation: const WidgetStatePropertyAll(0),
          leading: const Icon(Icons.search),
          hintText: AppLocalizations.of(context)!.search,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: section == 0
              ? _InstalledPlugins(
                  loading: loading,
                  plugins: plugins,
                  selectedPluginId: selectedPluginId,
                  onOpen: onOpen,
                  emptyText: emptyText,
                )
              : _PluginMarket(
                  loading: marketLoading,
                  error: marketError,
                  entries: entries,
                  installing: installing,
                  emptyText: marketUnavailableText,
                  onRefresh: onRefreshMarket,
                  onInstall: onInstall,
                  onOpen: onOpenEntry,
                ),
        ),
      ],
    );
  }
}

class _InstalledPlugins extends StatelessWidget {
  const _InstalledPlugins({
    required this.loading,
    required this.plugins,
    required this.selectedPluginId,
    required this.onOpen,
    required this.emptyText,
  });

  final bool loading;
  final List<Map<String, Object?>> plugins;
  final String? selectedPluginId;
  final ValueChanged<String> onOpen;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(emptyText),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: plugins.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return _PluginCard(
          plugin: plugin,
          onTap: () => onOpen(plugin['id']!.toString()),
        );
      },
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, required this.onTap});

  final Map<String, Object?> plugin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PluginIcon(
                base64: plugin['icon']?.toString(),
                path: plugin['iconPath']?.toString(),
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plugin['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginSelectionPlaceholder extends StatelessWidget {
  const _PluginSelectionPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(text),
        ],
      ),
    );
  }
}

class _PluginMarket extends StatelessWidget {
  const _PluginMarket({
    required this.loading,
    required this.error,
    required this.entries,
    required this.installing,
    required this.emptyText,
    required this.onRefresh,
    required this.onInstall,
    required this.onOpen,
  });

  final bool loading;
  final Object? error;
  final List<Map<String, Object?>> entries;
  final Set<String> installing;
  final String emptyText;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, Object?>> onInstall;
  final ValueChanged<Map<String, Object?>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.refresh),
            ),
          ],
        ),
      );
    }
    if (entries.isEmpty) return Center(child: Text(emptyText));
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final id = entry['id']?.toString() ?? '';
          final isInstalling = installing.contains(id);
          final installed = entry['installed'] == true;
          final updateAvailable = entry['updateAvailable'] == true;
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(entry),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _MarketIcon(
                      iconUrl: entry['iconUrl']?.toString(),
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${entry['author'] ?? ''} · ${entry['version'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    isInstalling
                        ? IconButton.filledTonal(
                            onPressed: null,
                            icon: const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filledTonal(
                            onPressed: installed
                                ? null
                                : () => onInstall(entry),
                            icon: Icon(
                              installed
                                  ? Icons.check_rounded
                                  : updateAvailable
                                  ? Icons.upgrade_rounded
                                  : Icons.add_rounded,
                            ),
                            tooltip: installed
                                ? AppLocalizations.of(context)!.pluginUpToDate
                                : updateAvailable
                                ? AppLocalizations.of(context)!.update
                                : AppLocalizations.of(context)!.install,
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MarketIcon extends StatelessWidget {
  const _MarketIcon({required this.iconUrl, required this.size});

  final String? iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.extension,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
    final url = iconUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? fallback(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => fallback(context),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback(context),
              ),
      ),
    );
  }
}

class PluginIcon extends StatelessWidget {
  const PluginIcon({super.key, this.base64, this.path, required this.size});

  final String? base64;
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    final data = base64;
    if (data != null) {
      try {
        bytes = base64Decode(data);
      } on FormatException {
        bytes = null;
      }
    }
    Widget fallback(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.extension,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
    Widget child;
    final nativePath = path;
    if (!kIsWeb && nativePath != null && File(nativePath).existsSync()) {
      child = Image.file(
        File(nativePath),
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => fallback(context),
      );
    } else if (bytes != null) {
      child = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => fallback(context),
      );
    } else {
      child = fallback(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}
