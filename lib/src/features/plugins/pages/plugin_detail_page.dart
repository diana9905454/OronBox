import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/app/window/desktop_window.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_ui_tree.dart';

import 'plugins_page.dart';

class PluginDetailPage extends ConsumerStatefulWidget {
  const PluginDetailPage({
    super.key,
    required this.pluginId,
    this.embedded = false,
    this.allowDetach = true,
    this.onClose,
    this.onRemoved,
  });

  final String pluginId;
  final bool embedded;
  final bool allowDetach;
  final VoidCallback? onClose;
  final FutureOr<void> Function()? onRemoved;

  @override
  ConsumerState<PluginDetailPage> createState() => _PluginDetailPageState();
}

/// Optional state carried from the plugin event that opens a secondary page.
///
/// The route itself is identified by [pluginId]/page. This object is only a
/// first-paint preview; a restored/deep-linked route must not depend on it.
class PluginUiRouteArgs {
  const PluginUiRouteArgs({required this.nodes, required this.title});

  final Object? nodes;
  final String title;
}

class _PluginDetailPageState extends ConsumerState<PluginDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StreamSubscription<CommandEvent>? _events;
  StreamSubscription<void>? _handoffs;
  late final OronBoxCommandBus _host;
  Future<void>? _loadFuture;
  Map<String, Object?>? _plugin;
  Object? _nodes;
  Object? _error;
  bool _runtimeHandedOff = false;
  bool _pageRouteOpen = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _host = ref.read(applicationHostProvider);
    _events = _host.events.listen(_handleEvent);
    if (!widget.allowDetach) {
      _handoffs = secondaryWindowHandoffs.listen((_) {
        _runtimeHandedOff = true;
      });
    }
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _handoffs?.cancel();
    _tabs.dispose();
    unawaited(_closeAfterLoad());
    super.dispose();
  }

  Future<void> _closeAfterLoad() async {
    try {
      await _loadFuture;
    } catch (_) {
      // A failed open does not leave a running plugin to close.
    }
    if (_runtimeHandedOff) return;
    await _host.execute(
      OronBoxCommand(method: 'plugin.close', params: {'id': widget.pluginId}),
    );
  }

  Future<void> _detach() async {
    final opened = await openPluginWindow(widget.pluginId);
    if (!opened || !mounted) return;
    _runtimeHandedOff = true;
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      context.pop();
    }
  }

  Future<void> _load() async {
    try {
      final detail = (await _execute(
        OronBoxCommand(method: 'plugin.get', params: {'id': widget.pluginId}),
      ) as Map).cast<String, Object?>();
      if (mounted) setState(() => _plugin = detail);
      if (!widget.allowDetach) {
        await setSecondaryWindowTitle(detail['name']?.toString() ?? '');
        await setSecondaryWindowIcon(detail['icon']?.toString());
      }
      final nodes = await _execute(
        OronBoxCommand(method: 'plugin.open', params: {'id': widget.pluginId}),
      );
      if (mounted) {
        setState(() {
          _nodes = nodes;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'plugin.ui' &&
        event.data['id']?.toString() == widget.pluginId) {
      final nodes = event.data['nodes'];
      if (event.data['page'] == true) {
        unawaited(_openNodePage(nodes));
      } else if (mounted) {
        setState(() => _nodes = nodes);
      }
      return;
    }
  }

  Future<void> _invoke(String callback, [Object? value]) async {
    try {
      await _execute(
        OronBoxCommand(
          method: 'plugin.invoke',
          params: {
            'id': widget.pluginId,
            'callback': callback,
            if (value != null) 'value': value,
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorMessage(AppLocalizations.of(context)!, error),
          ),
        ),
      );
    }
  }

  Future<void> _openNodePage(Object? nodes) async {
    if (!mounted || _pageRouteOpen) return;
    _pageRouteOpen = true;
    final title =
        _plugin?['name']?.toString() ??
        AppLocalizations.of(context)!.pluginFeatures;
    final routeArgs = PluginUiRouteArgs(nodes: nodes, title: title);
    try {
      if (GoRouter.maybeOf(context) case final router?) {
        await router.push<void>(
          '/plugins/${Uri.encodeComponent(widget.pluginId)}/page',
          extra: routeArgs,
        );
      } else {
        // Secondary plugin windows intentionally do not own the main app
        // router. Keep the same route page and lifecycle in that isolated
        // navigator instead of coupling the page to the parent state.
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PluginUiPage(
              pluginId: widget.pluginId,
              preview: nodes,
              title: title,
            ),
          ),
        );
      }
    } finally {
      _pageRouteOpen = false;
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginUninstallTitle),
        content: Text(l10n.pluginUninstallMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.uninstall),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _execute(
      OronBoxCommand(method: 'plugin.remove', params: {'id': widget.pluginId}),
    );
    await widget.onRemoved?.call();
    if (mounted && !widget.embedded) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plugin = _plugin;
    if (!widget.allowDetach) {
      if (plugin == null) {
        return Scaffold(
          body: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(localizedErrorMessage(l10n, _error)),
          ),
        );
      }
      return Scaffold(
        body: PluginUITree(root: _nodes, onInvoke: _invoke),
      );
    }
    final content = plugin == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(localizedErrorMessage(l10n, _error)),
          )
        : Column(
            children: [
              _PluginHeader(
                plugin: plugin,
                tabs: _tabs,
                onClose: widget.embedded ? widget.onClose : null,
                onDetach: widget.allowDetach && supportsSecondaryWindows
                    ? _detach
                    : null,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    PluginUITree(
                      root: _nodes,
                      onInvoke: _invoke,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: StyleConstants.pagePadding,
                      ),
                    ),
                    _PluginInformation(plugin: plugin, onUninstall: _remove),
                  ],
                ),
              ),
            ],
          );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(plugin?['name']?.toString() ?? l10n.pluginDetails),
      ),
      body: content,
    );
  }

  Future<Object?> _execute(OronBoxCommand command) async {
    final result = await _host.execute(command);
    if (!result.ok) {
      throw result.error!;
    }
    return result.value;
  }
}

/// Displays the page tree currently opened by a plugin.
///
/// The parent [PluginDetailPage] owns the plugin runtime and supplies the
/// optional event preview. This page owns only its route-local event
/// subscription and invocation bridge, so it remains valid when restored by
/// GoRouter without a closure captured from the parent widget.
class PluginUiPage extends ConsumerStatefulWidget {
  const PluginUiPage({
    super.key,
    required this.pluginId,
    this.preview,
    this.title = '',
  });

  final String pluginId;
  final Object? preview;
  final String title;

  @override
  ConsumerState<PluginUiPage> createState() => _PluginUiPageState();
}

class _PluginUiPageState extends ConsumerState<PluginUiPage> {
  late final OronBoxCommandBus _host;
  StreamSubscription<CommandEvent>? _events;
  Object? _nodes;
  Object? _error;
  String? _pluginName;

  @override
  void initState() {
    super.initState();
    _host = ref.read(applicationHostProvider);
    _nodes = widget.preview;
    _pluginName = widget.title.isEmpty ? null : widget.title;
    _events = _host.events.listen(_handleEvent);
    if (_nodes == null || _pluginName == null) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = (await _execute(
        OronBoxCommand(method: 'plugin.get', params: {'id': widget.pluginId}),
      ) as Map).cast<String, Object?>();
      final page = detail['page'];
      if (!mounted) return;
      setState(() {
        _pluginName ??= detail['name']?.toString();
        _nodes ??= page ?? const <Object?>[];
        _error = null;
      });
    } catch (error) {
      if (mounted && _nodes == null) setState(() => _error = error);
    }
  }

  void _handleEvent(CommandEvent event) {
    if (event.event != 'plugin.ui' ||
        event.data['id']?.toString() != widget.pluginId ||
        event.data['page'] != true ||
        !mounted) {
      return;
    }
    setState(() {
      _nodes = event.data['nodes'];
      _error = null;
    });
  }

  Future<void> _invoke(String callback, [Object? value]) async {
    try {
      await _execute(
        OronBoxCommand(
          method: 'plugin.invoke',
          params: {
            'id': widget.pluginId,
            'callback': callback,
            if (value != null) 'value': value,
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorMessage(AppLocalizations.of(context)!, error),
          ),
        ),
      );
    }
  }

  Future<Object?> _execute(OronBoxCommand command) async {
    final result = await _host.execute(command);
    if (!result.ok) throw result.error!;
    return result.value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _pluginName ?? l10n.pluginFeatures;
    final body = _nodes == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _nodes == null
        ? ErrorStateView(
            message: localizedErrorMessage(l10n, _error),
            onRetry: _load,
          )
        : PluginUITree(
            root: _nodes,
            onInvoke: _invoke,
            contentPadding: EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              StyleConstants.pagePadding,
              StyleConstants.pagePadding,
              bottomContentPadding(context, extra: StyleConstants.pagePadding),
            ),
          );
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(title)),
      body: body,
    );
  }
}

class _PluginHeader extends StatelessWidget {
  const _PluginHeader({
    required this.plugin,
    required this.tabs,
    this.onClose,
    this.onDetach,
  });
  final Map<String, Object?> plugin;
  final TabController tabs;
  final VoidCallback? onClose;
  final VoidCallback? onDetach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final description = plugin['description']?.toString() ?? '';
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                onClose != null && onDetach != null
                    ? 96
                    : onClose != null || onDetach != null
                    ? 48
                    : 16,
                12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PluginIcon(base64: plugin['icon']?.toString(), size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plugin['name']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: color.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: tabs,
              dividerHeight: 0,
              tabs: [
                Tab(text: l10n.pluginFeatures),
                Tab(text: l10n.pluginDetails),
              ],
            ),
          ],
        ),
        if (onClose != null || onDetach != null)
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                if (onDetach != null)
                  IconButton(
                    onPressed: onDetach,
                    icon: const Icon(Icons.open_in_new),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Open in new window',
                  ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PluginInformation extends StatelessWidget {
  const _PluginInformation({required this.plugin, required this.onUninstall});
  final Map<String, Object?> plugin;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final website = plugin['website']?.toString();
    final permissions =
        (plugin['permissions'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageContainer(
          padding: const EdgeInsets.fromLTRB(
            StyleConstants.pagePadding,
            16,
            StyleConstants.pagePadding,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoGroup(
                title: l10n.pluginDetails,
                children: [
                  _InfoLine(
                    icon: Icons.person_outline,
                    label: l10n.pluginAuthor,
                    value: plugin['author']?.toString() ?? '',
                  ),
                  if (website != null && website.isNotEmpty)
                    _InfoLine(
                      icon: Icons.language,
                      label: l10n.pluginWebsite,
                      value: website,
                      onOpen: () {
                        final uri = Uri.tryParse(website);
                        if (uri != null) launchUrl(uri);
                      },
                    ),
                  _InfoLine(
                    icon: Icons.info_outline,
                    label: l10n.pluginVersion,
                    value: plugin['version']?.toString() ?? '',
                  ),
                  _InfoLine(
                    icon: Icons.numbers,
                    label: l10n.pluginApiLevel,
                    value: plugin['apiLevel']?.toString() ?? '',
                  ),
                ],
              ),
              _InfoGroup(
                title: l10n.pluginPermissions,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: permissions
                        .map((permission) => Chip(label: Text(permission)))
                        .toList(growable: false),
                  ),
                ],
              ),
              Center(
                child: FilledButton.icon(
                  onPressed: onUninstall,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.uninstall),
                  style: FilledButton.styleFrom(
                    backgroundColor: color.errorContainer,
                    foregroundColor: color.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.onOpen,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onOpen != null)
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
