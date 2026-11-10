import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';

/// One OS subscription, independently leased by each connected device.
class PhoneLocationSessions {
  PhoneLocationSessions({OronboxLocation? platform})
    : platform = platform ?? OronboxLocation.instance;
  static final instance = PhoneLocationSessions();
  static const enabledKey = 'xiaomi.phone_location.enabled';
  final OronboxLocation platform;
  final _leases = <Object>{};
  final _positions = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;
  Future<void> _queue = Future.value();
  bool _running = false;
  Locale? locale;

  bool get enabled {
    final prefs = SharedPrefsService.instance;
    return !prefs.isInitialized || (prefs.getBool(enabledKey) ?? true);
  }

  Stream<Position> get positions => _positions.stream;

  Future<void> acquire(Object lease) => _serialize(() async {
    if (!enabled) throw StateError('PHONE_LOCATION_DISABLED');
    if (_leases.contains(lease)) return;
    if (!_running) {
      final selectedLocale =
          locale ?? WidgetsBinding.instance.platformDispatcher.locale;
      final supported = AppLocalizations.supportedLocales;
      final l10n = lookupAppLocalizations(
        basicLocaleListResolution([selectedLocale], supported),
      );
      _subscription = platform.positions.listen(
        _positions.add,
        onError: (Object error, StackTrace stack) =>
            _positions.addError(error, stack),
      );
      try {
        await platform.startUpdates(
          notificationTitle: l10n.phoneLocationTitle,
          notificationText: l10n.phoneLocationNotification,
          channelName: l10n.phoneLocationTitle,
          recoveryTitle: l10n.phoneLocationOpenApp,
          recoveryText: l10n.phoneLocationRecovery,
        );
        _running = true;
      } catch (_) {
        await _subscription?.cancel();
        _subscription = null;
        rethrow;
      }
    }
    _leases.add(lease);
  });

  Future<void> release(Object lease) => _serialize(() async {
    _leases.remove(lease);
    if (_leases.isEmpty) await _stop();
  });
  Future<void> disable() => _serialize(() async {
    _leases.clear();
    _positions.addError(PlatformException(code: 'PHONE_LOCATION_DISABLED'));
    await _stop();
    await platform.cancelCurrentPosition();
  });
  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_running) {
      _running = false;
      await platform.stopUpdates();
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
