import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations_en.dart';
import 'package:oronbox/src/app/generated/app_localizations_zh.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  group('localizedErrorMessage', () {
    test('comment rejection never displays raw AI reasoning', () {
      expect(
        localizedErrorMessage(
          zh,
          const _TestCodedError(
            'comment_blocked',
            'Model classified this as spam',
          ),
        ),
        '评论未通过社区规范',
      );
    });

    test('localizes redacted server failures by their stable code', () {
      expect(
        localizedErrorMessage(
          zh,
          const _TestCodedError(
            'moderation_unavailable',
            'The server could not complete the request',
          ),
        ),
        zh.commentModerationUnavailable,
      );
    });

    test('maps every connection failure shape to one unified message', () {
      const shapes = [
        // BLE link-establishment timeout (daemon wrapper included).
        'Bad state: connection: Failed to connect '
            '66F65DDF-EA1A-DE29-7CBC-509EB8DE2E2D: TimeoutException after '
            '0:00:12.000000: BLE connect failed: timeout (Xiaomi Smart Band 7); '
            'the device may be occupied by another host or tool, or out of range',
        // BLE post-connect stage timeouts.
        'TimeoutException after 0:00:10.000000: '
            'BLE connect failed: service discovery timed out',
        'TimeoutException after 0:00:08.000000: '
            'BLE notification subscription timed out for 00000002-0000-3512-2118-0009af100700',
        // BLE native failure, normalized at the driver boundary.
        'Bad state: BLE connect failed: connect_failed: gatt 133',
        // SPP native failures, normalized at the driver boundary.
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'connect failed: channel 5: -536870186, channel 1: -536870186',
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'read failed, socket might closed or timeout',
      ];

      for (final raw in shapes) {
        expect(
          localizedErrorMessage(en, raw),
          en.errorBluetoothConnectFailed,
          reason: raw,
        );
        expect(
          localizedErrorMessage(zh, raw),
          zh.errorBluetoothConnectFailed,
          reason: raw,
        );
      }
    });

    test('maps BLE write timeout to the disconnected message', () {
      const raw =
          'TimeoutException after 0:00:05.000000: '
          'BLE write timed out for 00000001-0000-3512-2118-0009af100700';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothDisconnected);
    });

    test('maps missing bluetooth permission to the unavailable message', () {
      const raw =
          'PlatformException(MISSING_PERMISSION, '
          'Bluetooth permission is required, null, null)';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothUnavailable);
    });

    test('maps SPP bond removal failures to actionable guidance', () {
      const raw =
          'SPP bond removal failed: removeBond() was rejected; bondState=12';

      expect(localizedErrorMessage(en, raw), en.errorSppBondRemovalFailed);
      expect(localizedErrorMessage(zh, raw), zh.errorSppBondRemovalFailed);
    });

    test('does not swallow generic timeouts', () {
      const raw = 'TimeoutException after 0:00:05.000000: Future not completed';

      expect(
        localizedErrorMessage(en, raw),
        isNot(en.errorBluetoothConnectFailed),
      );
    });

    test('preserves structured backend session messages', () {
      expect(
        localizedErrorMessage(
          en,
          const _TestCodedError(
            'invalid_refresh_token',
            'refresh token is invalid or expired',
          ),
        ),
        'refresh token is invalid or expired',
      );
      expect(
        localizedErrorMessage(
          zh,
          const _TestCodedError(
            'unauthorized',
            'OronBox access token is invalid or expired',
          ),
        ),
        'OronBox access token is invalid or expired',
      );
      expect(
        localizedErrorMessage(en, 'OronBox session expired'),
        en.errorOronBoxSessionExpired,
      );
    });

    test('localizes client auth and session errors for zh and en', () {
      expect(
        localizedErrorMessage(zh, const OronBoxAuthRequiredException()),
        zh.settingsBandBbsAccountRequired,
      );
      expect(
        localizedErrorMessage(en, const OronBoxAuthRequiredException()),
        en.settingsBandBbsAccountRequired,
      );
      expect(
        localizedErrorMessage(zh, const BandBbsSessionExpiredException()),
        zh.errorOronBoxSessionExpired,
      );
      expect(
        localizedErrorMessage(en, const BandBbsSessionExpiredException()),
        en.errorOronBoxSessionExpired,
      );
      expect(
        localizedErrorMessage(
          zh,
          StateError('BandBBS account is not signed in'),
        ),
        zh.settingsBandBbsAccountRequired,
      );
      expect(
        localizedErrorMessage(
          en,
          StateError('BandBBS account is not signed in'),
        ),
        en.settingsBandBbsAccountRequired,
      );
      expect(
        localizedErrorMessage(zh, 'invalid_refresh_token: application state'),
        zh.errorOronBoxSessionExpired,
      );
      expect(
        localizedErrorMessage(en, 'invalid_refresh_token: application state'),
        en.errorOronBoxSessionExpired,
      );
      expect(
        localizedErrorMessage(zh, 'watchface_install_blocked'),
        zh.watchfaceRestrictedMessage,
      );
      expect(
        localizedErrorMessage(en, 'watchface_install_blocked'),
        en.watchfaceRestrictedMessage,
      );
    });

    test('preserves structured backend messages', () {
      for (final code in oronBoxKnownErrorCodes) {
        expect(
          localizedErrorMessage(
            en,
            _TestCodedError(code, 'actual backend message'),
          ),
          code == 'comment_blocked'
              ? en.commentBlocked
              : 'actual backend message',
          reason: code,
        );
      }
    });

    test('shows only the first line of backend messages', () {
      expect(
        localizedErrorMessage(
          en,
          const _TestCodedError('new_server_code', 'actual backend message'),
        ),
        'actual backend message',
      );
      expect(
        localizedErrorMessage(
          en,
          const _TestCodedError(
            'internal',
            'actual backend message',
            '#0 LocalCommandBus._execute (package:oronbox/command_bus.dart:1:1)\n'
                '#1 LocalCommandBus.execute (package:oronbox/command_bus.dart:2:2)',
          ),
        ),
        'actual backend message',
      );
      expect(
        localizedErrorMessage(
          en,
          const _TestCodedError('internal', 'actual backend message', {
            'stage': 'publish',
            'stackTrace': '#0 ignored',
          }),
        ),
        'actual backend message',
      );
    });

    test('localizes raw Dio transport and response failures safely', () {
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/resources'),
            type: DioExceptionType.connectionError,
          ),
        ),
        en.errorNetworkUnavailable,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/v1/resources'),
              statusCode: 429,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        en.errorRateLimited,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/v1/resources'),
              statusCode: 400,
              data: {'code': 'coin_balance_insufficient'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        en.errorCoinBalanceInsufficient,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/v1/resources'),
              statusCode: 400,
              data: {'code': 'future_server_code', 'detail': 'secret'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        'secret',
      );
    });
  });
}

class _TestCodedError implements CodedError {
  const _TestCodedError(this.code, this.message, [this.details]);

  @override
  final String code;
  @override
  final String message;
  @override
  final Object? details;

  @override
  String toString() => message;
}
