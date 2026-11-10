import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/storage/managed_temporary_files.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/host/tasks/task_models.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';
import 'package:oronbox/src/features/resources/services/host_task_feed.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

export 'package:oronbox/src/features/resources/services/resource_install_service.dart'
    show LocalDeviceInstallType, ResourceTaskStatus;

enum QueueRunStatus { pending, running, stopping }

class InstallTask {
  const InstallTask({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.installMode = ResourceInstallMode.automatic,
    required this.filePath,
    this.bytes,
    this.analysis,
    this.identifier,
    this.resource,
    this.file,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String id;
  final String name;
  final String description;
  final LocalDeviceInstallType type;
  final ResourceInstallMode installMode;
  final String filePath;
  final Uint8List? bytes;

  /// Analysis result resolved before this task entered the queue; reused for
  /// installation so the payload is only parsed once.
  final ResourcePayloadAnalysis? analysis;

  /// Watchface identifier override for reinstalls (empty means default).
  final String? identifier;

  final CommunityResourceDetail? resource;
  final CommunityResourceFile? file;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;
}

class InstallQueueState {
  const InstallQueueState({
    this.tasks = const [],
    this.runStatus = QueueRunStatus.pending,
    this.loaded = false,
  });

  final List<InstallTask> tasks;
  final QueueRunStatus runStatus;

  /// Whether the daemon has returned the first complete task snapshot.
  ///
  /// An empty task list before that snapshot is not proof that the queue is
  /// empty. Consumers that coordinate device work must wait for this flag.
  final bool loaded;

  bool get isRunning => runStatus == QueueRunStatus.running;
  bool get isStopping => runStatus == QueueRunStatus.stopping;
  bool get hasActiveTasks => tasks.any(
    (task) =>
        task.status == ResourceTaskStatus.pending ||
        task.status == ResourceTaskStatus.downloading ||
        task.status == ResourceTaskStatus.installing,
  );
  bool get hasRunnableTasks => tasks.any(
    (task) =>
        task.status == ResourceTaskStatus.pending ||
        task.status == ResourceTaskStatus.failed,
  );
  double get progress => tasks.isEmpty
      ? 1
      : tasks.fold<double>(0, (sum, task) => sum + task.progress) /
            tasks.length;
}

class InstallQueueNotifier extends Notifier<InstallQueueState> {
  DaemonTaskFeed<InstallTask>? _feed;

  @override
  InstallQueueState build() {
    if (kIsWeb) {
      ref.listen(deviceManagerProvider, (_, _) {});
      return const InstallQueueState(loaded: true);
    }
    final host = ref.watch(applicationHostProvider);
    _feed = DaemonTaskFeed(
      host: host,
      method: 'install.local',
      decode: _fromView,
      taskId: (task) => task.id,
      onChanged: _setTasks,
    );
    ref.onDispose(() => unawaited(_feed?.dispose()));
    scheduleMicrotask(() => _feed?.start());
    return const InstallQueueState();
  }

  void _setTasks(List<InstallTask> tasks) {
    final running = tasks.any(
      (task) =>
          task.status == ResourceTaskStatus.installing ||
          task.status == ResourceTaskStatus.downloading,
    );
    state = InstallQueueState(
      tasks: tasks,
      runStatus: running ? QueueRunStatus.running : QueueRunStatus.pending,
      loaded: true,
    );
  }

  InstallTask _fromView(DaemonTaskView view) {
    final typeName = view.params['type']?.toString() ?? 'quickapp';
    final resourceJson = view.params['resource'];
    final resource = resourceJson is Map
        ? communityResourceDetailFromJson(resourceJson.cast<String, Object?>())
        : null;
    final fileId = view.params['file']?.toString();
    final resourceFile = resource?.files
        .where((file) => file.id == fileId)
        .firstOrNull;
    return InstallTask(
      id: view.id,
      name:
          view.params['title']?.toString() ??
          view.path?.split(Platform.pathSeparator).last ??
          'Local install',
      description: view.params['description']?.toString().isNotEmpty == true
          ? view.params['description']!.toString()
          : typeName,
      type: switch (typeName) {
        'watchface' => LocalDeviceInstallType.watchface,
        'firmware' => LocalDeviceInstallType.firmware,
        _ => LocalDeviceInstallType.app,
      },
      installMode: ResourceInstallMode.values.firstWhere(
        (mode) => mode.name == view.params['installMode']?.toString(),
        orElse: () => ResourceInstallMode.automatic,
      ),
      filePath: view.path ?? '',
      identifier: view.params['identifier']?.toString(),
      resource: resource,
      file: resourceFile,
      status: resourceTaskStatusFromDaemon(
        view.status,
        activity: ResourceTaskActivity.install,
      ),
      progress: view.progress,
      error: view.error,
    );
  }

  void enqueueLocalFile(XFile file) {
    unawaited(_enqueueLocalFile(file));
  }

  Future<void> _enqueueLocalFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (kIsWeb) {
      final type = ResourceInstallService().detectLocalInstallType(
        file.name,
        bytes,
      );
      final task = InstallTask(
        id: file.path,
        name: file.name,
        description: type?.name ?? 'Unsupported file',
        type: type ?? LocalDeviceInstallType.app,
        filePath: file.path,
        bytes: bytes,
        status: type == null
            ? ResourceTaskStatus.failed
            : ResourceTaskStatus.pending,
        error: type == null ? 'Unsupported or unrecognized file type' : null,
      );
      _addWebTask(task);
      return;
    }
    final path = await _stage(file.name, bytes);
    await _enqueue(
      OronBoxCommand(
        method: 'install.local',
        params: {
          'type': 'auto',
          'path': path,
          'title': file.name,
          'deleteAfter': true,
          'autoClean': true,
        },
      ),
    );
  }

  Future<void> enqueueConfirmedLocalFile(
    XFile file, {
    required LocalDeviceInstallType type,
    required ResourceInstallMode installMode,
    String? identifier,
  }) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      _addWebTask(
        InstallTask(
          id: '${file.path}:${DateTime.now().microsecondsSinceEpoch}',
          name: file.name,
          description: type.name,
          type: type,
          installMode: installMode,
          filePath: file.path,
          bytes: bytes,
          identifier: identifier,
        ),
      );
      start();
      return;
    }
    final path = await _stageFile(file);
    await _enqueue(
      OronBoxCommand(
        method: 'install.local',
        params: {
          'type': type.name,
          'installMode': installMode.name,
          if (identifier != null && identifier.isNotEmpty)
            'identifier': identifier,
          'path': path,
          'title': file.name,
          'deleteAfter': true,
          'autoClean': true,
        },
      ),
    );
    await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'queue.start'));
  }

  Future<String> _stage(String name, Uint8List bytes) async {
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return ManagedTemporaryFiles.create(
      TemporaryFilePurpose.installs,
      'file_$safeName',
      (path) async {
        await File(path).writeAsBytes(bytes, flush: true);
      },
    );
  }

  Future<String> _stageFile(XFile source) async {
    final safeName = source.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return ManagedTemporaryFiles.create(
      TemporaryFilePurpose.installs,
      'file_$safeName',
      (path) async {
        final sink = File(path).openWrite();
        try {
          await sink.addStream(source.openRead());
        } finally {
          await sink.close();
        }
      },
    );
  }

  Future<void> _enqueue(OronBoxCommand command, {bool held = true}) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'task.enqueue',
            params: {'held': held, 'command': command.toJson()},
          ),
        );
    if (!result.ok) {
      throw result.error!;
    }
    await _feed?.refresh();
  }

  /// Re-enqueue a failed watchface install with an explicit identifier,
  /// letting users fix a wrong watchface id instead of re-picking the file.
  Future<void> reinstallWatchface(
    String taskId, {
    required String identifier,
    bool startImmediately = true,
  }) async {
    final task = state.tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null) return;
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: [
          for (final item in state.tasks)
            if (item.id == taskId)
              InstallTask(
                id: item.id,
                name: item.name,
                description: item.description,
                type: item.type,
                installMode: item.installMode,
                filePath: item.filePath,
                bytes: item.bytes,
                analysis: item.analysis,
                identifier: identifier,
                resource: item.resource,
                file: item.file,
                status: startImmediately
                    ? ResourceTaskStatus.pending
                    : item.status,
              )
            else
              item,
        ],
        runStatus: state.runStatus,
        loaded: state.loaded,
      );
      if (startImmediately) start();
      return;
    }
    await _enqueue(
      OronBoxCommand(
        method: 'install.local',
        params: {
          'type': 'watchface',
          'identifier': identifier,
          'path': task.filePath,
          'title': task.name,
          'description': task.description,
          'installMode': task.installMode.name,
          'deleteAfter': true,
          'autoClean': true,
          if (task.resource != null)
            'resource': communityResourceDetailToJson(task.resource!),
          if (task.file != null) 'file': task.file!.id,
        },
      ),
      held: !startImmediately,
    );
    await _feed?.remove(
      taskId,
      terminal: task.status == ResourceTaskStatus.failed,
    );
  }

  void enqueueResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
    required String filePath,
    Uint8List? bytes,
    ResourcePayloadAnalysis? analysis,
  }) {
    assert(kIsWeb);
    final catalogType = switch (resource.type) {
      CommunityResourceType.quickApp => LocalDeviceInstallType.app,
      CommunityResourceType.miniprogram => LocalDeviceInstallType.app,
      CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
      CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
      CommunityResourceType.canopus => LocalDeviceInstallType.watchface,
    };
    _addWebTask(
      InstallTask(
        id: '${resource.ref.key}:${file.id}:$codename',
        name: resource.name,
        description: codename,
        type: analysis?.type ?? catalogType,
        filePath: filePath,
        bytes: bytes,
        analysis: analysis,
        resource: resource,
        file: file,
        status: ResourceTaskStatus.pending,
      ),
    );
    if (ref.read(appSettingsProvider).autoInstall && _webDeviceReady()) {
      start();
    }
  }

  void _addWebTask(InstallTask task) {
    if (state.tasks.any(
      (item) =>
          item.id == task.id && item.status != ResourceTaskStatus.completed,
    )) {
      return;
    }
    state = InstallQueueState(
      tasks: [...state.tasks, task],
      runStatus: state.runStatus,
      loaded: state.loaded,
    );
  }

  bool _webDeviceReady() {
    final device = ref.read(deviceManagerProvider);
    return device.protocolState == proto.ProtocolState.ready &&
        device.currentDevice != null &&
        !device.currentDevice!.disconnected;
  }

  void remove(String taskId) => unawaited(_remove(taskId));
  Future<void> _remove(String taskId) async {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: state.tasks.where((task) => task.id != taskId).toList(),
        runStatus: state.tasks.length <= 1
            ? QueueRunStatus.pending
            : state.runStatus,
        loaded: state.loaded,
      );
      return;
    }
    final task = state.tasks.where((task) => task.id == taskId).firstOrNull;
    final terminal =
        task == null ||
        task.status == ResourceTaskStatus.completed ||
        task.status == ResourceTaskStatus.failed;
    await _feed?.remove(taskId, terminal: terminal);
  }

  void clearTerminal() {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: state.tasks
            .where(
              (task) =>
                  task.status != ResourceTaskStatus.completed &&
                  task.status != ResourceTaskStatus.failed,
            )
            .toList(),
        runStatus: state.runStatus,
        loaded: state.loaded,
      );
      return;
    }
    for (final task in state.tasks.where(
      (task) =>
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    )) {
      unawaited(_remove(task.id));
    }
  }

  void retry(String taskId) {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: [
          for (final task in state.tasks)
            if (task.id == taskId)
              InstallTask(
                id: task.id,
                name: task.name,
                description: task.description,
                type: task.type,
                installMode: task.installMode,
                filePath: task.filePath,
                bytes: task.bytes,
                analysis: task.analysis,
                identifier: task.identifier,
                resource: task.resource,
                file: task.file,
              )
            else
              task,
        ],
        runStatus: state.runStatus,
        loaded: state.loaded,
      );
      return;
    }
    unawaited(_feed?.retry(taskId));
  }

  void start() {
    if (kIsWeb) {
      if (state.isRunning || !state.hasRunnableTasks || !_webDeviceReady()) {
        return;
      }
      state = InstallQueueState(
        tasks: state.tasks,
        runStatus: QueueRunStatus.running,
        loaded: state.loaded,
      );
      unawaited(_runWeb());
      return;
    }
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const OronBoxCommand(method: 'queue.start')),
    );
  }

  void pause() {
    if (kIsWeb) {
      if (!state.isRunning) return;
      state = InstallQueueState(
        tasks: state.tasks,
        runStatus: QueueRunStatus.stopping,
        loaded: state.loaded,
      );
      return;
    }
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const OronBoxCommand(method: 'queue.pause')),
    );
  }

  Future<void> _runWeb() async {
    while (state.runStatus == QueueRunStatus.running) {
      final task = state.tasks
          .where((item) => item.status == ResourceTaskStatus.pending)
          .firstOrNull;
      if (task == null) break;
      await _runWebTask(task);
      if (state.runStatus == QueueRunStatus.stopping) break;
    }
    state = InstallQueueState(
      tasks: state.tasks,
      runStatus: QueueRunStatus.pending,
      loaded: state.loaded,
    );
  }

  Future<void> _runWebTask(InstallTask task) async {
    final manager = ref.read(deviceManagerProvider.notifier);
    void update(ResourceTaskStatus status, double progress, String? error) {
      state = InstallQueueState(
        tasks: [
          for (final item in state.tasks)
            if (item.id == task.id)
              InstallTask(
                id: item.id,
                name: item.name,
                description: item.description,
                type: item.type,
                installMode: item.installMode,
                filePath: item.filePath,
                bytes: item.bytes,
                analysis: item.analysis,
                identifier: item.identifier,
                resource: item.resource,
                file: item.file,
                status: status,
                progress: progress,
                error: error,
              )
            else
              item,
        ],
        runStatus: state.runStatus,
        loaded: state.loaded,
      );
    }

    if (task.resource != null && task.file != null) {
      try {
        final analysis = task.analysis;
        if (analysis != null) {
          await ResourceInstallService().installAnalyzedPayload(
            analysis: analysis,
            fileName: task.file!.fileName,
            deviceManager: manager,
            identifierOverride: task.identifier,
            onProgress: (progress) =>
                update(ResourceTaskStatus.installing, progress, null),
          );
          update(ResourceTaskStatus.completed, 1, null);
        } else {
          await ResourceInstallService().installDownloadedResource(
            resource: task.resource!,
            file: task.file!,
            filePath: task.filePath,
            bytes: task.bytes,
            deviceManager: manager,
            onUpdate: update,
          );
        }
      } catch (error) {
        update(ResourceTaskStatus.failed, 0, error.toString());
      }
      return;
    } else {
      final service = ResourceInstallService();
      final bytes = task.bytes;
      if (bytes == null) {
        update(ResourceTaskStatus.failed, 0, 'Missing resource bytes');
        return;
      }
      try {
        switch (task.installMode) {
          case ResourceInstallMode.automatic:
            await service.installLocalPayload(
              type: task.type,
              fileName: task.name,
              bytes: bytes,
              deviceManager: manager,
              identifierOverride: task.identifier,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
          case ResourceInstallMode.forceType:
            await service.installForcedPayload(
              type: task.type,
              fileName: task.name,
              bytes: bytes,
              deviceManager: manager,
              identifierOverride: task.identifier,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
          case ResourceInstallMode.forcePlatform:
            final analysis = service.analyzePayload(
              fileName: task.name,
              bytes: bytes,
              hint: task.type,
              source: 'web-queue-force-platform',
            );
            if (analysis == null) {
              throw FormatException('Unrecognized resource: ${task.name}');
            }
            await service.installAnalyzedPayload(
              analysis: analysis,
              fileName: task.name,
              deviceManager: manager,
              forcePlatform: true,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
        }
        update(ResourceTaskStatus.completed, 1, null);
      } catch (error) {
        update(ResourceTaskStatus.failed, 0, error.toString());
      }
    }
  }
}

final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );
