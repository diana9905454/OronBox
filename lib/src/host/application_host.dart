import 'dart:async';

import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/host/tasks/task_queue.dart';

/// Owns OronBox application state and long-running tasks independently from
/// how callers reach it. Desktop exposes this module through IPC while mobile
/// keeps it in the GUI process.
class ApplicationHost implements OronBoxCommandBus {
  ApplicationHost(this.core, {this.onClose, this.beginTaskExecution}) {
    tasks = HostTaskQueue(
      core,
      onCancelRunning: core is ActiveOperationController
          ? (core as ActiveOperationController).cancelActiveOperation
          : null,
      beginExecution: beginTaskExecution,
      shouldRemoveCompleted: _shouldRemoveCompleted,
    );
    _coreSubscription = core.events.listen(_events.add);
    _taskSubscription = tasks.events.listen(_events.add);
  }

  final OronBoxCommandBus core;
  final FutureOr<void> Function()? onClose;
  final Future<Future<void> Function()> Function(HostTask)?
  beginTaskExecution;
  late final HostTaskQueue tasks;
  final _events = StreamController<CommandEvent>.broadcast();
  late final StreamSubscription<CommandEvent> _coreSubscription;
  late final StreamSubscription<CommandEvent> _taskSubscription;

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) {
    return runAsDiagnosticBackend(() async {
      switch (command.method) {
        case 'task.enqueue':
          return CommandResult.success({
            'taskId': tasks.enqueue(
              OronBoxCommand.fromJson(
                (command.params['command'] as Map).cast<String, Object?>(),
              ),
              held: command.params['held'] == true,
            ),
          });
        case 'queue.list':
          return CommandResult.success(tasks.list());
        case 'queue.get':
          return _taskResult(command.params['id']?.toString());
        case 'queue.wait':
          return _waitResult(command.params['id']?.toString());
        case 'queue.cancel':
          return CommandResult.success({
            'cancelled': tasks.cancel(command.params['id']?.toString() ?? ''),
          });
        case 'queue.clear':
          return _clearTasks();
        case 'queue.start':
          return CommandResult.success({'started': tasks.startHeld()});
        case 'queue.pause':
          return CommandResult.success({'held': tasks.holdPending()});
        case 'queue.retry':
          return CommandResult.success({
            'retried': tasks.retry(command.params['id']?.toString() ?? ''),
          });
        case 'queue.remove':
          return CommandResult.success({
            'removed': tasks.remove(command.params['id']?.toString() ?? ''),
          });
        default:
          return core.execute(command);
      }
    });
  }

  Future<void> cancelActiveOperation() async {
    final controller = core;
    if (controller is ActiveOperationController) {
      await (controller as ActiveOperationController).cancelActiveOperation();
    }
  }

  Future<bool> _shouldRemoveCompleted(
    HostTask task,
    CommandResult result,
  ) async {
    if (task.command.params['autoClean'] != true) return false;
    final setting = await core.execute(
      const OronBoxCommand(
        method: 'settings.get',
        params: {'key': 'disable_auto_clean'},
      ),
    );
    return setting.ok && (setting.value as Map)['value'] != true;
  }

  CommandResult _taskResult(String? id) {
    final task = tasks.get(id ?? '');
    return task == null
        ? const CommandResult.failure(
            CommandError('not_found', 'Task not found'),
          )
        : CommandResult.success(task.toJson());
  }

  Future<CommandResult> _waitResult(String? id) async {
    final task = await tasks.wait(id ?? '');
    return task == null
        ? const CommandResult.failure(
            CommandError('not_found', 'Task not found'),
          )
        : CommandResult.success(task.toJson());
  }

  CommandResult _clearTasks() {
    tasks.clear();
    return const CommandResult.success({'cleared': true});
  }

  Map<String, Object?> get taskSummary {
    final snapshot = tasks.list();
    return {
      'total': snapshot.length,
      'running': snapshot.where((task) => task['status'] == 'running').length,
      'pending': snapshot.where((task) => task['status'] == 'pending').length,
    };
  }

  @override
  Future<void> close() async {
    await _coreSubscription.cancel();
    await _taskSubscription.cancel();
    await tasks.close();
    await core.close();
    await onClose?.call();
    await _events.close();
  }
}

abstract interface class ActiveOperationController {
  Future<void> cancelActiveOperation();
}
