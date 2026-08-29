import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/theme/dynamic_color_adapter.dart';
import 'package:oronbox/src/app/theme/system_accent_color.dart';
import 'package:oronbox/src/app/window/secondary_window_host.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/debug/widgets/debug_console.dart';
import 'package:oronbox/src/features/debug/widgets/debug_inspectors.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:flutter/material.dart' as material_ui;

final _desktopAccentColorProvider = FutureProvider<Color?>((ref) {
  final source = ref.watch(
    themeSettingsProvider.select((settings) {
      return settings.desktopAccentColorSource;
    }),
  );
  return loadDesktopAccentColor(source);
});

class DebugWindowApp extends ConsumerWidget {
  const DebugWindowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeSettingsProvider);
    final localeSettings = ref.watch(localeSettingsProvider);
    final desktopAccentColor = ref
        .watch(_desktopAccentColorProvider)
        .maybeWhen(data: (color) => color, orElse: () => null);

    return DynamicColorBuilder(
      builder:
          (
            material_ui.ColorScheme? lightDynamic,
            material_ui.ColorScheme? darkDynamic,
          ) {
            final lightFlutterDynamic = toFlutterColorScheme(lightDynamic);
            final darkFlutterDynamic = toFlutterColorScheme(darkDynamic);
            final useDynamicColor = themeSettings.useDynamicColor;
            final lightColorScheme = useDynamicColor
                ? lightFlutterDynamic ??
                      _accentColorScheme(desktopAccentColor, Brightness.light)
                : _seedColorScheme(
                    themeSettings.customSeedColor,
                    Brightness.light,
                  );
            final darkColorScheme = useDynamicColor
                ? darkFlutterDynamic ??
                      _accentColorScheme(desktopAccentColor, Brightness.dark)
                : _seedColorScheme(
                    themeSettings.customSeedColor,
                    Brightness.dark,
                  );

            return MaterialApp(
              title: 'OronBox DevTools',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildLightTheme(colorScheme: lightColorScheme),
              darkTheme: themeSettings.isOledDark
                  ? AppTheme.buildOledDarkTheme(colorScheme: darkColorScheme)
                  : AppTheme.buildDarkTheme(colorScheme: darkColorScheme),
              themeMode: themeSettings.materialThemeMode,
              locale: localeSettings.materialLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SecondaryWindowHost(
                role: 'debug',
                child: DebugWindowPage(),
              ),
            );
          },
    );
  }

  ColorScheme? _accentColorScheme(Color? accentColor, Brightness brightness) {
    if (accentColor == null) {
      return null;
    }
    return _seedColorScheme(accentColor, brightness);
  }

  ColorScheme _seedColorScheme(Color seedColor, Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}

class DebugWindowPage extends ConsumerStatefulWidget {
  const DebugWindowPage({super.key, this.embedded = false});

  /// Embedded mode is used inside the main app (Android): adds an app bar
  /// with back navigation and switches to the narrow-screen layout.
  final bool embedded;

  @override
  ConsumerState<DebugWindowPage> createState() => _DebugWindowPageState();
}

class _DebugWindowPageState extends ConsumerState<DebugWindowPage>
    with SingleTickerProviderStateMixin {
  late final OronBoxCommandBus _host;
  late final TabController _tabs;
  StreamSubscription<CommandEvent>? _events;
  final _records = <DiagnosticEvent>[];
  final _plugins = <String, Map<String, Object?>>{};
  final _protocolTraces = <Map<String, Object?>>[];
  final _pendingProtocolTraces = <Map<String, Object?>>[];
  Timer? _protocolTraceFlushTimer;
  final _search = TextEditingController();
  String _source = 'all';
  String _level = 'ALL';
  bool _paused = false;
  bool _protocolTraceEnabled = false;
  bool _batterySyncPaused = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _host = ref.read(applicationHostProvider);
    _events = _host.events.listen(_onEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    _events?.cancel();
    _protocolTraceFlushTimer?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _host.execute(
        const OronBoxCommand(method: 'debug.snapshot'),
      );
      if (!result.ok) {
        throw result.error!;
      }
      final snapshot = (result.value as Map).cast<String, Object?>();
      final records = (snapshot['records'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => DiagnosticEvent.fromJson(value.cast()))
          .toList();
      final plugins = (snapshot['plugins'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, Object?>());
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(records);
        _plugins
          ..clear()
          ..addEntries(
            plugins.map((plugin) => MapEntry(plugin['id'].toString(), plugin)),
          );
        if (_source.startsWith('plugin:') && _selectedPlugin == null) {
          _source = 'all';
        }
        _error = null;
        _protocolTraceEnabled = snapshot['protocolTraceEnabled'] == true;
        _batterySyncPaused = snapshot['batterySyncPaused'] == true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _onEvent(CommandEvent event) {
    if (event.event == 'debug.log' && !_paused) {
      final value = event.data['record'];
      if (value is! Map || !mounted) return;
      setState(() {
        _records.add(DiagnosticEvent.fromJson(value.cast()));
        if (_records.length > 2000) _records.removeAt(0);
      });
    } else if (event.event == 'debug.plugin.changed') {
      final value = event.data['plugin'];
      if (value is! Map || !mounted) return;
      final plugin = value.cast<String, Object?>();
      setState(() => _plugins[plugin['id'].toString()] = plugin);
    } else if (event.event == 'debug.protocol_trace' &&
        _protocolTraceEnabled &&
        mounted) {
      _pendingProtocolTraces.add(event.data);
      _protocolTraceFlushTimer ??= Timer(
        const Duration(milliseconds: 100),
        _flushProtocolTraces,
      );
    }
  }

  void _flushProtocolTraces() {
    _protocolTraceFlushTimer = null;
    if (!mounted || !_protocolTraceEnabled || _pendingProtocolTraces.isEmpty) {
      _pendingProtocolTraces.clear();
      return;
    }
    final pending = List<Map<String, Object?>>.from(_pendingProtocolTraces);
    _pendingProtocolTraces.clear();
    setState(() {
      _protocolTraces.addAll(pending);
      if (_protocolTraces.length > 2000) {
        _protocolTraces.removeRange(0, _protocolTraces.length - 2000);
      }
    });
  }

  Future<void> _setProtocolTrace(bool enabled) async {
    final result = await _host.execute(
      OronBoxCommand(
        method: 'debug.protocolTrace.set',
        params: {'enabled': enabled},
      ),
    );
    if (!mounted || !result.ok) return;
    final value = result.value;
    setState(() {
      _protocolTraceEnabled = value is Map ? value['enabled'] == true : enabled;
      _batterySyncPaused = value is Map
          ? value['batterySyncPaused'] == true
          : _batterySyncPaused;
      if (!enabled) {
        _protocolTraceFlushTimer?.cancel();
        _protocolTraceFlushTimer = null;
        _pendingProtocolTraces.clear();
        _protocolTraces.clear();
      }
    });
  }

  List<DiagnosticEvent> get _visibleRecords {
    final query = _search.text.trim().toLowerCase();
    return _records
        .where((record) {
          if (_source != 'all' && record.scope != _source) return false;
          if (_level != 'ALL' && record.level.name != _level) return false;
          return query.isEmpty ||
              record.message.toLowerCase().contains(query) ||
              record.source.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Map<String, Object?>? get _selectedPlugin => _source.startsWith('plugin:')
      ? _plugins[_source.substring('plugin:'.length)]
      : null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isWide = useWideLayout(MediaQuery.sizeOf(context).width);
    final content = Column(
      children: [
        _Toolbar(
          search: _search,
          level: _level,
          paused: _paused,
          onRefresh: _load,
          onSearch: () => setState(() {}),
          onLevel: (value) => setState(() => _level = value),
          onPause: () => setState(() => _paused = !_paused),
          onClear: () => setState(_records.clear),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.terminal), text: 'Console'),
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Layout'),
            Tab(icon: Icon(Icons.memory), text: 'Runtime'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Storage'),
            Tab(icon: Icon(Icons.account_tree), text: 'Protocol Trace'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error.toString()))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    DebugConsole(records: _visibleRecords),
                    DebugLayoutInspector(
                      nodes: debugLayoutNodes(_selectedPlugin?['layout']),
                    ),
                    DebugRuntimeInspector(
                      host: _host,
                      source: _source,
                      plugin: _selectedPlugin,
                    ),
                    DebugStorageInspector(
                      host: _host,
                      source: _source,
                      plugin: _selectedPlugin,
                    ),
                    _ProtocolTraceInspector(
                      enabled: _protocolTraceEnabled,
                      batterySyncPaused: _batterySyncPaused,
                      traces: _protocolTraces,
                      onToggle: _setProtocolTrace,
                      onClear: () => setState(() {
                        _pendingProtocolTraces.clear();
                        _protocolTraces.clear();
                      }),
                    ),
                  ],
                ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? SysAppBar(secondary: true, title: Text(l10n.devTools))
          : null,
      body: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Material(
                    color: colors.surfaceContainerLow,
                    child: _SourceList(
                      source: _source,
                      records: _records,
                      plugins: _plugins,
                      onSelected: (value) => setState(() => _source = value),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : Column(
              children: [
                _SourceChips(
                  source: _source,
                  records: _records,
                  plugins: _plugins,
                  onSelected: (value) => setState(() => _source = value),
                ),
                const Divider(height: 1),
                Expanded(child: content),
              ],
            ),
    );
  }
}

List<Map<String, Object?>> debugLayoutNodes(Object? layout) {
  final roots = layout is List
      ? layout.whereType<Map>()
      : layout is Map
      ? <Map>[layout]
      : const <Map>[];
  final nodes = <Map<String, Object?>>[];
  void visit(Map<dynamic, dynamic> raw) {
    final node = raw.cast<String, Object?>();
    nodes.add(node);
    final children = node['children'];
    if (children is List) {
      for (final child in children.whereType<Map>()) {
        visit(child);
      }
    }
  }

  for (final root in roots) {
    visit(root);
  }
  return nodes;
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({
    required this.source,
    required this.records,
    required this.plugins,
    required this.onSelected,
  });

  final String source;
  final List<DiagnosticEvent> records;
  final Map<String, Map<String, Object?>> plugins;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(String value) => value == 'all'
        ? records.length
        : records.where((record) => record.scope == value).length;
    final entries = <(String, String)>[
      ('all', 'All'),
      ('frontend', 'Frontend'),
      ('backend', 'Backend'),
      for (final plugin in plugins.values)
        (
          'plugin:${plugin['id']}',
          plugin['name']?.toString() ?? plugin['id'].toString(),
        ),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                selected: source == entry.$1,
                onSelected: (_) => onSelected(entry.$1),
                label: Text('${entry.$2} ${count(entry.$1)}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProtocolTraceInspector extends StatelessWidget {
  const _ProtocolTraceInspector({
    required this.enabled,
    required this.batterySyncPaused,
    required this.traces,
    required this.onToggle,
    required this.onClear,
  });

  final bool enabled;
  final bool batterySyncPaused;
  final List<Map<String, Object?>> traces;
  final Future<void> Function(bool enabled) onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Protocol trace'),
          subtitle: const Text(
            'Decode Xiaomi transport, encrypted PB and protocol payloads',
          ),
          value: enabled,
          onChanged: (value) => onToggle(value),
        ),
        ListTile(
          dense: true,
          leading: Icon(batterySyncPaused ? Icons.pause_circle : Icons.sync),
          title: Text(
            batterySyncPaused
                ? 'Background synchronization paused'
                : 'Background synchronization running',
          ),
          trailing: TextButton(onPressed: onClear, child: const Text('Clear')),
        ),
        const Divider(height: 1),
        Expanded(
          child: traces.isEmpty
              ? const Center(child: Text('No protocol events captured'))
              : SelectionArea(
                  child: ListView.builder(
                    itemCount: traces.length,
                    itemBuilder: (context, index) {
                      final trace = traces[traces.length - index - 1];
                      final direction =
                          trace['direction']?.toString() ??
                          trace['operation']?.toString() ??
                          '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: Text(
                          '${trace['time'] ?? ''}  '
                          '$direction  '
                          '${trace['layer'] ?? ''}\n'
                          '${_formatProtocolTrace(trace)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

String _formatProtocolTrace(Map<String, Object?> trace) {
  final fields = <String>[];
  for (final entry in trace.entries) {
    if ({'time', 'direction', 'layer', 'deviceId'}.contains(entry.key)) {
      continue;
    }
    fields.add('${entry.key}=${entry.value}');
  }
  return fields.join('  ');
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.source,
    required this.records,
    required this.plugins,
    required this.onSelected,
  });

  final String source;
  final List<DiagnosticEvent> records;
  final Map<String, Map<String, Object?>> plugins;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(String value) => value == 'all'
        ? records.length
        : records.where((record) => record.scope == value).length;
    final entries = <(String, String, IconData)>[
      ('all', 'All sources', Icons.all_inclusive),
      ('frontend', 'Frontend', Icons.web_asset_outlined),
      ('backend', 'Backend', Icons.dns_outlined),
      for (final plugin in plugins.values)
        (
          'plugin:${plugin['id']}',
          plugin['name']?.toString() ?? plugin['id'].toString(),
          Icons.extension_outlined,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text('SOURCES', style: TextStyle(fontSize: 11)),
        ),
        for (final entry in entries)
          ListTile(
            dense: true,
            selected: source == entry.$1,
            leading: Icon(entry.$3, size: 19),
            title: Text(entry.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(count(entry.$1).toString()),
            onTap: () => onSelected(entry.$1),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.level,
    required this.paused,
    required this.onRefresh,
    required this.onSearch,
    required this.onLevel,
    required this.onPause,
    required this.onClear,
  });

  final TextEditingController search;
  final String level;
  final bool paused;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final ValueChanged<String> onLevel;
  final VoidCallback onPause;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: search,
            onChanged: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Filter logs',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: level,
            items: const ['ALL', 'FINE', 'INFO', 'WARNING', 'SEVERE']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => onLevel(value!),
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: onPause,
          tooltip: paused ? 'Resume' : 'Pause',
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
        ),
        IconButton(
          onPressed: onClear,
          tooltip: 'Clear',
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}
