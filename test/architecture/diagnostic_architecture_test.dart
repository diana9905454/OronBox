import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:oronbox/src/app/window/window_launch_spec.dart';
import 'package:oronbox/src/command_bus/command_observability.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';

void main() {
  test('diagnostic records survive JSON serialization', () {
    final record = DiagnosticEvent(
      time: DateTime.utc(2026, 7, 17),
      level: Level.WARNING,
      source: 'Plugin.reader',
      process: DiagnosticProcess.backend,
      pluginId: 'reader',
      runtime: 'js',
      message: 'failed to open file',
      fields: const {'operation': 'file.pick'},
    );

    final restored = DiagnosticEvent.fromJson(record.toJson());
    expect(restored.level, Level.WARNING);
    expect(restored.scope, 'plugin:reader');
    expect(restored.runtime, 'js');
    expect(restored.fields, {'operation': 'file.pick'});
    expect(restored.format(), contains('[plugin:reader]'));
    expect(restored.format(), contains('operation=file.pick'));
  });

  test('window role parser isolates secondary window targets', () {
    final debug = WindowLaunchSpec.parse(const ['--window', 'debug']);
    final plugin = WindowLaunchSpec.parse(const [
      '--window',
      'plugin',
      '--plugin-id',
      'reader',
    ]);

    expect(debug.role, OronBoxWindowRole.debug);
    expect(plugin.role, OronBoxWindowRole.plugin);
    expect(plugin.targetId, 'reader');

    final multiWindowDebug = WindowLaunchSpec.parse(const [
      'multi_window',
      '1',
      '{"role":"debug"}',
    ]);
    expect(multiWindowDebug.role, OronBoxWindowRole.debug);
    expect(multiWindowDebug.windowId, '1');

    final multiWindowPlugin = WindowLaunchSpec.parse(const [
      'multi_window',
      '2',
      '{"role":"plugin","targetId":"reader"}',
    ]);
    expect(multiWindowPlugin.role, OronBoxWindowRole.plugin);
    expect(multiWindowPlugin.targetId, 'reader');
    expect(multiWindowPlugin.windowId, '2');
  });

  test('command log summaries exclude credentials and payload content', () {
    expect(
      safeCommandLogParams({
        'resource': 'resource-id',
        'fileName': '/private/path/preview.png',
        'bytes': [1, 2, 3],
        'accessToken': 'secret-token',
        'authkey': 'secret-authkey',
        'description': 'private creator content',
      }),
      {'resource': 'resource-id', 'fileName': 'preview.png'},
    );
    expect(
      safeCommandLogParams({
        'command': {
          'method': 'creator.upload',
          'params': {
            'bytes': [1, 2, 3],
            'path': '/private/file',
          },
        },
      }),
      {'command': 'creator.upload'},
    );
  });
}
