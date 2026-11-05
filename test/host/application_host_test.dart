import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/host/application_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oronbox-app-host-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tempDir.path,
        );
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tempDir.delete(recursive: true);
  });

  test(
    'clients use the same host interface for direct and queued commands',
    () async {
      final core = _RecordingBus();
      final host = ApplicationHost(core);

      final direct = await host.execute(const OronBoxCommand(method: 'echo'));
      final queued = await host.execute(
        const OronBoxCommand(
          method: 'task.enqueue',
          params: {
            'command': {
              'method': 'install.local',
              'params': <String, Object?>{},
            },
          },
        ),
      );
      final taskId = (queued.value as Map)['taskId']!.toString();
      final completed = await host.execute(
        OronBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      );

      expect(direct.value, {'method': 'echo'});
      expect((completed.value as Map)['status'], 'completed');
      expect(core.methods, ['echo', 'install.local']);

      await host.close();
    },
  );

  test(
    'held GUI tasks remain in the host until a client starts them',
    () async {
      final core = _RecordingBus();
      final host = ApplicationHost(core);
      final queued = await host.execute(
        const OronBoxCommand(
          method: 'task.enqueue',
          params: {
            'held': true,
            'command': {
              'method': 'install.local',
              'params': <String, Object?>{},
            },
          },
        ),
      );
      final taskId = (queued.value as Map)['taskId']!.toString();

      await Future<void>.delayed(Duration.zero);
      final held = await host.execute(
        OronBoxCommand(method: 'queue.get', params: {'id': taskId}),
      );
      expect((held.value as Map)['status'], 'held');
      expect(core.methods, isEmpty);

      await host.execute(const OronBoxCommand(method: 'queue.start'));
      final completed = await host.execute(
        OronBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      );
      expect((completed.value as Map)['status'], 'completed');
      expect(core.methods, ['install.local']);

      await host.close();
    },
  );
}

class _RecordingBus implements OronBoxCommandBus {
  final methods = <String>[];
  final _events = StreamController<CommandEvent>.broadcast();

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    return CommandResult.success({'method': command.method});
  }

  @override
  Future<void> close() => _events.close();
}
