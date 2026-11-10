import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/settings/services/legal_agreements.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
  });
  test('old agreement and stale remote metadata do not accept the new privacy revision', () async {
    final prefs = SharedPrefsService.instance;
    await prefs.setInt('legal.agreementsAcceptedVersion', 1);
    await prefs.setString(
      'legal.manifest',
      jsonEncode({
        'documents': [
          {'id': 'privacy', 'revision': 1},
        ],
      }),
    );
    expect(LegalAgreements.requiredRevision('privacy'), 3);
    expect(LegalAgreements.accepted('privacy'), isFalse);
    expect(LegalAgreements.accepted('terms'), isFalse);
    await prefs.setInt('legal.shown.privacy', 1);
    expect(await LegalAgreements.acceptShown('privacy'), isFalse);
    await prefs.setInt('legal.shown.privacy', 3);
    expect(await LegalAgreements.acceptShown('privacy'), isTrue);
    expect(LegalAgreements.accepted('privacy'), isTrue);
  });
  test(
    'a newer verified remote revision still supersedes the bundled version',
    () async {
      await SharedPrefsService.instance.setString(
        'legal.manifest',
        jsonEncode({
          'documents': [
            {'id': 'privacy', 'revision': 4},
          ],
        }),
      );
      expect(LegalAgreements.requiredRevision('privacy'), 4);
      expect(LegalAgreements.bundledRevision('publishing'), 3);
    },
  );
}
