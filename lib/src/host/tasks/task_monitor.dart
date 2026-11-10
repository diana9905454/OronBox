import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/tasks/task_models.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final hostTasksProvider = StreamProvider<List<HostTaskView>>(
  (ref) => watchHostTasks(ref.watch(applicationHostProvider)),
);

final daemonTasksProvider = hostTasksProvider;

Stream<List<HostTaskView>> watchHostTasks(OronBoxCommandBus host) async* {
  final tasks = <String, HostTaskView>{};
  Future<void> load() async {
    final initial = await host.execute(
      const OronBoxCommand(method: 'queue.list'),
    );
    if (!initial.ok || initial.value is! List) return;
    tasks.clear();
    for (final row in (initial.value as List).whereType<Map>()) {
      final task = HostTaskView.fromJson(row.cast<String, Object?>());
      tasks[task.id] = task;
    }
  }

  await load();
  yield _sorted(tasks);
  final updates = StreamController<List<HostTaskView>>();
  final subscription = host.events.listen((event) {
    if (event.event == 'host.connected') {
      unawaited(
        load().then((_) {
          if (!updates.isClosed) updates.add(_sorted(tasks));
        }),
      );
      return;
    }
    if (event.event == 'task.removed') {
      tasks.remove(event.data['id']?.toString());
      updates.add(_sorted(tasks));
      return;
    }
    if (event.event != 'task') return;
    final task = HostTaskView.fromJson(event.data);
    tasks[task.id] = task;
    updates.add(_sorted(tasks));
  });
  try {
    yield* updates.stream;
  } finally {
    await subscription.cancel();
    await updates.close();
  }
}

List<HostTaskView> _sorted(Map<String, HostTaskView> tasks) =>
    tasks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

Future<void> cancelHostTask(OronBoxCommandBus host, String id) =>
    _taskCommand(host, 'queue.cancel', id);
Future<void> retryHostTask(OronBoxCommandBus host, String id) =>
    _taskCommand(host, 'queue.retry', id);
Future<void> removeHostTask(OronBoxCommandBus host, String id) =>
    _taskCommand(host, 'queue.remove', id);
Future<void> clearHostTasks(OronBoxCommandBus host) async {
  final result = await host.execute(
    const OronBoxCommand(method: 'queue.clear'),
  );
  if (!result.ok) {
    throw result.error!;
  }
}

Future<void> _taskCommand(
  OronBoxCommandBus host,
  String method,
  String id,
) async {
  final result = await host.execute(
    OronBoxCommand(method: method, params: {'id': id}),
  );
  if (!result.ok) {
    throw result.error!;
  }
}
