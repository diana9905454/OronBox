import 'dart:async';

import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/tasks/task_models.dart';

typedef HostTaskDecoder<T> = T? Function(HostTaskView view);
typedef HostTaskId<T> = String Function(T task);

typedef DaemonTaskDecoder<T> = HostTaskDecoder<T>;
typedef DaemonTaskId<T> = HostTaskId<T>;
typedef DaemonTaskFeed<T> = HostTaskFeed<T>;

/// Projects one host task method into a typed, live task list.
class HostTaskFeed<T> {
  HostTaskFeed({
    required this.host,
    required this.method,
    required this.decode,
    required this.taskId,
    required this.onChanged,
  });

  final OronBoxCommandBus host;
  final String method;
  final HostTaskDecoder<T> decode;
  final HostTaskId<T> taskId;
  final void Function(List<T> tasks) onChanged;

  StreamSubscription<CommandEvent>? _subscription;
  List<T> _tasks = const [];
  int _eventRevision = 0;
  bool _disposed = false;

  Future<void> start() async {
    _subscription ??= host.events.listen(_handleEvent);
    await refresh();
  }

  Future<void> refresh() async {
    final revision = _eventRevision;
    final result = await host.execute(
      const OronBoxCommand(method: 'queue.list'),
    );
    if (!result.ok || result.value is! List || _disposed) return;
    // A task event may arrive while queue.list is in flight. The event has
    // already applied the newer progress value, so never replace it with the
    // older snapshot returned by the request.
    if (revision != _eventRevision) return;
    _tasks = (result.value as List)
        .whereType<Map>()
        .map((row) => HostTaskView.fromJson(row.cast<String, Object?>()))
        .where((view) => view.method == method)
        .map(decode)
        .whereType<T>()
        .toList();
    _publish();
  }

  Future<void> remove(String id, {required bool terminal}) async {
    if (!terminal) {
      await _execute('queue.cancel', id);
    }
    await _execute('queue.remove', id);
  }

  Future<void> retry(String id) => _execute('queue.retry', id);

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
  }

  Future<void> _execute(String command, String id) async {
    final result = await host.execute(
      OronBoxCommand(method: command, params: {'id': id}),
    );
    if (!result.ok) {
      throw result.error!;
    }
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'host.connected') {
      _eventRevision += 1;
      unawaited(refresh());
      return;
    }
    if (event.event == 'task.removed') {
      _eventRevision += 1;
      final id = event.data['id']?.toString();
      _tasks = _tasks.where((task) => taskId(task) != id).toList();
      _publish();
      return;
    }
    if (event.event != 'task') return;
    _eventRevision += 1;
    final view = HostTaskView.fromJson(event.data);
    if (view.method != method) return;
    final task = decode(view);
    if (task == null) return;
    final tasks = [..._tasks];
    final index = tasks.indexWhere((item) => taskId(item) == taskId(task));
    if (index < 0) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    _tasks = tasks;
    _publish();
  }

  void _publish() {
    if (!_disposed) onChanged(List.unmodifiable(_tasks));
  }
}
