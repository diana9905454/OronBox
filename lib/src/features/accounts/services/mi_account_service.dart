import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';

const maxWearableLogArchiveBytes = 64 * 1024 * 1024;
const maxWearableLogFileBytes = 32 * 1024 * 1024;
const maxWearableLogBatchBytes = 128 * 1024 * 1024;
final _wearableLogFilePattern = RegExp(
  r'\.log(?:\.bak\.\d+)?$',
  caseSensitive: false,
);

bool isWearableLogArchive(String name) => name.toLowerCase().endsWith('.zip');

bool isWearableLogInput(String name) =>
    isWearableLogArchive(name) || _wearableLogFilePattern.hasMatch(name);

/// Extracts bound-device credentials from a Xiaomi Fitness wearable-log ZIP.
List<MiCloudDevice> extractMiDevicesFromWearableLogZip(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > maxWearableLogArchiveBytes) {
    throw const FormatException('Invalid or oversized wearable log archive');
  }
  return _extractMiDevicesFromLogs(ZipDecoder().decodeBytes(bytes).files);
}

/// Scans a selection as a single batch so companion logs can resolve MACs
/// redacted in device records.
List<MiCloudDevice> extractMiDevicesFromWearableLogs(
  List<({String name, Uint8List bytes})> inputs,
) {
  Iterable<ArchiveFile> entries() sync* {
    for (final input in inputs) {
      if (input.bytes.isEmpty) continue;
      if (isWearableLogArchive(input.name)) {
        if (input.bytes.length > maxWearableLogArchiveBytes) continue;
        Archive archive;
        try {
          archive = ZipDecoder().decodeBytes(input.bytes);
        } catch (_) {
          continue;
        }
        yield* archive.files;
      } else if (_wearableLogFilePattern.hasMatch(input.name) &&
          input.bytes.length <= maxWearableLogFileBytes) {
        yield ArchiveFile(input.name, input.bytes.length, input.bytes);
      }
    }
  }

  return _extractMiDevicesFromLogs(entries(), skipUnreadable: true);
}

/// Device records must have a valid address and key, which excludes account
/// cookie values even when they use the same auth_key field name.
List<MiCloudDevice> _extractMiDevicesFromLogs(
  Iterable<ArchiveFile> files, {
  bool skipUnreadable = false,
}) {
  final candidates = <String, MiCloudDevice>{};
  final logAddresses = <String>{};
  var totalLogBytes = 0;
  final keyPattern = RegExp(r'^[0-9a-fA-F]{32}$');
  final macPattern = RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$');
  final macSuffixPattern = RegExp(r'^[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){1,5}$');
  final embeddedMacPattern = RegExp(
    r'(?<![0-9a-fA-F])(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}(?![0-9a-fA-F])',
  );
  final deviceJsonLogPattern = RegExp(
    r'^XiaomiFit\.(?:device|main)\.log(?:\.bak\.\d+)?$',
  );

  void addRecord(Map<dynamic, dynamic> value) {
    final device = MiCloudDevice.fromJson(value.cast<String, dynamic>());
    final mac = _normalizeLogMac(device.mac);
    final authKey = device.authKey.trim().toLowerCase();
    if ((!macPattern.hasMatch(mac) && !macSuffixPattern.hasMatch(mac)) ||
        !keyPattern.hasMatch(authKey)) {
      return;
    }
    final candidateId = [
      device.model,
      device.name,
      device.serialNumber,
      mac,
    ].join('|');
    candidates[candidateId] = MiCloudDevice(
      name: device.name.trim(),
      model: device.model.trim(),
      mac: mac,
      authKey: authKey,
      firmwareVersion: device.firmwareVersion.trim(),
      serialNumber: device.serialNumber.trim(),
    );
  }

  for (final file in files) {
    if (!file.isFile) continue;
    final name = file.name.split(RegExp(r'[/\\]')).last;
    if (!_wearableLogFilePattern.hasMatch(name)) {
      continue;
    }
    if (file.size > maxWearableLogFileBytes) continue;
    if (totalLogBytes + file.size > maxWearableLogBatchBytes) {
      if (skipUnreadable) continue;
      throw const FormatException('Wearable log archive is too large');
    }
    totalLogBytes += file.size;

    Uint8List? content;
    try {
      content = file.readBytes();
    } catch (_) {
      if (skipUnreadable) continue;
      rethrow;
    }
    if (content == null) continue;
    final log = utf8.decode(content, allowMalformed: true);
    for (final match in embeddedMacPattern.allMatches(log)) {
      logAddresses.add(_normalizeLogMac(match.group(0)!));
    }
    if (deviceJsonLogPattern.hasMatch(name)) {
      for (final value in _scanJsonObjects(log)) {
        _visitDeviceJson(value, addRecord);
      }
    }
    file.clear();
  }
  // A device can appear both as a full-MAC record and as a redacted-suffix
  // record, producing two candidates with the same authKey. Deduplicate after
  // address resolution and prefer the entry that carries a complete MAC.
  final resolvedByIdentity = <String, MiCloudDevice>{};
  for (final device in candidates.values) {
    final address = resolveMiCloudDeviceAddress(device, logAddresses);
    final resolved = address == null
        ? device
        : MiCloudDevice(
            name: device.name,
            model: device.model,
            mac: address,
            authKey: device.authKey,
            firmwareVersion: device.firmwareVersion,
            serialNumber: device.serialNumber,
          );
    final identity = '${resolved.authKey}|${resolved.serialNumber}';
    final existing = resolvedByIdentity[identity];
    if (existing == null ||
        (!macPattern.hasMatch(existing.mac) &&
            macPattern.hasMatch(resolved.mac))) {
      resolvedByIdentity[identity] = resolved;
    }
  }
  return resolvedByIdentity.values.toList(growable: false);
}

String _normalizeLogMac(String value) {
  final normalized = value.trim().replaceAll('-', ':').toUpperCase();
  return normalized;
}

/// Yields complete JSON objects embedded in Xiaomi's line-oriented logs.
///
/// The app writes both compact HTTP responses and pretty-printed device
/// snapshots. Matching a single fixed record shape misses the latter and also
/// breaks as soon as Xiaomi adds a nested object. A small balanced-brace
/// scanner keeps this parser independent of the surrounding log prefix while
/// still avoiding a permissive regex over the whole archive.
Iterable<Object?> _scanJsonObjects(String source) sync* {
  const maxObjectBytes = 4 * 1024 * 1024;
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var index = 0; index < source.length; index += 1) {
    final char = source.codeUnitAt(index);
    if (start < 0) {
      if (char == 0x7b) {
        start = index;
        depth = 1;
        inString = false;
        escaped = false;
      }
      continue;
    }

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == 0x5c) {
        escaped = true;
      } else if (char == 0x22) {
        inString = false;
      }
      continue;
    }
    if (char == 0x22) {
      inString = true;
    } else if (char == 0x7b) {
      depth += 1;
    } else if (char == 0x7d) {
      depth -= 1;
      if (depth == 0) {
        final fragment = source.substring(start, index + 1);
        try {
          yield jsonDecode(fragment);
        } on FormatException {
          // Plain-text log messages also contain braces; ignore those.
        }
        start = -1;
      }
    }

    if (start >= 0 && index - start >= maxObjectBytes) {
      start = -1;
      depth = 0;
      inString = false;
      escaped = false;
    }
  }
}

void _visitDeviceJson(Object? value, void Function(Map<dynamic, dynamic>) add) {
  if (value is Map) {
    final detail = value['detail'];
    if (detail is Map &&
        (value.containsKey('model') || value.containsKey('name'))) {
      add(value);
    }
    for (final child in value.values) {
      _visitDeviceJson(child, add);
    }
  } else if (value is List) {
    for (final child in value) {
      _visitDeviceJson(child, add);
    }
  }
}

class MiAccountService {
  MiAccountService({Dio? dio}) : _dio = dio ?? createAppHttpTransport();

  static final _log = getLogger('MiAccountService');
  final Dio _dio;

  static const _sessionKey = PrivateAppState.miToken;
  static const _sdkVersion = 'accountsdk-18.8.15';
  static const _healthSid = 'miothealth';
  static const _serviceLoginUrl =
      'https://account.xiaomi.com/pass/serviceLogin?sid=$_healthSid&_json=true';
  static const _serviceLoginAuthUrl =
      'https://account.xiaomi.com/pass/serviceLoginAuth2';
  static const _deviceListUrl =
      'https://hlth.io.mi.com/app/v1/source/get_source_list';

  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 13; OronBox) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  Future<MiAccountToken?> loadStoredToken() async {
    final store = PrivateAppState.instance;
    await store.reload(key: _sessionKey);
    final raw = store.readString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      final token = value is Map<String, Object?>
          ? MiAccountToken.fromJson(value)
          : value is Map
          ? MiAccountToken.fromJson(value.cast<String, Object?>())
          : null;
      return token;
    } catch (_) {
      // Treat a malformed session as signed out.
    }
    return null;
  }

  Future<void> persistToken(MiAccountToken token) async {
    if (!token.isValid) {
      throw StateError('Cannot persist an invalid Xiaomi session');
    }
    await PrivateAppState.instance.update({
      _sessionKey: jsonEncode(token.toJson()),
    });
  }

  Future<void> clearStoredToken() async {
    await PrivateAppState.instance.update({_sessionKey: null});
  }

  /// Renews the short-lived Xiaomi service session with the stored pass token.
  ///
  /// Xiaomi does not return a reliable client-visible expiry timestamp for
  /// the service token. The account pass token is the credential used to run
  /// the serviceLogin -> STS exchange again. If that credential is no longer
  /// accepted, the caller must ask the user to sign in again.
  Future<MiAccountToken> refreshToken({
    required MiAccountToken token,
    String userAgent = defaultUserAgent,
  }) async {
    if (token.userId.isEmpty ||
        token.deviceId.isEmpty ||
        token.passToken.isEmpty) {
      await invalidateStoredToken(token);
      throw const MiAccountSessionExpired();
    }

    // Do not send the old serviceToken here. Xiaomi's account endpoint uses
    // the long-lived account cookies to mint a fresh service session.
    final cookieJar = _CookieJar()
      ..set('sdkVersion', _sdkVersion)
      ..set('deviceId', token.deviceId)
      ..set('userId', token.userId)
      ..set('passToken', token.passToken);
    if (token.cUserId.isNotEmpty) cookieJar.set('cUserId', token.cUserId);

    late final Response<String> response;
    try {
      response = await _dio.get<String>(
        _serviceLoginUrl,
        options: _requestOptions(userAgent, cookieJar),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (_isSessionFailureStatus(status)) {
        await invalidateStoredToken(token);
        throw MiAccountSessionExpired(statusCode: status);
      }
      rethrow;
    }
    cookieJar.mergeSetCookie(response.headers);

    final body = _fillAuthResponseFromHeaders(
      _decodeJsonBody(response.data),
      response.headers,
    );
    final code = _parseCode(body);
    final requiresInteractiveLogin =
        (body['_sign']?.toString() ?? '').isNotEmpty ||
        (body['notificationUrl']?.toString() ?? '').trim().isNotEmpty;
    if (code != 0 || requiresInteractiveLogin) {
      await invalidateStoredToken(token);
      throw MiAccountSessionExpired(statusCode: code > 0 ? code : null);
    }

    late final MiAccountToken refreshed;
    try {
      refreshed = await _finishLogin(
        body,
        userAgent: userAgent,
        deviceId: token.deviceId,
        cookieJar: cookieJar,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (_isSessionFailureStatus(status)) {
        await invalidateStoredToken(token);
        throw MiAccountSessionExpired(statusCode: status);
      }
      rethrow;
    } on StateError {
      await invalidateStoredToken(token);
      throw const MiAccountSessionExpired();
    }

    await _persistRefreshedTokenIfCurrent(token, refreshed);
    _log.info('Xiaomi account service session refreshed');
    return refreshed;
  }

  /// Clears the persisted session only when it is still the session that
  /// failed. A login started concurrently must not be removed by an older
  /// request completing later.
  Future<void> invalidateStoredToken(MiAccountToken token) async {
    final removed = await PrivateAppState.instance.update(
      {_sessionKey: null},
      when: (current) {
        final raw = current[_sessionKey] as String?;
        if (raw == null) return false;
        try {
          final stored = MiAccountToken.fromJson(
            (jsonDecode(raw) as Map).cast(),
          );
          return stored != null && _sameSession(stored, token);
        } catch (_) {
          return false;
        }
      },
    );
    if (!removed) return;
    _log.warning(
      'Xiaomi account session invalidated after authentication failure',
    );
  }

  Future<MiAccountToken> login({
    required String username,
    required String password,
    String userAgent = defaultUserAgent,
  }) async {
    try {
      return await _login(
        username: username,
        password: password,
        userAgent: userAgent,
      );
    } on MiAccountTwoFactorRequired {
      _log.info('Xiaomi account login requires two-factor verification');
      rethrow;
    } catch (error, stackTrace) {
      _log.warning(
        'Xiaomi account login failed: ${_describeFailure(error)}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// One-line description of a login failure with nothing secret in it.
  String _describeFailure(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final endpoint = safeHttpEndpoint(error.requestOptions.uri);
      return '${error.type.name} on $endpoint'
          '${status == null ? '' : ' (HTTP $status)'}';
    }
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 240 ? text : '${text.substring(0, 237)}...';
  }

  Future<MiAccountToken> _login({
    required String username,
    required String password,
    required String userAgent,
  }) async {
    final deviceId = _randomDeviceId();
    final cookieJar = _CookieJar()
      ..set('sdkVersion', _sdkVersion)
      ..set('deviceId', deviceId);

    final step1 = await _dio.get<String>(
      _serviceLoginUrl,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step1.headers);

    final step1Body = _decodeJsonBody(step1.data);
    final sign = step1Body['_sign']?.toString();
    if (sign == null || sign.isEmpty) {
      return _finishLogin(
        step1Body,
        userAgent: userAgent,
        deviceId: deviceId,
        cookieJar: cookieJar,
      );
    }

    final passwordHash = md5
        .convert(utf8.encode(password))
        .toString()
        .toUpperCase();
    final form = <String, String>{
      'sid': _healthSid,
      'hash': passwordHash,
      'callback': 'https://sts-hlth.io.mi.com/healthapp/sts',
      'qs': '%3Fsid%3Dmiothealth%26_json%3Dtrue',
      'user': username,
      '_sign': sign,
      '_json': 'true',
    };

    final step2 = await _dio.post<String>(
      _serviceLoginAuthUrl,
      data: form,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step2.headers);

    final step2Body = _decodeJsonBody(step2.data);
    _log.info(
      'Xiaomi account auth response: code=${_parseCode(step2Body)}, '
      'verification=${(step2Body['notificationUrl']?.toString() ?? '').isNotEmpty}, '
      'ssecurity=${(step2Body['ssecurity']?.toString() ?? '').isEmpty ? 'absent' : 'present'}',
    );
    // A non-empty `_sign` here means Xiaomi wants an extra credential step
    // (two-factor verification). `_finishLogin` already inspects
    // `notificationUrl` and throws `MiAccountTwoFactorRequired` so the host
    // command layer can surface `two_factor_required` and open the 2FA flow.
    // Throwing a plain StateError here instead (as this used to do) would
    // escape the host's `MiAccountTwoFactorRequired` catch and surface as a
    // generic `internal` failure.
    return _finishLogin(
      step2Body,
      userAgent: userAgent,
      deviceId: deviceId,
      cookieJar: cookieJar,
    );
  }

  Future<List<MiCloudDevice>> fetchBoundDevices({
    required MiAccountToken token,
    String userAgent = defaultUserAgent,
  }) async {
    final body = await _miServiceCallEncrypted(
      token: token,
      url: _deviceListUrl,
      paramsPlain: const {'data': '{"page_size":50,"status":1}'},
      userAgent: userAgent,
    );

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final code = _parseCode(payload);
    if (_isSessionFailureCode(code)) {
      await invalidateStoredToken(token);
      throw MiAccountSessionExpired(statusCode: code);
    }
    if (code != 0 && code != 200) {
      throw StateError(
        'Xiaomi device list failed: code=$code, message=${payload['message'] ?? payload['msg'] ?? ''}',
      );
    }
    final result =
        (payload['result'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final list = (result['list'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((item) => MiCloudDevice.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<String> fetchAgpsFileUrl({
    required MiAccountToken token,
    required String source,
    required int type,
    required bool online,
    required int days,
    required String model,
    String userAgent = defaultUserAgent,
  }) async {
    final url = online
        ? 'https://hlth.io.mi.com/healthapp/agps/get_online_file'
        : 'https://hlth.io.mi.com/healthapp/agps/get_offline_file';
    final body = await _miServiceCallEncrypted(
      token: token,
      url: url,
      signaturePath: '/agps/${online ? 'get_online_file' : 'get_offline_file'}',
      paramsPlain: {
        'data': jsonEncode({
          'source': source,
          'days': days,
          'gps_type': type,
          'model': model,
        }),
      },
      userAgent: userAgent,
    );
    final decoded = jsonDecode(body);
    final payload = decoded is Map
        ? decoded.cast<String, dynamic>()
        : const <String, dynamic>{};
    final code = _parseCode(payload);
    if (_isSessionFailureCode(code)) {
      await invalidateStoredToken(token);
      throw MiAccountSessionExpired(statusCode: code);
    }
    if (code != 0 && code != 200) {
      throw StateError(
        'Xiaomi AGPS metadata failed: code=$code, '
        'message=${payload['message'] ?? payload['msg'] ?? ''}',
      );
    }
    final result = (payload['result'] as Map?)?.cast<String, dynamic>();
    final fileUrl = result?['agps_fds_url']?.toString() ?? '';
    if (fileUrl.isEmpty) {
      throw StateError('Xiaomi AGPS response has no file URL');
    }
    return fileUrl;
  }

  Future<MiAccountToken> completeTwoFactorLogin({
    required MiAccountTwoFactorRequired challenge,
    required String cookieHeader,
    String userAgent = defaultUserAgent,
  }) async {
    // `passToken` is the only cookie that proves the browser verification
    // actually succeeded. Without it the service-login exchange cannot succeed,
    // so fail with a precise reason instead of retrying three times and
    // reporting a vague credential error.
    if (_extractCookieValue(cookieHeader, 'passToken') == null) {
      _log.warning('Xiaomi 2FA returned no passToken; verification incomplete');
      throw StateError(
        'Xiaomi 2FA did not return a pass token; verification incomplete',
      );
    }
    final deviceId =
        _extractCookieValue(cookieHeader, 'deviceId') ?? challenge.deviceId;
    final cookieJar = _CookieJar()
      ..set('sdkVersion', _sdkVersion)
      ..set('deviceId', deviceId)
      ..mergeCookieHeader(cookieHeader);

    Map<String, dynamic>? lastCredentialStepBody;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }

      final step1 = await _dio.get<String>(
        _serviceLoginUrl,
        options: _requestOptions(userAgent, cookieJar),
      );
      cookieJar.mergeSetCookie(step1.headers);

      final body = _fillAuthResponseFromHeaders(
        _decodeJsonBody(step1.data),
        step1.headers,
      );
      if ((body['_sign']?.toString() ?? '').isNotEmpty) {
        lastCredentialStepBody = body;
        continue;
      }

      final notificationUrl = body['notificationUrl']?.toString();
      if (notificationUrl != null && notificationUrl.trim().isNotEmpty) {
        throw MiAccountTwoFactorRequired(
          url: notificationUrl,
          deviceId: deviceId,
        );
      }

      return _finishLogin(
        body,
        userAgent: userAgent,
        deviceId: deviceId,
        cookieJar: cookieJar,
      );
    }
    throw StateError(
      'Verified Xiaomi 2FA session still requires account credentials'
      '${lastCredentialStepBody == null ? '' : ' after retry'}',
    );
  }

  Future<MiAccountToken> _finishLogin(
    Map<String, dynamic> authResp, {
    required String userAgent,
    required String deviceId,
    required _CookieJar cookieJar,
  }) async {
    final code = _parseCode(authResp);
    final ssecurity = authResp['ssecurity']?.toString() ?? '';
    final notificationUrl = authResp['notificationUrl']?.toString();
    if (notificationUrl != null && notificationUrl.trim().isNotEmpty) {
      throw MiAccountTwoFactorRequired(
        url: notificationUrl,
        deviceId: deviceId,
      );
    }
    if (code != 0 || ssecurity.isEmpty) {
      if (code == 70016) {
        throw StateError('Xiaomi account username or password is incorrect');
      }
      throw StateError(
        'Xiaomi account login failed: code=$code, description=${authResp['description'] ?? authResp['desc'] ?? ''}',
      );
    }

    final location = authResp['location']?.toString() ?? '';
    if (location.isEmpty) {
      throw StateError('Xiaomi account login response is missing STS location');
    }

    final step3 = await _dio.get<String>(
      location,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step3.headers);
    final serviceToken =
        cookieJar.value('serviceToken') ??
        _extractHeaderCookie(step3.headers, 'serviceToken');
    if (serviceToken == null || serviceToken.isEmpty) {
      throw StateError('Xiaomi account login did not return serviceToken');
    }

    return MiAccountToken(
      userId: authResp['userId']?.toString() ?? '',
      deviceId: deviceId,
      ssecurity: ssecurity,
      serviceToken: serviceToken,
      cUserId:
          cookieJar.value('cUserId') ?? authResp['cUserId']?.toString() ?? '',
      passToken:
          cookieJar.value('passToken') ??
          authResp['passToken']?.toString() ??
          '',
      psecurity: authResp['psecurity']?.toString() ?? '',
    );
  }

  Future<String> _miServiceCallEncrypted({
    required MiAccountToken token,
    required String url,
    String? signaturePath,
    required Map<String, String> paramsPlain,
    required String userAgent,
    bool allowRefresh = true,
  }) async {
    final nonce = _generateNonce(DateTime.now().millisecondsSinceEpoch);
    final signedNonce = _calcSignedNonce(token.ssecurity, nonce);
    final path = signaturePath ?? Uri.parse(url).path;

    final signedParams = Map<String, String>.from(paramsPlain);
    signedParams['rc4_hash__'] = _generateEncSignature(
      path: path,
      method: 'POST',
      signedNonce: signedNonce,
      params: paramsPlain,
    );

    final encryptedParams = _rc4EncryptParams(signedNonce, signedParams);
    encryptedParams['signature'] = _generateEncSignature(
      path: path,
      method: 'POST',
      signedNonce: signedNonce,
      params: encryptedParams,
    );
    encryptedParams['_nonce'] = nonce;

    final cookieParts = <String>[
      'sdkVersion=$_sdkVersion',
      'locale=en_us',
      if (token.deviceId.isNotEmpty) 'deviceId=${token.deviceId}',
      if (token.userId.isNotEmpty) 'userId=${token.userId}',
      if (token.cUserId.isNotEmpty) 'cUserId=${token.cUserId}',
      if (token.passToken.isNotEmpty) 'passToken=${token.passToken}',
      'serviceToken=${token.serviceToken}',
    ];

    late final Response<String> response;
    try {
      response = await _dio.post<String>(
        url,
        data: encryptedParams,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': userAgent,
            'region_tag': 'cn',
            'HandleParams': 'true',
            'Cookie': cookieParts.join('; '),
          },
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (_isSessionFailureStatus(status)) {
        if (!allowRefresh) {
          await invalidateStoredToken(token);
          throw MiAccountSessionExpired(statusCode: status);
        }
        final refreshed = await refreshToken(
          token: token,
          userAgent: userAgent,
        );
        return _miServiceCallEncrypted(
          token: refreshed,
          url: url,
          signaturePath: signaturePath,
          paramsPlain: paramsPlain,
          userAgent: userAgent,
          allowRefresh: false,
        );
      }
      rethrow;
    }

    final raw = (response.data ?? '').trim();
    if (raw.isEmpty) return raw;
    final encoded = raw.startsWith('"') && raw.endsWith('"')
        ? raw.substring(1, raw.length - 1)
        : raw;
    final encrypted = base64.decode(encoded);
    final decrypted = _rc4Crypt(base64.decode(signedNonce), encrypted);
    final result = utf8.decode(decrypted);
    if (_bodySignalsSessionFailure(result)) {
      if (!allowRefresh) {
        await invalidateStoredToken(token);
        throw const MiAccountSessionExpired();
      }
      final refreshed = await refreshToken(token: token, userAgent: userAgent);
      return _miServiceCallEncrypted(
        token: refreshed,
        url: url,
        signaturePath: signaturePath,
        paramsPlain: paramsPlain,
        userAgent: userAgent,
        allowRefresh: false,
      );
    }
    return result;
  }

  Options _requestOptions(String userAgent, _CookieJar cookieJar) {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      responseType: ResponseType.plain,
      headers: {'User-Agent': userAgent, 'Cookie': cookieJar.header},
    );
  }

  Map<String, dynamic> _decodeJsonBody(String? body) {
    const prefix = '&&&START&&&';
    final text = (body ?? '').trim();
    final stripped = text.startsWith(prefix)
        ? text.substring(prefix.length)
        : text;
    return jsonDecode(stripped) as Map<String, dynamic>;
  }

  Map<String, dynamic> _fillAuthResponseFromHeaders(
    Map<String, dynamic> body,
    Headers headers,
  ) {
    final filled = Map<String, dynamic>.from(body);
    for (final key in ['passToken', 'cUserId', 'userId']) {
      filled.putIfAbsent(key, () => _extractHeaderCookie(headers, key));
    }

    final extensionPragma =
        _headerValue(headers, 'extension-pragma') ??
        _headerValue(headers, 'Extension-Pragma');
    if (extensionPragma != null && extensionPragma.isNotEmpty) {
      try {
        final extension = jsonDecode(extensionPragma) as Map<String, dynamic>;
        for (final key in ['ssecurity', 'psecurity', 'nonce']) {
          final value = extension[key];
          if ((filled[key]?.toString() ?? '').isEmpty && value != null) {
            filled[key] = value;
          }
        }
      } catch (_) {
        // Xiaomi sometimes omits this header; malformed values should not hide
        // the primary account response.
      }
    }
    return filled;
  }

  String? _headerValue(Headers headers, String name) {
    final values = headers.map[name] ?? headers.map[name.toLowerCase()];
    return values?.firstOrNull?.trim();
  }

  int _parseCode(Map<String, dynamic> value) {
    final raw = value['code'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? -1;
  }

  bool _isSessionFailureStatus(int? status) => status == 401 || status == 403;

  bool _isSessionFailureCode(int code) => code == 401 || code == 403;

  bool _bodySignalsSessionFailure(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map &&
          _isSessionFailureCode(_parseCode(value.cast<String, dynamic>()));
    } catch (_) {
      return false;
    }
  }

  bool _sameSession(MiAccountToken first, MiAccountToken second) =>
      first.ssecurity == second.ssecurity &&
      first.serviceToken == second.serviceToken;

  Future<void> _persistRefreshedTokenIfCurrent(
    MiAccountToken previous,
    MiAccountToken refreshed,
  ) async {
    final stored = await loadStoredToken();
    if (stored == null || !_sameRefreshSource(stored, previous)) return;
    await persistToken(refreshed);
  }

  bool _sameRefreshSource(MiAccountToken first, MiAccountToken second) =>
      first.userId == second.userId &&
      first.deviceId == second.deviceId &&
      first.passToken == second.passToken;

  String _generateNonce(int millis) {
    final random = Random.secure();
    final bytes = BytesBuilder();
    bytes.add(List<int>.generate(8, (_) => random.nextInt(256)));
    final minutes = millis ~/ 60000;
    bytes.add([
      (minutes >> 24) & 0xff,
      (minutes >> 16) & 0xff,
      (minutes >> 8) & 0xff,
      minutes & 0xff,
    ]);
    return base64.encode(bytes.toBytes());
  }

  String _calcSignedNonce(String ssecurity, String nonce) {
    final bytes = BytesBuilder()
      ..add(base64.decode(ssecurity))
      ..add(base64.decode(nonce));
    return base64.encode(sha256.convert(bytes.toBytes()).bytes);
  }

  String _generateEncSignature({
    required String path,
    required String method,
    required String signedNonce,
    required Map<String, String> params,
  }) {
    final keys = params.keys.toList()..sort();
    final pieces = <String>[
      method.toUpperCase(),
      path,
      for (final key in keys) '$key=${params[key]}',
      signedNonce,
    ];
    return base64.encode(sha1.convert(utf8.encode(pieces.join('&'))).bytes);
  }

  Map<String, String> _rc4EncryptParams(
    String signedNonce,
    Map<String, String> paramsPlain,
  ) {
    final key = base64.decode(signedNonce);
    final keys = paramsPlain.keys.toList()..sort();
    final cipher = _Rc4(key)..drop(1024);
    return {
      for (final keyName in keys)
        keyName: base64.encode(
          cipher.crypt(utf8.encode(paramsPlain[keyName]!)),
        ),
    };
  }

  Uint8List _rc4Crypt(List<int> key, List<int> data) {
    final cipher = _Rc4(key)..drop(1024);
    return cipher.crypt(data);
  }

  String _randomDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String? _extractHeaderCookie(Headers headers, String name) {
    final setCookie = headers.map['set-cookie'] ?? const <String>[];
    for (final cookie in setCookie) {
      final value = _parseCookiePair(cookie, name);
      if (value != null) return value;
    }
    return null;
  }

  String? _extractCookieValue(String cookieHeader, String name) {
    for (final rawPair in cookieHeader.split(';')) {
      final pair = rawPair.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      if (pair.substring(0, index).trim() == name) {
        return pair.substring(index + 1).trim();
      }
    }
    return null;
  }
}

class _CookieJar {
  final _values = <String, String>{};

  String get header =>
      _values.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

  String? value(String key) => _values[key];

  void set(String key, String value) {
    if (key.isNotEmpty && value.isNotEmpty) {
      _values[key] = value;
    }
  }

  void mergeSetCookie(Headers headers) {
    final setCookie = headers.map['set-cookie'] ?? const <String>[];
    for (final cookie in setCookie) {
      final pair = cookie.split(';').first.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      set(pair.substring(0, index).trim(), pair.substring(index + 1).trim());
    }
  }

  void mergeCookieHeader(String cookieHeader) {
    for (final rawPair in cookieHeader.split(';')) {
      final pair = rawPair.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      set(pair.substring(0, index).trim(), pair.substring(index + 1).trim());
    }
  }
}

String? _parseCookiePair(String cookie, String name) {
  final pair = cookie.split(';').first.trim();
  final index = pair.indexOf('=');
  if (index <= 0) return null;
  final cookieName = pair.substring(0, index).trim();
  if (cookieName != name && !cookieName.endsWith('_$name')) return null;
  return pair.substring(index + 1).trim();
}

class _Rc4 {
  _Rc4(List<int> key) {
    for (var n = 0; n < 256; n++) {
      _s[n] = n;
    }
    var j = 0;
    for (var n = 0; n < 256; n++) {
      j = (j + _s[n] + key[n % key.length]) & 0xff;
      final tmp = _s[n];
      _s[n] = _s[j];
      _s[j] = tmp;
    }
  }

  final _s = Uint8List(256);
  var _i = 0;
  var _j = 0;

  void drop(int count) {
    for (var n = 0; n < count; n++) {
      _next();
    }
  }

  Uint8List crypt(List<int> data) {
    final out = Uint8List(data.length);
    for (var n = 0; n < data.length; n++) {
      out[n] = data[n] ^ _next();
    }
    return out;
  }

  int _next() {
    _i = (_i + 1) & 0xff;
    _j = (_j + _s[_i]) & 0xff;
    final tmp = _s[_i];
    _s[_i] = _s[_j];
    _s[_j] = tmp;
    return _s[(_s[_i] + _s[_j]) & 0xff];
  }
}

final miAccountServiceProvider = Provider<MiAccountService>((ref) {
  return MiAccountService(dio: ref.read(appDioProvider));
});
