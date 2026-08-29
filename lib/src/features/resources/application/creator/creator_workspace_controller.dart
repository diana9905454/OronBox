import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/core/extensions/riverpod_mounted_ext.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

enum CreatorOperation {
  refreshing,
  creating,
  creatingCollection,
  saving,
  publishing,
  deleting,
  authorizing,
}

class CreatorWorkspaceState {
  const CreatorWorkspaceState({
    this.resources = const [],
    this.collections = const [],
    this.devices = const [],
    this.grants = const {},
    this.selected,
    this.loading = false,
    this.operation,
    this.publishProgress,
    this.error,
    this.governance,
  });
  final List<CreatorWorkspace> resources;
  final List<Map<String, Object?>> collections;
  final List<CreatorDevice> devices;
  final Map<String, Object?> grants;
  final CreatorWorkspace? selected;
  final bool loading;
  final CreatorOperation? operation;
  final double? publishProgress;
  final String? error;

  /// 'banned' or 'creator_frozen' when the server rejected the account.
  final String? governance;

  CreatorWorkspaceState copyWith({
    List<CreatorWorkspace>? resources,
    List<Map<String, Object?>>? collections,
    List<CreatorDevice>? devices,
    Map<String, Object?>? grants,
    CreatorWorkspace? selected,
    bool clearSelected = false,
    bool? loading,
    CreatorOperation? operation,
    bool clearOperation = false,
    double? publishProgress,
    bool clearProgress = false,
    String? error,
    bool clearError = false,
    String? governance,
    bool clearGovernance = false,
  }) => CreatorWorkspaceState(
    resources: resources ?? this.resources,
    collections: collections ?? this.collections,
    devices: devices ?? this.devices,
    grants: grants ?? this.grants,
    selected: clearSelected ? null : selected ?? this.selected,
    loading: loading ?? this.loading,
    operation: clearOperation ? null : operation ?? this.operation,
    publishProgress: clearProgress
        ? null
        : publishProgress ?? this.publishProgress,
    error: clearError ? null : error ?? this.error,
    governance: clearGovernance ? null : governance ?? this.governance,
  );
}

class CreatorWorkspaceController extends Notifier<CreatorWorkspaceState> {
  static final _log = getLogger('CreatorWorkspace');

  int _refreshGeneration = 0;

  @override
  CreatorWorkspaceState build() {
    Future.microtask(refresh);
    return const CreatorWorkspaceState(loading: true);
  }

  OronBoxCommandBus get _host => ref.read(applicationHostProvider);

  Future<Object?> _execute(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await _host.execute(
      OronBoxCommand(method: method, params: params),
    );
    if (!result.ok) throw CreatorCommandException.fromCommand(result.error!);
    return result.value;
  }

  Future<void> refresh({
    CreatorOperation operation = CreatorOperation.refreshing,
  }) async {
    final generation = ++_refreshGeneration;
    state = state.copyWith(
      loading: true,
      operation: operation,
      clearError: true,
      clearGovernance: true,
    );
    try {
      final resourcesRequest = _execute('creator.list');
      Object? collectionsValue;
      Object? devicesValue;
      Object? grantsValue;
      Object? secondaryError;
      final secondaryRequests = Future.wait([
        () async {
          try {
            collectionsValue = await _execute('creator.collections.list');
          } catch (error) {
            secondaryError ??= error;
          }
        }(),
        () async {
          try {
            devicesValue = await _execute('creator.devices');
          } catch (error) {
            secondaryError ??= error;
          }
        }(),
        () async {
          try {
            grantsValue = await _execute('creator.grants');
          } catch (error) {
            secondaryError ??= error;
          }
        }(),
      ]);
      final root = _map(await resourcesRequest);
      await secondaryRequests;
      if (!ref.mounted || generation != _refreshGeneration) return;
      final deviceRoot = _map(devicesValue);
      final grants = grantsValue == null ? state.grants : _map(grantsValue);
      final resources = (root['resources'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CreatorWorkspace.fromJson(item.cast<String, Object?>()),
          )
          .toList();
      final selectedId = state.selected?.resource.id;
      state = state.copyWith(
        resources: resources,
        collections: collectionsValue == null
            ? state.collections
            : (_map(collectionsValue)['collections'] as List? ?? const [])
                  .whereType<Map>()
                  .map((item) => item.cast<String, Object?>())
                  .toList(),
        devices: devicesValue == null
            ? state.devices
            : (deviceRoot['devices'] as List? ?? const [])
                  .whereType<Map>()
                  .map(
                    (item) =>
                        CreatorDevice.fromJson(item.cast<String, Object?>()),
                  )
                  .toList(),
        grants: grants,
        selected: resources
            .where((item) => item.resource.id == selectedId)
            .firstOrNull,
        clearSelected: selectedId == null,
        loading: false,
        clearOperation: true,
        error: secondaryError == null
            ? null
            : creatorFailureMessage(secondaryError!),
        clearError: secondaryError == null,
      );
      logDiagnostic(
        _log,
        Level.INFO,
        'Creator workspace refreshed',
        fields: {
          'resources': resources.length,
          'devices': state.devices.length,
          if (secondaryError != null) 'partial': true,
        },
      );
    } catch (error) {
      if (!ref.mounted || generation != _refreshGeneration) return;
      final code = switch (error) {
        CreatorCommandException exception => exception.code,
        _ => '',
      };
      final governed = code == 'banned' || code == 'creator_frozen';
      state = state.copyWith(
        loading: false,
        clearOperation: true,
        error: governed ? null : creatorFailureMessage(error),
        clearError: governed,
        governance: governed ? code : null,
        clearGovernance: !governed,
      );
    }
  }

  void select(CreatorWorkspace? workspace) => state = state.copyWith(
    selected: workspace,
    clearSelected: workspace == null,
  );

  Future<void> create(
    String slug,
    String name,
    CreatorResourceKind kind,
  ) async {
    await _mutate('creator.create', {
      'slug': slug,
      'name': name,
      'kind': kind == CreatorResourceKind.watchface ? 'watchface' : 'quickapp',
    }, operation: CreatorOperation.creating);
    logDiagnostic(
      _log,
      Level.INFO,
      'Creator resource created',
      fields: {
        'resource': state.selected?.resource.id,
        'slug': slug,
        'kind': kind == CreatorResourceKind.watchface
            ? 'watchface'
            : 'quickapp',
      },
    );
  }

  Future<void> createCollection({
    required String slug,
    required String name,
    required String summary,
    required CreatorResourceKind kind,
  }) async {
    await _runCollectionMutation('creator.collections.create', {
      'slug': slug,
      'name': name,
      'summary': summary,
      'kind': kind == CreatorResourceKind.watchface ? 'watchface' : 'quickapp',
    }, CreatorOperation.creatingCollection);
  }

  Future<void> setCollectionResources({
    required String collectionId,
    required List<String> resourceIds,
    required String representativeResourceId,
  }) => _runCollectionMutation('creator.collections.resources', {
    'collection': collectionId,
    'resourceIds': resourceIds,
    'representativeResourceId': representativeResourceId,
  }, CreatorOperation.saving);

  Future<void> deleteCollection(String collectionId) => _runCollectionMutation(
    'creator.collections.delete',
    {'collection': collectionId},
    CreatorOperation.deleting,
  );

  Future<void> updateCollection({
    required String collectionId,
    required String name,
    required String summary,
  }) => _runCollectionMutation('creator.collections.update', {
    'collection': collectionId,
    'name': name,
    'summary': summary,
  }, CreatorOperation.saving);

  Future<void> _runCollectionMutation(
    String method,
    Map<String, Object?> params,
    CreatorOperation operation,
  ) async {
    state = state.copyWith(
      loading: true,
      operation: operation,
      clearError: true,
    );
    try {
      await _execute(method, params);
      await refresh(operation: operation);
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          loading: false,
          clearOperation: true,
          error: creatorFailureMessage(error),
        );
      }
      rethrow;
    }
  }

  Future<void> publish({required Uint8List bundle}) async {
    final workspace = state.selected;
    if (workspace == null) return;
    final operationId = const Uuid().v4();
    state = state.copyWith(
      loading: true,
      operation: CreatorOperation.publishing,
      publishProgress: 0,
      clearError: true,
    );
    final subscription = _host.events.listen((event) {
      if (ref.mounted &&
          event.event == 'creator.publish.progress' &&
          event.data['operationId'] == operationId) {
        state = state.copyWith(
          publishProgress: (event.data['progress'] as num?)?.toDouble() ?? 0,
        );
      }
    });
    try {
      final value = await _execute('creator.publish', {
        'resource': workspace.resource.id,
        'bundle': base64Encode(bundle),
        'operationId': operationId,
      });
      if (!ref.mounted) return;
      _acceptWorkspace(CreatorWorkspace.fromJson(_map(value)));
      logDiagnostic(
        _log,
        Level.INFO,
        'Creator resource published',
        fields: {'resource': workspace.resource.id, 'bytes': bundle.length},
      );
    } catch (error) {
      if (!ref.mounted) return;
      final failure = CreatorCommandException.from(error);
      logDiagnostic(
        _log,
        Level.WARNING,
        'Creator publish failed',
        fields: {'resource': workspace.resource.id},
        error: failure.message,
      );
      state = state.copyWith(error: failure.message);
      throw failure;
    } finally {
      await subscription.cancel();
      if (ref.mounted) {
        state = state.copyWith(
          loading: false,
          clearOperation: true,
          clearProgress: true,
        );
      }
    }
  }

  Future<void> saveDraft({required Uint8List bundle}) => _mutate(
    'creator.draft',
    {'resource': state.selected!.resource.id, 'bundle': base64Encode(bundle)},
  );

  final _blobCache = <String, Uint8List>{};

  Future<Uint8List> blob(String resourceId, String sha256) async {
    if (_blobCache[sha256] case final cached?) return cached;
    final value = _map(
      await _execute('creator.blob', {
        'resource': resourceId,
        'sha256': sha256,
      }),
    );
    final bytes = base64Decode(value['bytes']?.toString() ?? '');
    _blobCache[sha256] = bytes;
    return bytes;
  }

  Future<List<Map<String, Object?>>> bandBbsPublicationCategories() async {
    final raw = await _execute('creator.bandbbs.categories');
    return (raw as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
  }

  /// Provenance recorded for this resource (author/source/license), null when
  /// none was set.
  Future<Map<String, Object?>?> resourceSource(String resourceId) async {
    final value = _map(
      await _execute('creator.relationships', {'resource': resourceId}),
    );
    final source = value['source'];
    return source is Map ? source.cast<String, Object?>() : null;
  }

  Future<Map<String, Object?>> startGitHubAuthorization() async {
    state = state.copyWith(
      loading: true,
      operation: CreatorOperation.authorizing,
      clearError: true,
    );
    try {
      return _map(await _execute('creator.github.start'));
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          loading: false,
          clearOperation: true,
          error: creatorFailureMessage(error),
        );
      }
      rethrow;
    }
  }

  Future<bool> pollGitHubAuthorization(String flowId) async {
    final result = _map(
      await _execute('creator.github.status', {'flowId': flowId}),
    );
    if (result['state'] == 'connected') {
      await refresh();
      return true;
    }
    return false;
  }

  void finishAuthorization() {
    state = state.copyWith(loading: false, clearOperation: true);
  }

  Future<void> disconnectGitHub() async {
    state = state.copyWith(
      loading: true,
      operation: CreatorOperation.authorizing,
      clearError: true,
    );
    try {
      await _execute('creator.github.disconnect');
      await refresh();
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          loading: false,
          clearOperation: true,
          error: creatorFailureMessage(error),
        );
      }
      rethrow;
    }
  }

  Future<void> takedown() => _moderate('creator.takedown', 'takedown');

  Future<void> restore() => _moderate('creator.restore', 'restored');

  Future<void> _moderate(String method, String verb) async {
    final resourceId = state.selected!.resource.id;
    await _mutate(method, {'resource': resourceId});
    logDiagnostic(
      _log,
      Level.INFO,
      'Creator resource $verb',
      fields: {'resource': resourceId},
    );
  }

  /// Deletes the selected resource. External platforms are only touched when
  /// listed in [deleteExternal]; returns the server result (e.g. the AstroBox
  /// removal PR link).
  Future<Map<String, Object?>> deleteResource({
    List<String> deleteExternal = const [],
  }) async {
    final id = state.selected!.resource.id;
    state = state.copyWith(
      loading: true,
      operation: CreatorOperation.deleting,
      clearError: true,
    );
    try {
      final value = await _execute('creator.delete', {
        'resource': id,
        'deleteExternal': deleteExternal,
      });
      logDiagnostic(
        _log,
        Level.INFO,
        'Creator resource deleted',
        fields: {'resource': id, 'deleteExternal': deleteExternal.join(',')},
      );
      state = state.copyWith(
        resources: state.resources
            .where((workspace) => workspace.resource.id != id)
            .toList(growable: false),
        clearSelected: true,
        loading: false,
        clearOperation: true,
      );
      unawaited(refresh());
      return (value as Map?)?.cast<String, Object?>() ?? const {};
    } catch (error) {
      if (!ref.mounted) return const {};
      final failure = CreatorCommandException.from(error);
      state = state.copyWith(
        loading: false,
        clearOperation: true,
        error: failure.message,
      );
      throw failure;
    }
  }

  Future<void> _mutate(
    String method,
    Map<String, Object?> params, {
    CreatorOperation operation = CreatorOperation.saving,
  }) async {
    state = state.copyWith(
      loading: true,
      operation: operation,
      clearError: true,
    );
    try {
      final value = await _execute(method, params);
      if (!ref.mounted) return;
      final workspace = CreatorWorkspace.fromJson(_map(value));
      _acceptWorkspace(workspace);
    } catch (error) {
      if (!ref.mounted) return;
      final failure = CreatorCommandException.from(error);
      logDiagnostic(
        _log,
        Level.WARNING,
        'Creator operation failed',
        fields: {'method': method},
        error: failure.message,
      );
      state = state.copyWith(
        loading: false,
        clearOperation: true,
        error: failure.message,
      );
      throw failure;
    }
  }

  void _acceptWorkspace(
    CreatorWorkspace workspace, {
    bool finishOperation = true,
  }) {
    final resources = [...state.resources];
    final index = resources.indexWhere(
      (item) => item.resource.id == workspace.resource.id,
    );
    if (index < 0) {
      resources.insert(0, workspace);
    } else {
      resources[index] = workspace;
    }
    state = state.copyWith(
      resources: resources,
      selected: workspace,
      loading: finishOperation ? false : state.loading,
      clearOperation: finishOperation,
    );
  }
}

class CreatorCommandException implements CodedError {
  const CreatorCommandException({
    required this.code,
    required this.message,
    this.details,
  });

  factory CreatorCommandException.fromCommand(CommandError error) =>
      CreatorCommandException(
        code: error.code,
        message: error.message,
        details: error.details,
      );

  factory CreatorCommandException.from(Object error) {
    if (error is CreatorCommandException) return error;
    return CreatorCommandException(
      code: 'creator_failed',
      message: creatorFailureMessage(error),
    );
  }

  @override
  final String code;
  @override
  final String message;
  @override
  final Object? details;

  @override
  String toString() => message;
}

String creatorFailureMessage(Object error) {
  if (error is CreatorCommandException) {
    return '${error.code}: ${error.message}';
  }
  var message = error.toString().trim();
  for (final prefix in const ['Bad state: ', 'Exception: ', 'DioException: ']) {
    if (message.startsWith(prefix)) message = message.substring(prefix.length);
  }
  return message.isEmpty ? 'Creator operation failed' : message;
}

final creatorWorkspaceProvider =
    NotifierProvider<CreatorWorkspaceController, CreatorWorkspaceState>(
      CreatorWorkspaceController.new,
    );

Map<String, Object?> _map(Object? value) =>
    (value as Map?)?.cast<String, Object?>() ?? const {};
