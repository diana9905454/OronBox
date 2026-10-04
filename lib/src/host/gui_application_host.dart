import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/command_bus/local_command_bus.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/background_task_guard.dart';
import 'package:oronbox/src/host/application_host.dart';

OronBoxCommandBus createGuiApplicationHost([ProviderContainer? container]) {
  final effectiveContainer = container ?? ProviderContainer();
  return ApplicationHost(
    LocalCommandBus(effectiveContainer),
    onClose: container == null ? effectiveContainer.dispose : null,
    beginTaskExecution: (task) async {
      final backgroundTask = await beginBackgroundTask(
        task.command.params['title']?.toString() ?? 'OronBox task',
      );
      return backgroundTask.end;
    },
  );
}
