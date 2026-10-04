import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/host/tasks/task_queue.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  setUp(() => SharedPrefsService.instance.remove('daemon.tasks'));

  test('runs queued commands strictly one at a time', () async {
    final bus = _DelayedBus();
    final queue = DaemonTaskQueue(bus);
    final first = queue.enqueue(const OronBoxCommand(method: 'first'));
    final second = queue.enqueue(const OronBoxCommand(method: 'second'));

    expect((await queue.wait(first))?.status, 'completed');
    expect((await queue.wait(second))?.status, 'completed');
    expect(bus.maxActive, 1);
    expect(bus.methods, ['first', 'second']);
    await queue.close();
  });

  test('cancelling a running task invokes the cancellation hook', () async {
    final bus = _BlockingBus();
    late final DaemonTaskQueue queue;
    queue = DaemonTaskQueue(bus, onCancelRunning: () async => bus.release());
    final id = queue.enqueue(const OronBoxCommand(method: 'install.local'));
    await bus.started.future;

    expect(queue.cancel(id), isTrue);
    expect((await queue.wait(id))?.status, 'cancelled');
    expect(bus.cancelled, isTrue);
    await queue.close();
  });

  test('wraps task execution in the configured platform lease', () async {
    final bus = _DelayedBus();
    var activeLeases = 0;
    final queue = DaemonTaskQueue(
      bus,
      beginExecution: (_) async {
        activeLeases += 1;
        return () async {
          activeLeases -= 1;
        };
      },
    );

    final id = queue.enqueue(const OronBoxCommand(method: 'install.local'));
    expect((await queue.wait(id))?.status, 'completed');
    expect(activeLeases, 0);
    await queue.close();
  });

  test('preserves actual progress updates below five percent', () async {
    final bus = _ProgressBus([
      const _ProgressEvent(.01, path: '/tmp/resource.bin'),
      const _ProgressEvent(.02, path: '/tmp/resource.bin'),
      const _ProgressEvent(.03, path: '/tmp/resource.bin'),
    ]);
    final queue = DaemonTaskQueue(bus);
    final progress = <double>[];
    final subscription = queue.events.listen((event) {
      if (event.event != 'task') return;
      final value = event.data['progress'];
      if (value is num && value > 0 && value < 1) {
        progress.add(value.toDouble());
      }
    });

    final id = queue.enqueue(
      const OronBoxCommand(
        method: 'install.local',
        params: {'path': '/tmp/resource.bin'},
      ),
    );
    await queue.wait(id);

    expect(progress, [.01, .02, .03]);
    await subscription.cancel();
    await queue.close();
  });

  test('ignores progress from concurrent tasks and backward updates', () async {
    final bus = _ProgressBus([
      const _ProgressEvent(.4, path: '/tmp/current.bin'),
      const _ProgressEvent(
        .9,
        path: '/tmp/other.bin',
        operationId: 'resource.download:other',
      ),
      const _ProgressEvent(.2, path: '/tmp/current.bin'),
      const _ProgressEvent(.7, path: '/tmp/current.bin'),
    ]);
    final queue = DaemonTaskQueue(bus);
    final progress = <double>[];
    final subscription = queue.events.listen((event) {
      if (event.event != 'task') return;
      final value = event.data['progress'];
      if (value is num && value > 0 && value < 1) {
        progress.add(value.toDouble());
      }
    });

    final id = queue.enqueue(
      const OronBoxCommand(
        method: 'install.local',
        params: {'path': '/tmp/current.bin'},
      ),
    );
    await queue.wait(id);

    expect(progress, [.4, .7]);
    await subscription.cancel();
    await queue.close();
  });

  test('resumes a task that was running before host restart', () async {
    final task = DaemonTask(
      id: 'recovered',
      command: const OronBoxCommand(method: 'resource.download'),
      status: 'running',
      createdAt: DateTime(2026),
      startedAt: DateTime(2026, 1, 1, 0, 1),
      progress: .5,
    );
    await SharedPrefsService.instance.setStringList('daemon.tasks', [
      jsonEncode(task.toJson()),
    ]);
    final bus = _DelayedBus();
    final queue = DaemonTaskQueue(bus);

    final recovered = await queue.wait('recovered');
    expect(recovered?.status, 'completed');
    expect(bus.methods, ['resource.download']);
    await queue.close();
  });

  test('drops persisted install tasks on restore, keeps other tasks', () async {
    DaemonTask task(String id, String method, String status) => DaemonTask(
      id: id,
      command: OronBoxCommand(method: method),
      status: status,
      createdAt: DateTime(2026),
    );
    await SharedPrefsService.instance.setStringList('daemon.tasks', [
      jsonEncode(task('install-pending', 'install.local', 'pending').toJson()),
      jsonEncode(task('install-running', 'install.local', 'running').toJson()),
      jsonEncode(task('install-failed', 'install.local', 'failed').toJson()),
      jsonEncode(task('download', 'resource.download', 'held').toJson()),
    ]);
    final bus = _DelayedBus();
    final queue = DaemonTaskQueue(bus);

    expect(queue.get('install-pending'), isNull);
    expect(queue.get('install-running'), isNull);
    expect(queue.get('install-failed'), isNull);
    expect(queue.get('download')?.status, 'held');
    await queue.close();

    // The purge is also written back, so a second restart stays clean.
    final stored = SharedPrefsService.instance.getStringList('daemon.tasks')!;
    expect(stored, hasLength(1));
    expect(stored.single, contains('resource.download'));
  });
}

class _DelayedBus implements OronBoxCommandBus {
  int active = 0;
  int maxActive = 0;
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    active += 1;
    maxActive = active > maxActive ? active : maxActive;
    methods.add(command.method);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active -= 1;
    return const CommandResult.success();
  }

  @override
  Future<void> close() async {}
}

class _BlockingBus implements OronBoxCommandBus {
  final started = Completer<void>();
  final _release = Completer<void>();
  bool cancelled = false;

  void release() {
    cancelled = true;
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    return const CommandResult.failure(
      CommandError('cancelled', 'Operation was cancelled'),
    );
  }

  @override
  Future<void> close() async {}
}

class _ProgressBus implements OronBoxCommandBus {
  _ProgressBus(this.progress);

  final List<_ProgressEvent> progress;
  final _events = StreamController<CommandEvent>.broadcast(sync: true);

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    for (final item in progress) {
      _events.add(
        CommandEvent(
          'progress',
          data: {
            'progress': item.value,
            if (item.path != null) 'path': item.path,
            'operationId': item.operationId ?? command.params['operationId'],
          },
        ),
      );
    }
    return const CommandResult.success();
  }

  @override
  Future<void> close() => _events.close();
}

class _ProgressEvent {
  const _ProgressEvent(this.value, {this.path, this.operationId});

  final double value;
  final String? path;
  final String? operationId;
}
