import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_ui_tree.dart';

void main() {
  testWidgets('renders a centered tree with flexible rows and callbacks', (
    tester,
  ) async {
    String? callback;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PluginUITree(
            root: {
              'type': 'Column',
              'props': const <String, Object?>{},
              'children': [
                {
                  'type': 'Image',
                  'props': {
                    'data':
                        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
                        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                    'width': 1,
                    'height': 1,
                  },
                },
                {
                  'type': 'Row',
                  'props': const <String, Object?>{},
                  'children': [
                    {
                      'type': 'Text',
                      'props': {'value': 'left'},
                    },
                    {'type': 'Spacer'},
                    {
                      'type': 'Button',
                      'props': {'text': 'run', 'onClick': 'callback-1'},
                    },
                  ],
                },
              ],
            },
            onInvoke: (id, [value]) async => callback = id,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('left'), findsOneWidget);
    await tester.tap(find.text('run'));
    expect(callback, 'callback-1');
  });

  testWidgets('passes typed values from interactive controls', (tester) async {
    final values = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PluginUITree(
            root: {
              'type': 'Column',
              'children': [
                {
                  'type': 'Switch',
                  'props': {'checked': false, 'onChange': 'switch'},
                },
                {
                  'type': 'Checkbox',
                  'props': {'checked': false, 'onChange': 'checkbox'},
                },
              ],
            },
            onInvoke: (id, [value]) async => values.add(value),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.tap(find.byType(Checkbox));

    expect(values, <Object?>[true, true]);
  });

  testWidgets('publishes text changes before the field loses focus', (
    tester,
  ) async {
    final values = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PluginUITree(
            root: {
              'type': 'TextField',
              'props': {'onChange': 'change', 'placeholder': 'city'},
            },
            onInvoke: (id, [value]) async => values.add(value),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '北京');

    expect(values, <Object?>['北京']);
  });
}
