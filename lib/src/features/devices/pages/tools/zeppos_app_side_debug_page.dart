import 'dart:async';
import 'dart:convert';

import 'package:segmented_list/segmented_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_app_side_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

enum _MessageMode { text, json, hex }

enum _EventFilter { all, watchIn, watchOut, console, lifecycle, error }

class ZeppOsAppSideDebugPage extends ConsumerStatefulWidget {
  const ZeppOsAppSideDebugPage({super.key});

  @override
  ConsumerState<ZeppOsAppSideDebugPage> createState() =>
      _ZeppOsAppSideDebugPageState();
}

class _ZeppOsAppSideDebugPageState
    extends ConsumerState<ZeppOsAppSideDebugPage> {
  final _message = TextEditingController();
  final _search = TextEditingController();
  List<int> _cached = const [];
  List<int> _observed = const [];
  List<ZeppOsAppSideSessionInfo> _sessions = const [];
  List<ZeppOsAppSideDebugEvent> _events = const [];
  int? _selectedAppId;
  Timer? _timer;
  bool _busy = false;
  bool _refreshing = false;
  bool _watchOnly = false;
  _MessageMode _mode = _MessageMode.text;
  _EventFilter _filter = _EventFilter.all;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    _message.addListener(_editorChanged);
    _search.addListener(_editorChanged);
    Future.microtask(() => _refresh(showError: true));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(showError: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _message.removeListener(_editorChanged);
    _search.removeListener(_editorChanged);
    _message.dispose();
    _search.dispose();
    super.dispose();
  }

  void _editorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh({bool showError = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      final results = await Future.wait<Object>([
        manager.listZeppOsAppSides(),
        manager.observedZeppOsAppSideIds(),
        manager.zeppOsAppSideSessions(),
      ]);
      final cached = results[0] as List<int>;
      final observed = results[1] as List<int>;
      final sessions = results[2] as List<ZeppOsAppSideSessionInfo>;
      final ids = <int>{
        ...cached,
        ...observed,
        ...sessions.map((e) => e.appId),
      }.toList()..sort();
      final selected = ids.contains(_selectedAppId)
          ? _selectedAppId
          : ids.firstOrNull;
      final events = selected == null
          ? const <ZeppOsAppSideDebugEvent>[]
          : await manager.zeppOsAppSideEvents(selected);
      if (!mounted) return;
      setState(() {
        _cached = cached;
        _observed = ids;
        _sessions = sessions;
        _selectedAppId = selected;
        _events = events;
        _refreshError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(
        () => _refreshError = l10n.zeppOsDebugRefreshFailed(
          localizedErrorMessage(l10n, error),
        ),
      );
      if (showError) _show(error);
    } finally {
      _refreshing = false;
    }
  }

  Uint8List _parseMessage() {
    switch (_mode) {
      case _MessageMode.text:
        return Uint8List.fromList(utf8.encode(_message.text));
      case _MessageMode.json:
        final value = jsonDecode(_message.text);
        return Uint8List.fromList(utf8.encode(jsonEncode(value)));
      case _MessageMode.hex:
        var value = _message.text.replaceAll(RegExp(r'0[xX]'), '');
        value = value.replaceAll(RegExp(r'[\s,;:_-]+'), '');
        if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(value)) {
          throw FormatException(
            AppLocalizations.of(context)!.zeppOsDebugInvalidHex,
          );
        }
        return Uint8List.fromList([
          for (var i = 0; i < value.length; i += 2)
            int.parse(value.substring(i, i + 2), radix: 16),
        ]);
    }
  }

  Uint8List? get _previewBytes {
    try {
      return _parseMessage();
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(Future<void> Function(int id) action) async {
    final id = _selectedAppId;
    if (_busy || id == null) return;
    setState(() => _busy = true);
    try {
      await action(id);
      await _refresh();
    } catch (error) {
      _show(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(int appId) {
    setState(() {
      _selectedAppId = appId;
      _events = const [];
    });
    _refresh(showError: true);
  }

  Future<void> _clearEvents() async {
    final l10n = AppLocalizations.of(context)!;
    final id = _selectedAppId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.zeppOsDebugClearEventsTitle),
        content: Text(l10n.zeppOsDebugClearEventsDescription(_formatId(id))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.zeppOsDebugClearEvents),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      (id) =>
          ref.read(deviceManagerProvider.notifier).clearZeppOsAppSideEvents(id),
    );
  }

  void _loadEvent(ZeppOsAppSideDebugEvent event) {
    final payload = event.payload;
    if (payload == null) return;
    final text = _strictUtf8(payload);
    if (text != null) {
      try {
        final json = jsonDecode(text);
        setState(() {
          _mode = _MessageMode.json;
          _message.text = const JsonEncoder.withIndent('  ').convert(json);
        });
        return;
      } catch (_) {}
      if (_isReadable(text)) {
        setState(() {
          _mode = _MessageMode.text;
          _message.text = text;
        });
        return;
      }
    }
    setState(() {
      _mode = _MessageMode.hex;
      _message.text = _hex(payload);
    });
  }

  Iterable<ZeppOsAppSideDebugEvent> get _filteredEvents {
    final keyword = _search.text.trim().toLowerCase();
    return _events.reversed.where((event) {
      if (_watchOnly && event.source != 'watch') return false;
      final categoryMatches = switch (_filter) {
        _EventFilter.all => true,
        _EventFilter.watchIn =>
          event.source == 'watch' && event.direction != 'out',
        _EventFilter.watchOut =>
          event.source == 'watch' && event.direction == 'out',
        _EventFilter.console => event.type == 'console',
        _EventFilter.lifecycle => const {
          'open',
          'open_ack',
          'close',
          'start',
          'stop',
        }.contains(event.type),
        _EventFilter.error => event.type == 'error',
      };
      if (!categoryMatches) return false;
      if (keyword.isEmpty) return true;
      final payload = event.payload;
      final text = payload == null
          ? ''
          : utf8.decode(payload, allowMalformed: true);
      final haystack =
          '${event.type} ${event.message} ${event.direction ?? ''} '
                  '${event.source ?? ''} ${payload == null ? '' : _hex(payload)} $text'
              .toLowerCase();
      return haystack.contains(keyword);
    });
  }

  void _show(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizedErrorMessage(AppLocalizations.of(context)!, error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.read(deviceManagerProvider.notifier);
    final selected = _selectedAppId;
    final cached = selected != null && _cached.contains(selected);
    final session = _sessions
        .where((value) => value.appId == selected)
        .firstOrNull;
    final preview = _previewBytes;
    final events = _filteredEvents.take(300).toList();
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.zeppOsAppDebug),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _refresh(showError: true),
            tooltip: l10n.zeppOsDebugRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              StyleConstants.pagePadding,
            ),
            child: Column(
              children: [
                if (_refreshError != null) ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_refreshError!),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SectionHeader(title: l10n.zeppOsDebugAppList),
                if (_observed.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.zeppOsDebugNoApps),
                    ),
                  )
                else
                  SegmentedSection(
                    margin: EdgeInsetsDirectional.zero,
                    tiles: [
                      for (final id in _observed)
                        SegmentedTile<int>.radioTile(
                          radioValue: id,
                          groupValue: selected,
                          onChanged: (value) =>
                              value == null ? null : _select(value),
                          leading: Icon(
                            _cached.contains(id) ? Icons.code : Icons.code_off,
                          ),
                          title: Text(_formatId(id)),
                          description: Text(
                            '${_cached.contains(id) ? l10n.zeppOsDebugCached : l10n.zeppOsDebugNotCached} · '
                            '${_sessions.any((e) => e.appId == id) ? l10n.zeppOsDebugRuntimeRunning : l10n.zeppOsDebugRuntimeStopped}',
                          ),
                        ),
                    ],
                  ),
                if (selected != null) ...[
                  const SizedBox(height: StyleConstants.sectionSpacing),
                  _SessionCard(
                    session: session,
                    cached: cached,
                    events: _events,
                  ),
                  const SizedBox(height: StyleConstants.sectionSpacing),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(title: l10n.zeppOsDebugLocalRuntime),
                          Text(
                            !cached
                                ? l10n.zeppOsDebugCannotStart
                                : session == null
                                ? l10n.zeppOsDebugCanStart
                                : l10n.zeppOsDebugScriptRunning,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy || session != null || !cached
                                      ? null
                                      : () => _run(manager.startZeppOsAppSide),
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(l10n.zeppOsDebugStartQuickJs),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy || session == null
                                      ? null
                                      : () => _run(manager.stopZeppOsAppSide),
                                  icon: const Icon(Icons.stop),
                                  label: Text(l10n.stop),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: StyleConstants.sectionSpacing),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(title: l10n.zeppOsDebugMessageEditor),
                          SegmentedButton<_MessageMode>(
                            segments: [
                              ButtonSegment(
                                value: _MessageMode.text,
                                label: Text(l10n.zeppOsDebugUtf8Text),
                              ),
                              ButtonSegment(
                                value: _MessageMode.json,
                                label: Text('JSON'),
                              ),
                              ButtonSegment(
                                value: _MessageMode.hex,
                                label: Text('HEX'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (value) =>
                                setState(() => _mode = value.first),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _message,
                            minLines: 2,
                            maxLines: 6,
                            decoration: InputDecoration(
                              labelText: switch (_mode) {
                                _MessageMode.text => l10n.zeppOsDebugUtf8Text,
                                _MessageMode.json =>
                                  l10n.zeppOsDebugJsonCompact,
                                _MessageMode.hex => l10n.zeppOsDebugHexBytes,
                              },
                              hintText: _mode == _MessageMode.hex
                                  ? '01 02, 0xA0 FF'
                                  : null,
                              errorText: preview == null
                                  ? l10n.zeppOsDebugEncodingFailed
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preview == null
                                ? l10n.zeppOsDebugByteCountUnavailable
                                : l10n.zeppOsDebugBytePreview(
                                    preview.length,
                                    _hex(preview, limit: 96),
                                  ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed:
                                _busy || session == null || preview == null
                                ? null
                                : () => _run(
                                    (id) => manager.injectZeppOsAppSideMessage(
                                      id,
                                      _parseMessage(),
                                    ),
                                  ),
                            icon: const Icon(Icons.input),
                            label: Text(l10n.zeppOsDebugInjectLocal),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _busy ||
                                    session?.watchSessionOpen != true ||
                                    preview == null
                                ? null
                                : () => _run(
                                    (id) => manager.sendZeppOsAppSideMessage(
                                      id,
                                      _parseMessage(),
                                    ),
                                  ),
                            icon: const Icon(Icons.watch),
                            label: Text(
                              session?.watchSessionOpen == true
                                  ? l10n.zeppOsDebugSendToWatch
                                  : l10n.zeppOsDebugWaitingForWatch,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: l10n.zeppOsDebugEvents,
                    action: TextButton.icon(
                      onPressed: _busy || _events.isEmpty ? null : _clearEvents,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(l10n.zeppOsDebugClearCurrentApp),
                    ),
                  ),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.zeppOsDebugSearch,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in _EventFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(_filterLabel(l10n, item)),
                              selected: _filter == item,
                              onSelected: (_) => setState(() => _filter = item),
                            ),
                          ),
                        FilterChip(
                          label: Text(l10n.zeppOsDebugWatchOnly),
                          selected: _watchOnly,
                          onSelected: (value) =>
                              setState(() => _watchOnly = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (events.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.zeppOsDebugNoEvents),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final event in events)
                            ListTile(
                              dense: true,
                              leading: Icon(_eventIcon(event)),
                              title: Text(_eventText(event)),
                              subtitle: Text(
                                '${_time(event.timestamp)} · ${event.type}'
                                '${event.direction == null ? '' : ' · ${event.direction}'}'
                                '${event.source == null ? '' : ' · ${event.source}'}',
                              ),
                              trailing: event.payload == null
                                  ? null
                                  : PopupMenuButton<String>(
                                      tooltip: l10n.zeppOsDebugMessageActions,
                                      onSelected: (value) {
                                        final payload = event.payload!;
                                        if (value == 'load') _loadEvent(event);
                                        if (value == 'hex') {
                                          Clipboard.setData(
                                            ClipboardData(text: _hex(payload)),
                                          );
                                        }
                                        if (value == 'text') {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: utf8.decode(
                                                payload,
                                                allowMalformed: true,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'load',
                                          child: Text(
                                            l10n.zeppOsDebugLoadEditor,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'hex',
                                          child: Text(l10n.zeppOsDebugCopyHex),
                                        ),
                                        PopupMenuItem(
                                          value: 'text',
                                          child: Text(l10n.zeppOsDebugCopyText),
                                        ),
                                      ],
                                    ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.cached,
    required this.events,
  });

  final ZeppOsAppSideSessionInfo? session;
  final bool cached;
  final List<ZeppOsAppSideDebugEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = events.reversed.where((event) {
      return event.message.contains('自动启动') ||
          event.message.contains('脚本加载') ||
          event.message.contains('QuickJS');
    }).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.zeppOsDebugSessionStatus),
            Text(
              l10n.zeppOsDebugCachedScript(
                cached ? l10n.exists : l10n.notExists,
              ),
            ),
            Text(
              l10n.zeppOsDebugLocalRuntimeStatus(
                session == null ? l10n.notRunning : l10n.running,
              ),
            ),
            Text(
              l10n.zeppOsDebugWatchSession(
                session?.watchSessionOpen == true
                    ? l10n.zeppOsDebugWatchSessionOpen
                    : l10n.notOpen,
              ),
            ),
            if (session != null) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.zeppOsDebugRealHeader}：version ${session!.version} · port1 ${session!.port1} · '
                'port2 ${session!.port2} · extra ${session!.extra}',
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(l10n.zeppOsDebugLatestStartup(status.message)),
            ],
          ],
        ),
      ),
    );
  }
}

String _eventText(ZeppOsAppSideDebugEvent event) {
  final payload = event.payload;
  if (payload == null) return event.message;
  final text = utf8.decode(payload, allowMalformed: true);
  return _isReadable(text) && text.isNotEmpty
      ? '${event.message}\n${_hex(payload)}\n$text'
      : '${event.message}\n${_hex(payload)}';
}

IconData _eventIcon(ZeppOsAppSideDebugEvent event) => switch (event.type) {
  'error' => Icons.error_outline,
  'console' => Icons.terminal,
  'message' => event.direction == 'out' ? Icons.north_east : Icons.south_west,
  'open' || 'open_ack' || 'start' => Icons.play_circle_outline,
  'close' || 'stop' => Icons.stop_circle_outlined,
  _ => Icons.info_outline,
};

String _filterLabel(AppLocalizations l10n, _EventFilter filter) =>
    switch (filter) {
      _EventFilter.all => l10n.all,
      _EventFilter.watchIn => l10n.zeppOsDebugWatchInbound,
      _EventFilter.watchOut => l10n.zeppOsDebugWatchOutbound,
      _EventFilter.console => 'console',
      _EventFilter.lifecycle => l10n.zeppOsDebugLifecycle,
      _EventFilter.error => l10n.error,
    };

String _hex(List<int> bytes, {int? limit}) {
  final values = limit == null ? bytes : bytes.take(limit);
  final result = values
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  return limit != null && bytes.length > limit ? '$result …' : result;
}

String? _strictUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

bool _isReadable(String text) => text.runes.every(
  (rune) => rune == 9 || rune == 10 || rune == 13 || rune >= 32,
);

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:'
    '${value.second.toString().padLeft(2, '0')}';

String _formatId(int id) =>
    '0x${id.toRadixString(16).padLeft(8, '0').toUpperCase()}';
