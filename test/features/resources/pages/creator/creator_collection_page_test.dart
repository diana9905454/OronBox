import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_collection_page.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  testWidgets('opening a collection refreshes after the first frame', (
    tester,
  ) async {
    final host = _CollectionHost();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [applicationHostProvider.overrideWithValue(host)],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreatorCollectionPage(
            collectionId: 'collection-1',
            item: {
              'id': 'collection-1',
              'kind': 'quickapp',
              'pending_revision': {'name': 'Collection', 'summary': 'Summary'},
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Collection'), findsWidgets);
  });
}

class _CollectionHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(
    OronBoxCommand command,
  ) async => switch (command.method) {
    'creator.list' => const CommandResult.success({'resources': <Object?>[]}),
    'creator.collections.list' => const CommandResult.success({
      'collections': [
        {
          'id': 'collection-1',
          'kind': 'quickapp',
          'pending_revision': {'name': 'Collection', 'summary': 'Summary'},
        },
      ],
    }),
    'creator.collection.get' => const CommandResult.success({
      'id': 'collection-1',
      'kind': 'quickapp',
      'edit_version': 0,
      'pending_revision': {'name': 'Collection', 'summary': 'Summary'},
    }),
    'creator.devices' => const CommandResult.success({'devices': <Object?>[]}),
    'creator.grants' => const CommandResult.success(<String, Object?>{}),
    _ => CommandResult.failure(CommandError('unexpected', command.method)),
  };

  @override
  Future<void> close() => _events.close();
}
