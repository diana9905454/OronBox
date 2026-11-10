import 'package:flutter/material.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';

class DebugConsole extends StatefulWidget {
  const DebugConsole({super.key, required this.records});
  final List<DiagnosticEvent> records;

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final _scroll = ScrollController();
  var _followTail = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackPosition);
    _scrollToTail();
  }

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_followTail && oldWidget.records.length != widget.records.length) {
      _scrollToTail();
    }
  }

  void _trackPosition() {
    if (!_scroll.hasClients) return;
    _followTail =
        _scroll.position.maxScrollExtent - _scroll.position.pixels < 48;
  }

  void _scrollToTail() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  void dispose() {
    _scroll
      ..removeListener(_trackPosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.records.isEmpty) {
      return const Center(child: Text('No logs'));
    }

    // A single selectable text surface preserves line boundaries when a
    // selection spans multiple records.  Selecting independent Text widgets
    // causes Flutter's semantics tree to copy them as one paragraph.
    final spans = <TextSpan>[];
    for (final record in widget.records) {
      final color = switch (record.level.name) {
        'SEVERE' => scheme.error,
        'WARNING' => context.appColors.warning,
        _ => scheme.onSurface,
      };
      final line = StringBuffer()
        ..write(record.time.toIso8601String())
        ..write('  ')
        ..write(record.level.name.padRight(7))
        ..write(' [${record.scope}] ${record.source}  ${record.message}');
      if (record.error != null) {
        line.write('\n${record.error}');
      }
      spans.add(
        TextSpan(
          text: '${line.toString()}\n',
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SelectionArea(
          child: SelectableText.rich(TextSpan(children: spans)),
        ),
      ),
    );
  }
}
