import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/settings/services/legal_agreements.dart';

/// Legal documents the user has accepted. Bump [currentLegalVersion] when the
/// terms or privacy notice change in a way that requires re-consent.
const currentLegalVersion = 1;

const _legalVersionKey = 'legal.agreementsAcceptedVersion';
const _oobeCompletedKey = 'oobe.completed';

bool isLegalAccepted([SharedPrefsService? prefs]) {
  final store = prefs ?? SharedPrefsService.instance;
  return (store.getInt(_legalVersionKey) ?? 0) >= currentLegalVersion &&
      LegalAgreements.accepted('terms') &&
      LegalAgreements.accepted('privacy');
}

bool isOobeCompleted([SharedPrefsService? prefs]) {
  final store = prefs ?? SharedPrefsService.instance;
  return isLegalAccepted(store) && (store.getBool(_oobeCompletedKey) ?? false);
}

Future<void> markLegalAccepted([SharedPrefsService? prefs]) async {
  final store = prefs ?? SharedPrefsService.instance;
  await store.setInt(_legalVersionKey, currentLegalVersion);
}

Future<void> markOobeCompleted([SharedPrefsService? prefs]) async {
  final store = prefs ?? SharedPrefsService.instance;
  await store.setBool(_oobeCompletedKey, true);
}
