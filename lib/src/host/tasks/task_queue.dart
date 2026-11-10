import 'dart:async';
import 'dart:convert';

import 'package:oronbox/src/core/storage/managed_temporary_files.dart';

import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'dart:typed_data';

class HostTaskQueue {
  HostTaskQueue(
    this.bus, {
    this.onCancelRunning,
    this.beginExecution,
    this.onCompleted,
    this.shouldRemoveCompleted,
    AppDataDirectory? storage,
  }) {
    _storage = storage == null
        ? openAppDataDirectory('tasks')
        : Future.value(storage);
    ready = _restore();
    unawaited(
      ready.catchError((Object error, StackTrace stack) {
        getLogger('HostTaskQueue')
            .warning('Task state restore failed', error, stack);
      }),
    );
  }

  static const _storageKey = 'daemon.tasks';
  final OronBoxCommandBus bus;
  final Future<void> Function()? onCancelRunning;
  final Future<Future<void> Function()> Function(HostTask)? beginExecution;
  final Future<void> Function(HostTask, CommandResult)? onCompleted;
  final Future<bool> Function(HostTask, CommandResult)? shouldRemoveCompleted;
  final _tasks = <String, HostTask>{};
  late final Future<AppDataDirectory> _storage;
  late final Future<void> ready;
  final _waiters = <String, List<Completer<HostTask>>>{};
  final _events = StreamController<CommandEvent>.broadcast();
  String? _runningId;
  bool _pumpScheduled = false;
  Future<void> _persistTail = Future<void>.value();
  Stream<CommandEvent> get events => _events.stream;

  List<Map<String, Object?>> list() =>
      _tasks.values.map((task) => task.toJson()).toList(growable: false)
        ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));

  String enqueue(OronBoxCommand command, {bool held = false}) {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}';
    final trackedCommand = _withProgressCorrelation(command, id);
    _tasks[id] = HostTask(
      id: id,
      command: trackedCommand,
      status: held ? 'held' : 'pending',
      createdAt: now,
    );
    _notify(_tasks[id]!);
    _schedulePump();
    return id;
  }

  void _schedulePump() {
    if (_pumpScheduled || _runningId != null) return;
    _pumpScheduled = true;
    scheduleMicrotask(() async {
      _pumpScheduled = false;
      await _pump();
    });
  }

  Future<void> _pump() async {
    try {
      await ready;
    } catch (_) {
      return;
    }
    if (_runningId != null) return;
    final next = _tasks.values
        .where((task) => task.status == 'pending')
        .firstOrNull;
    if (next == null) return;
    _runningId = next.id;
    await _run(next.id);
    _runningId = null;
    _schedulePump();
  }

  Future<void> _run(String id) => runAsDiagnosticBackend(() => _runTask(id));

  Future<void> _runTask(String id) async {
    var task = _tasks[id];
    if (task == null || task.status != 'pending') return;
    task = task.copyWith(status: 'running', startedAt: DateTime.now());
    _tasks[id] = task;
    _notify(task);
    final expectedOperationId = task.command.params['operationId']?.toString();
    final expectedPath = task.command.params['path']?.toString();
    final progressSubscription = bus.events.listen((event) {
      final eventOperationId = event.data['operationId']?.toString();
      final eventPath = event.data['path']?.toString();
      if (expectedOperationId != null &&
          eventOperationId != expectedOperationId) {
        return;
      }
      if (expectedOperationId == null &&
          expectedPath != null &&
          expectedPath.isNotEmpty &&
          eventPath != expectedPath) {
        return;
      }
      final raw = event.data['progress'];
      if (raw is! num) return;
      final progress = (raw <= 1 ? raw.toDouble() : raw.toDouble() / 100)
          .clamp(0, 1)
          .toDouble();
      final current = _tasks[id];
      if (current == null || current.status != 'running') return;
      if (progress < current.progress) return;
      if (progress == current.progress) return;
      final updated = current.copyWith(progress: progress);
      _tasks[id] = updated;
      _notify(updated, persist: false);
    });
    Future<void> Function()? endExecution;
    late CommandResult result;
    try {
      endExecution = await beginExecution?.call(task);
      result = await bus.execute(task.command);
    } catch (error) {
      result = CommandResult.failure(
        CommandError(
          'task_execution',
          error.toString(),
        ),
      );
    } finally {
      await progressSubscription.cancel();
      await endExecution?.call();
    }
    if (result.ok && onCompleted != null) {
      try {
        await onCompleted!(task, result);
      } catch (error) {
        result = CommandResult.failure(
          CommandError(
            'task_completion',
            error.toString(),
          ),
        );
      }
    }
    task = _tasks[id];
    if (task == null) return;
    final status = task.cancelRequested
        ? 'cancelled'
        : result.ok
        ? 'completed'
        : 'failed';
    task = task.copyWith(
      status: status,
      finishedAt: DateTime.now(),
      result: result.toJson(),
      progress: result.ok ? 1 : task.progress,
    );
    _tasks[id] = task;
    _notify(task);
    _completeWaiters(task);
    if (status == 'completed' &&
        await shouldRemoveCompleted?.call(task, result) == true) {
      remove(id);
    }
  }

  OronBoxCommand _withProgressCorrelation(OronBoxCommand command, String id) {
    if (command.method != 'install.local' &&
        command.method != 'resource.download') {
      return command;
    }
    if (command.params['operationId'] != null) return command;
    return OronBoxCommand(
      method: command.method,
      params: {...command.params, 'operationId': '${command.method}:$id'},
    );
  }

  bool cancel(String id) {
    final task = _tasks[id];
    if (task == null ||
        {'completed', 'failed', 'cancelled'}.contains(task.status)) {
      return false;
    }
    final updated = task.status == 'pending' || task.status == 'held'
        ? task.copyWith(status: 'cancelled', finishedAt: DateTime.now())
        : task.copyWith(cancelRequested: true);
    _tasks[id] = updated;
    _notify(updated);
    if (task.status == 'running') {
      unawaited(onCancelRunning?.call());
    }
    if (updated.status == 'cancelled') _completeWaiters(updated);
    return true;
  }

  int startHeld() {
    var count = 0;
    for (final entry in _tasks.entries.toList()) {
      if (entry.value.status != 'held' && entry.value.status != 'failed') {
        continue;
      }
      _tasks[entry.key] = entry.value.copyWith(
        status: 'pending',
        progress: 0,
        clearResult: true,
      );
      _notify(_tasks[entry.key]!);
      count += 1;
    }
    _schedulePump();
    return count;
  }

  int holdPending() {
    var count = 0;
    for (final entry in _tasks.entries.toList()) {
      if (entry.value.status != 'pending') continue;
      _tasks[entry.key] = entry.value.copyWith(status: 'held');
      _notify(_tasks[entry.key]!);
      count += 1;
    }
    return count;
  }

  bool retry(String id) {
    final task = _tasks[id];
    if (task == null || !{'failed', 'cancelled'}.contains(task.status)) {
      return false;
    }
    final updated = task.copyWith(
      status: 'pending',
      progress: 0,
      clearResult: true,
    );
    _tasks[id] = updated;
    _notify(updated);
    _schedulePump();
    return true;
  }

  HostTask? get(String id) => _tasks[id];

  Future<HostTask?> wait(String id) async {
    await ready;
    final task = _tasks[id];
    if (task == null) return null;
    if (_isTerminal(task.status)) return task;
    final completer = Completer<HostTask>();
    _waiters.putIfAbsent(id, () => []).add(completer);
    return completer.future;
  }

  void clear() {
    final removed = _tasks.values
        .where((task) => _isTerminal(task.status))
        .map((task) => task.id)
        .toList();
    for (final id in removed) {
      _releaseFiles(_tasks.remove(id)!);
    }
    _persist();
    for (final id in removed) {
      _events.add(CommandEvent('task.removed', data: {'id': id}));
    }
  }

  bool remove(String id) {
    final task = _tasks[id];
    if (task == null || !_isTerminal(task.status)) return false;
    _tasks.remove(id);
    _releaseFiles(task);
    _persist();
    _events.add(CommandEvent('task.removed', data: {'id': id}));
    return true;
  }

  void _releaseFiles(HostTask task) {
    final result = task.result?['result'];
    final candidates = {
      if (task.command.params['path'] is String)
        task.command.params['path'] as String,
      if (result is Map && result['path'] is String) result['path'] as String,
    };
    for (final path in candidates) {
      unawaited(
        ManagedTemporaryFiles.release(path, delete: false).catchError((
          Object error,
          StackTrace stack,
        ) {
          getLogger('HostTasks')
              .warning('Temporary file lease release failed', error, stack);
        }),
      );
    }
  }

  void _notify(HostTask task, {bool persist = true}) {
    if (persist) _persist();
    _events.add(CommandEvent('task', data: task.toJson()));
  }

  bool _isTerminal(String status) =>
      {'completed', 'failed', 'cancelled'}.contains(status);

  void _completeWaiters(HostTask task) {
    for (final waiter in _waiters.remove(task.id) ?? const []) {
      if (!waiter.isCompleted) waiter.complete(task);
    }
  }

  Future<void> _restore() async {
    final storage = await _storage;
    final bytes = await storage.read('state.json');
    final legacy =
        SharedPrefsService.instance.getStringList(_storageKey) ??
        const <String>[];
    final rows = bytes == null
        ? legacy
        : (jsonDecode(utf8.decode(bytes)) as List).cast<String>();
    if (bytes == null && legacy.isNotEmpty) {
      await storage.write(
        'legacy.json',
        Uint8List.fromList(utf8.encode(jsonEncode(legacy))),
      );
    }
    var droppedInstallTasks = false;
    for (final row in rows) {
      try {
        final task = HostTask.fromJson(
          (jsonDecode(row) as Map).cast<String, Object?>(),
        );
        // Install tasks never survive a restart: a half-finished install
        // against a possibly disconnected device is worse than a clean queue.
        if (task.command.method.startsWith('install.')) {
          droppedInstallTasks = true;
          continue;
        }
        _tasks.putIfAbsent(
          task.id,
          () => task.status == 'running'
              ? task.copyWith(
                  status: 'pending',
                  progress: 0,
                  cancelRequested: false,
                  clearStartedAt: true,
                  clearFinishedAt: true,
                  clearResult: true,
                )
              : task,
        );
      } catch (_) {}
    }
    if (droppedInstallTasks || bytes == null) _persist();
    _schedulePump();
  }

  Future<void> _persist() => _persistTail = _persistTail
      .then((_) async {
        await ready;
        final terminal =
            _tasks.values.where((task) => _isTerminal(task.status)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final keep = terminal.take(100).map((task) => task.id).toSet();
        final rows = _tasks.values
            .where(
              (task) => !_isTerminal(task.status) || keep.contains(task.id),
            )
            .map((task) => jsonEncode(task.toJson()))
            .toList();
        final bytes = Uint8List.fromList(utf8.encode(jsonEncode(rows)));
        final storage = await _storage;
        await storage.exclusive(() => storage.write('state.json', bytes));
      })
      .catchError((Object error, StackTrace stack) {
        getLogger('HostTaskQueue')
            .warning('Task state write failed', error, stack);
      });

  Future<void> close() async {
    await ready;
    for (final waiters in _waiters.values) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) {
          waiter.completeError(StateError('Daemon task queue closed'));
        }
      }
    }
    _waiters.clear();
    await _persistTail;
    await _events.close();
  }
}

class HostTask {
  const HostTask({
    required this.id,
    required this.command,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.cancelRequested = false,
    this.progress = 0,
    this.result,
  });

  final String id;
  final OronBoxCommand command;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final bool cancelRequested;
  final double progress;
  final Map<String, Object?>? result;

  HostTask copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? cancelRequested,
    Map<String, Object?>? result,
    double? progress,
    bool clearStartedAt = false,
    bool clearFinishedAt = false,
    bool clearResult = false,
  }) => HostTask(
    id: id,
    command: command,
    status: status ?? this.status,
    createdAt: createdAt,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
    cancelRequested: cancelRequested ?? this.cancelRequested,
    progress: progress ?? this.progress,
    result: clearResult ? null : result ?? this.result,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'command': command.toJson(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    if (cancelRequested) 'cancelRequested': true,
    'progress': progress,
    if (result != null) 'result': result,
  };

  factory HostTask.fromJson(Map<String, Object?> json) => HostTask(
    id: json['id']!.toString(),
    command: OronBoxCommand.fromJson(
      (json['command'] as Map).cast<String, Object?>(),
    ),
    status: json['status']!.toString(),
    createdAt: DateTime.parse(json['createdAt']!.toString()),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt']!.toString()),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt']!.toString()),
    cancelRequested: json['cancelRequested'] == true,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    result: (json['result'] as Map?)?.cast<String, Object?>(),
  );
}

typedef DaemonTaskQueue = HostTaskQueue;
typedef DaemonTask = HostTask;
