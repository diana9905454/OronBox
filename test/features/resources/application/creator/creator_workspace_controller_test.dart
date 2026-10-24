import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  test(
    'workspace controller keeps the server workspace as its single state',
    () async {
      final host = _CreatorHost();
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      container.read(creatorWorkspaceProvider);
      await _eventually(
        () => !container.read(creatorWorkspaceProvider).loading,
      );
      expect(container.read(creatorWorkspaceProvider).resources, isEmpty);

      await container
          .read(creatorWorkspaceProvider.notifier)
          .create(
            'demo-resource',
            'Demo resource',
            CreatorResourceKind.quickApp,
          );
      final state = container.read(creatorWorkspaceProvider);
      expect(state.resources, hasLength(1));
      expect(state.selected?.resource.slug, 'demo-resource');
      expect(state.selected?.resource.draftName, 'Demo resource');
      expect(state.selected?.revisions, isEmpty);
    },
  );

  test('workspace refresh trusts the authenticated host instead of frontend credentials', () async {
    final host = _CreatorHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    container.read(creatorWorkspaceProvider);
    await _eventually(() => !container.read(creatorWorkspaceProvider).loading);

    expect(host.methods, contains('creator.list'));
    expect(host.methods, contains('creator.devices'));
    expect(host.methods, contains('creator.grants'));
    expect(host.methods, contains('creator.collections.list'));
  });

  test(
    'workspace refresh starts primary and secondary requests together',
    () async {
      final listGate = Completer<void>();
      final host = _CreatorHost(listGate: listGate);
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      container.read(creatorWorkspaceProvider);
      await _eventually(
        () => host.methods.toSet().containsAll({
          'creator.list',
          'creator.devices',
          'creator.grants',
          'creator.collections.list',
        }),
      );
      listGate.complete();
      await _eventually(
        () => !container.read(creatorWorkspaceProvider).loading,
      );
    },
  );

  test('a grants failure does not discard creator resources', () async {
    final host = _CreatorHost(grantsFailure: true, includeResource: true);
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    container.read(creatorWorkspaceProvider);
    await _eventually(() => !container.read(creatorWorkspaceProvider).loading);

    final state = container.read(creatorWorkspaceProvider);
    expect(state.resources.single.resource.id, 'existing-resource');
    expect(state.error, contains('grants unavailable'));
  });

  test('a collections failure does not discard creator resources', () async {
    final host = _CreatorHost(collectionsFailure: true, includeResource: true);
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    container.read(creatorWorkspaceProvider);
    await _eventually(() => !container.read(creatorWorkspaceProvider).loading);

    final state = container.read(creatorWorkspaceProvider);
    expect(state.resources.single.resource.id, 'existing-resource');
    expect(state.error, contains('collections unavailable'));
  });

  test(
    'publish preserves the server validation message in controller state',
    () async {
      final host = _CreatorHost(
        publishFailure: const CommandError(
          'creator_invalid',
          'Preview image exceeds the 1500 px limit',
          details: {'status': 400},
        ),
      );
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      container.read(creatorWorkspaceProvider);
      await _eventually(
        () => !container.read(creatorWorkspaceProvider).loading,
      );
      final controller = container.read(creatorWorkspaceProvider.notifier);
      await controller.create(
        'demo-resource',
        'Demo resource',
        CreatorResourceKind.quickApp,
      );

      Object? thrown;
      try {
        await controller.publish(bundle: Uint8List.fromList(const [1, 2, 3]));
      } catch (error) {
        thrown = error;
      }
      expect(
        thrown.toString(),
        contains('Preview image exceeds the 1500 px limit'),
      );
      expect(
        thrown,
        isA<CreatorCommandException>()
            .having((error) => error.code, 'code', 'creator_invalid')
            .having(
              (error) => error.message,
              'message',
              'Preview image exceeds the 1500 px limit',
            ),
      );
      expect(
        container.read(creatorWorkspaceProvider).error,
        'Preview image exceeds the 1500 px limit',
      );
      expect(container.read(creatorWorkspaceProvider).publishProgress, isNull);
    },
  );
  test('keeps the saved draft edit version when submission fails', () async {
    final host = _CreatorHost(
      draftSavedBeforeFailure: true,
      publishFailure: const CommandError('upstream_unavailable', 'Try again'),
    );
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);
    container.read(creatorWorkspaceProvider);
    await _eventually(() => !container.read(creatorWorkspaceProvider).loading);
    final controller = container.read(creatorWorkspaceProvider.notifier);
    await controller.create(
      'demo-resource',
      'Demo',
      CreatorResourceKind.quickApp,
    );
    await expectLater(
      controller.publish(bundle: Uint8List.fromList([1])),
      throwsA(isA<CreatorCommandException>()),
    );
    expect(
      container.read(creatorWorkspaceProvider).selected?.resource.editVersion,
      7,
    );
    expect(container.read(creatorWorkspaceProvider).error, 'Try again');
  });
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not reached');
}

class _CreatorHost implements OronBoxCommandBus {
  _CreatorHost({
    this.publishFailure,
    this.grantsFailure = false,
    this.collectionsFailure = false,
    this.includeResource = false,
    this.listGate,
    this.draftSavedBeforeFailure = false,
  });

  final CommandError? publishFailure;
  final bool draftSavedBeforeFailure;
  final bool grantsFailure;
  final bool collectionsFailure;
  final bool includeResource;
  final Completer<void>? listGate;
  final _events = StreamController<CommandEvent>.broadcast();
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    if (command.method == 'creator.list') {
      await listGate?.future;
      return CommandResult.success({
        'resources': [
          if (includeResource)
            {
              'resource': {
                'id': 'existing-resource',
                'slug': 'existing',
                'kind': 'quickapp',
                'state': 'active',
              },
              'revisions': <Object?>[],
              'artifacts': <Object?>[],
              'media': <Object?>[],
              'publications': <Object?>[],
            },
        ],
      });
    }
    if (command.method == 'creator.devices') {
      return const CommandResult.success({'devices': <Object?>[]});
    }
    if (command.method == 'creator.collections.list') {
      if (collectionsFailure) {
        return const CommandResult.failure(
          CommandError('collections_failed', 'collections unavailable'),
        );
      }
      return const CommandResult.success({'collections': <Object?>[]});
    }
    if (command.method == 'creator.create') {
      return CommandResult.success({
        'resource': {
          'id': 'resource-1',
          'slug': command.params['slug'],
          'draft_name': command.params['name'],
          'kind': command.params['kind'],
          'state': 'active',
        },
        'revisions': <Object?>[],
        'artifacts': <Object?>[],
        'media': <Object?>[],
        'publications': <Object?>[],
      });
    }
    if (command.method == 'creator.grants' && grantsFailure) {
      return const CommandResult.failure(
        CommandError('grants_failed', 'grants unavailable'),
      );
    }
    if (command.method == 'creator.grants') {
      return const CommandResult.success(<String, Object?>{});
    }
    if (command.method == 'creator.publish') {
      if (draftSavedBeforeFailure) {
        _events.add(
          CommandEvent(
            'creator.publish.draftSaved',
            data: {
              'operationId': command.params['operationId'],
              'workspace': {
                'resource': {
                  'id': 'resource-1',
                  'slug': 'demo-resource',
                  'kind': 'quickapp',
                  'edit_version': 7,
                },
                'revisions': <Object?>[],
                'media': <Object?>[],
                'artifacts': <Object?>[],
                'publications': <Object?>[],
              },
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
      return publishFailure == null
          ? CommandResult.success({
              'resource': {
                'id': 'resource-1',
                'slug': 'demo-resource',
                'kind': 'quickapp',
                'state': 'active',
              },
              'revisions': <Object?>[],
              'artifacts': <Object?>[],
              'media': <Object?>[],
              'publications': <Object?>[],
            })
          : CommandResult.failure(publishFailure!);
    }
    return CommandResult.failure(CommandError('unexpected', command.method));
  }

  @override
  Future<void> close() => _events.close();
}
