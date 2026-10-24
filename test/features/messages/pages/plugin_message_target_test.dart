import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/plugins/pages/plugins_page.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });
  testWidgets(
    'plugin message opens remote catalog even when plugin is not installed',
    (tester) async {
      final host = _PluginHost();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [applicationHostProvider.overrideWithValue(host)],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PluginsPage(targetPluginId: 'org.example.target'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(host.source, 'oronbox');
      expect(find.text('Different display name'), findsOneWidget);
      expect(host.methods, isNot(contains('plugin.get')));
      expect(host.methods, isNot(contains('plugin.open')));
      expect(tester.takeException(), isNull);
    },
  );
}

class _PluginHost implements OronBoxCommandBus {
  String? source;
  final methods = <String>[];
  @override
  Stream<CommandEvent> get events => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<CommandResult> execute(OronBoxCommand c) async {
    methods.add(c.method);
    switch (c.method) {
      case 'plugin.list':
        return const CommandResult.success([]);
      case 'plugin.safeMode.get':
        return const CommandResult.success({'enabled': false});
      case 'plugin.repositories':
        return const CommandResult.success([
          {'id': 'oronbox', 'name': 'OronBox', 'legacy': false},
        ]);
      case 'plugin.repository.catalog':
        source = c.params['source']?.toString();
        return const CommandResult.success([
          {
            'id': 'org.example.target',
            'source': 'oronbox',
            'installedId': 'org.example.target',
            'name': 'Different display name',
            'version': '1.0.0',
            'author': 'Author',
            'description': 'Description',
          },
        ]);
      default:
        return const CommandResult.success({});
    }
  }
}
