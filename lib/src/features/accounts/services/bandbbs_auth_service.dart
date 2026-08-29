import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/core/extensions/riverpod_mounted_ext.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

const _clientAppId = 'oronbox';
const _callbackUri = 'oronbox://oauth/bandbbs';

/// Read-only BandBBS access token held by the client. The matching refresh
/// token always stays on the OronBox server.
class BandBbsToken {
  const BandBbsToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.scope,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final String scope;

  bool get isExpired => DateTime.now().toUtc().isAfter(
    expiresAt.subtract(const Duration(minutes: 2)),
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_at': expiresAt.toIso8601String(),
    'scope': scope,
  };

  static BandBbsToken fromTokenResponse(Map<String, Object?> json) {
    final expiresIn = _asInt(json['expires_in']);
    final accessToken = json['access_token']?.toString().trim() ?? '';
    if (accessToken.isEmpty || expiresIn <= 0) {
      throw const FormatException('Invalid BandBBS token response');
    }
    return BandBbsToken(
      accessToken: accessToken,
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      scope: json['scope']?.toString() ?? '',
    );
  }

  static BandBbsToken? fromJson(Map<String, Object?> json) {
    final accessToken = json['access_token']?.toString() ?? '';
    final expiresAtRaw = json['expires_at']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (accessToken.isEmpty || expiresAt == null) {
      return null;
    }
    return BandBbsToken(
      accessToken: accessToken,
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: expiresAt.toUtc(),
      scope: json['scope']?.toString() ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// OronBox's own session credential, used for ob-api endpoints.
class OronBoxSession {
  const OronBoxSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(
    expiresAt.subtract(const Duration(minutes: 2)),
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toIso8601String(),
  };

  static OronBoxSession fromTokenResponse(Map<String, Object?> json) {
    final expiresIn = BandBbsToken._asInt(json['expires_in']);
    final accessToken = json['access_token']?.toString().trim() ?? '';
    final refreshToken = json['refresh_token']?.toString().trim() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty || expiresIn <= 0) {
      throw const FormatException('Invalid OronBox session response');
    }
    return OronBoxSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  static OronBoxSession? fromJson(Map<String, Object?> json) {
    final accessToken = json['access_token']?.toString() ?? '';
    final refreshToken = json['refresh_token']?.toString() ?? '';
    final expiresAtRaw = json['expires_at']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (accessToken.isEmpty || refreshToken.isEmpty || expiresAt == null) {
      return null;
    }
    return OronBoxSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

abstract interface class OronBoxSessionAccess {
  Future<OronBoxSession?> sessionIfNeeded();

  Future<void> expireSession();
}

class BandBbsSessionExpiredException implements CodedError {
  const BandBbsSessionExpiredException();

  @override
  String get code => 'invalid_refresh_token';

  @override
  String get message => 'OronBox session expired';

  @override
  Object? get details => null;

  @override
  String toString() => message;
}

class BandBbsAuthState {
  const BandBbsAuthState({
    required this.token,
    required this.session,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isBusy,
    required this.lastError,
  });

  /// BandBBS read-only access token, used to query bandbbs.cn directly.
  final BandBbsToken? token;

  /// OronBox session, used for ob-api endpoints.
  final OronBoxSession? session;
  final String? userId;
  final String? username;
  final String? avatarUrl;
  final bool isBusy;
  final String? lastError;

  bool get isSignedIn => session != null;

  BandBbsAuthState copyWith({
    BandBbsToken? token,
    bool clearToken = false,
    OronBoxSession? session,
    bool clearSession = false,
    String? userId,
    bool clearUserId = false,
    String? username,
    bool clearUsername = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    bool? isBusy,
    String? lastError,
    bool clearLastError = false,
  }) {
    return BandBbsAuthState(
      token: clearToken ? null : token ?? this.token,
      session: clearSession ? null : session ?? this.session,
      userId: clearUserId ? null : userId ?? this.userId,
      username: clearUsername ? null : username ?? this.username,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      isBusy: isBusy ?? this.isBusy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  static const empty = BandBbsAuthState(
    token: null,
    session: null,
    userId: null,
    username: null,
    avatarUrl: null,
    isBusy: false,
    lastError: null,
  );
}

class BandBbsAuthNotifier extends Notifier<BandBbsAuthState>
    implements OronBoxSessionAccess {
  static const _keyToken = 'bandbbs.oauth.token';
  static const _keySession = 'oronbox.session.token';
  static const _keyUserId = 'bandbbs.oauth.user_id';
  static const _keyUsername = 'bandbbs.oauth.username';
  static const _keyAvatarUrl = 'bandbbs.oauth.avatar_url';

  final Logger _log = getLogger('BandBbsAuthService');
  Future<BandBbsToken?>? _tokenRefresh;
  Future<OronBoxSession?>? _sessionRefresh;
  Future<void>? _credentialRestore;
  StreamSubscription<CommandEvent>? _hostEvents;
  int _credentialRevision = 0;

  final Dio _dio = createAppHttpTransport(
    options: BaseOptions(
      baseUrl: oronBoxServerBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  @override
  BandBbsAuthState build() {
    final prefs = SharedPrefsService.instance;
    final initial = BandBbsAuthState.empty.copyWith(
      userId: prefs.getString(_keyUserId),
      username: prefs.getString(_keyUsername),
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
    _hostEvents = ref.read(applicationHostProvider).events.listen((event) {
      if (event.event == 'host.connected') {
        unawaited(reloadCredentials());
        return;
      }
      if (event.event != 'account.state') return;
      final rows = event.data['state'];
      if (rows is! List) {
        unawaited(reloadCredentials());
        return;
      }
      final bandbbs = rows.whereType<Map>().cast<Map>().firstWhere(
        (row) => row['provider']?.toString() == 'bandbbs',
        orElse: () => const {},
      );
      final signedIn = bandbbs['signedIn'];
      unawaited(
        reloadCredentials(clearWhenMissing: signedIn is bool && !signedIn),
      );
    });
    ref.onDispose(() => unawaited(_hostEvents?.cancel()));
    _credentialRestore = Future.microtask(_restoreCredentials);
    return initial;
  }

  Future<void> _restoreCredentials() async {
    final revision = _credentialRevision;
    try {
      final prefs = SharedPrefsService.instance;
      final tokenRaw = prefs.getString(_keyToken);
      final sessionRaw = prefs.getString(_keySession);
      if (!ref.mounted || revision != _credentialRevision) return;
      final token = _restore(tokenRaw, BandBbsToken.fromJson);
      final session = _restore(sessionRaw, OronBoxSession.fromJson);
      state = state.copyWith(token: token, session: session);
      if (session != null && state.username == null) {
        await _fetchCurrentUser(session);
      }
    } catch (error) {
      _log.warning('Unable to restore persisted credentials', error);
    }
  }

  Future<void> restoreCredentials() async {
    await _credentialRestore;
  }

  /// Reload credentials written by the daemon process after an OAuth flow.
  Future<void> reloadCredentials({bool clearWhenMissing = false}) async {
    await _credentialRestore;
    final revision = ++_credentialRevision;
    _sessionRefresh = null;
    _tokenRefresh = null;
    final prefs = SharedPrefsService.instance;
    if (prefs.isInitialized) await prefs.reload();
    final tokenRaw = prefs.isInitialized ? prefs.getString(_keyToken) : null;
    final sessionRaw = prefs.isInitialized
        ? prefs.getString(_keySession)
        : null;
    if (!ref.mounted || revision != _credentialRevision) return;
    if (sessionRaw == null && !clearWhenMissing) return;
    final userId = prefs.isInitialized ? prefs.getString(_keyUserId) : null;
    final username = prefs.isInitialized ? prefs.getString(_keyUsername) : null;
    final avatarUrl = prefs.isInitialized
        ? prefs.getString(_keyAvatarUrl)
        : null;
    state = state.copyWith(
      token: _restore(tokenRaw, BandBbsToken.fromJson),
      clearToken: clearWhenMissing && tokenRaw == null,
      session: _restore(sessionRaw, OronBoxSession.fromJson),
      clearSession: clearWhenMissing && sessionRaw == null,
      userId: userId,
      clearUserId: clearWhenMissing && userId == null,
      username: username,
      clearUsername: clearWhenMissing && username == null,
      avatarUrl: avatarUrl,
      clearAvatarUrl: clearWhenMissing && avatarUrl == null,
      clearLastError: true,
    );
  }

  static T? _restore<T>(String? raw, T? Function(Map<String, Object?>) parse) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return parse(decoded);
      if (decoded is Map) return parse(decoded.cast<String, Object?>());
    } catch (_) {
      // Corrupted persisted credential; drop it.
    }
    return null;
  }

  Future<void> startLogin() => _startAuthorization();

  Future<void> authorizePublishing() => _startAuthorization(purpose: 'publish');

  Future<void> _startAuthorization({String? purpose}) async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final returnUri = kIsWeb
          ? Uri.base
                .replace(
                  queryParameters: {
                    ...Uri.base.queryParameters,
                    'oauth': 'bandbbs',
                  },
                  fragment: '',
                )
                .toString()
          : _callbackUri;
      late final Uri uri;
      if (purpose == 'publish') {
        final session = await sessionIfNeeded();
        if (session == null) {
          throw StateError('BandBBS account is not signed in');
        }
        final response = await _send<Object?>(
          () async => _dio.post<Object?>(
            '/api/oauth/bandbbs/publish/start',
            data: {'return_uri': returnUri},
            options: Options(
              headers: {
                ...await _clientHeaders(),
                'Authorization': 'Bearer ${session.accessToken}',
              },
            ),
          ),
        );
        uri = Uri.parse(
          _objectMap(response.data)['authorization_url']!.toString(),
        );
      } else {
        uri = Uri.parse('$oronBoxServerBaseUrl/oauth2/bandbbs/start').replace(
          queryParameters: {
            'app_id': _clientAppId,
            'app_version': BuildInfoService.appVersion,
            'app_build': await BuildInfoService.resolveCommitHash(),
            'platform': _platformName(),
            'return_uri': returnUri,
          },
        );
      }
      _log.info(
        'BandBBS OAuth start method=GET endpoint=${_endpoint(uri)} '
        'platform=${_platformName()} appVersion=${BuildInfoService.appVersion}',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('failed to open BandBBS OAuth page');
      }
      state = state.copyWith(isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      rethrow;
    }
  }

  Future<bool> handleCallback(Uri uri) async {
    final nativeCallback =
        uri.scheme == 'oronbox' &&
        uri.host == 'oauth' &&
        uri.path == '/bandbbs';
    final webCallback = kIsWeb && uri.queryParameters['oauth'] == 'bandbbs';
    if (!nativeCallback && !webCallback) {
      return false;
    }
    final ticket = uri.queryParameters['ticket']?.trim() ?? '';
    if (ticket.isEmpty) {
      final error = uri.queryParameters['error']?.trim();
      state = state.copyWith(
        isBusy: false,
        lastError: error?.isNotEmpty == true ? error : 'missing ticket',
      );
      return true;
    }
    await exchangeTicket(ticket);
    return true;
  }

  Future<void> exchangeTicket(String ticket) async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/oauth/bandbbs/exchange',
          data: {'ticket': ticket},
          options: Options(headers: await _clientHeaders()),
        ),
      );
      final payload = _objectMap(response.data);
      final session = OronBoxSession.fromTokenResponse(payload);
      ++_credentialRevision;
      _sessionRefresh = null;
      _tokenRefresh = null;
      await _saveSession(session);
      // Login tickets carry the read-only BandBBS access token; publish
      // authorization tickets do not, so the existing read token survives.
      final bandbbs = payload['bandbbs'];
      BandBbsToken? token;
      if (bandbbs is Map) {
        token = BandBbsToken.fromTokenResponse(bandbbs.cast<String, Object?>());
        await _saveToken(token);
      }
      await _applyUser(_objectMap(payload['user']));
      state = state.copyWith(
        token: token,
        session: session,
        isBusy: false,
        clearLastError: true,
      );
      logDiagnostic(
        _log,
        Level.INFO,
        'BandBBS authorization completed',
        fields: {
          if (state.userId != null) 'userId': state.userId,
          if (state.username != null) 'username': state.username,
          'readTokenGranted': token != null,
        },
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      logDiagnostic(
        _log,
        Level.WARNING,
        'BandBBS authorization failed',
        fields: {if (state.userId != null) 'userId': state.userId},
        error: e,
      );
      rethrow;
    }
  }

  /// Read-only BandBBS access token, refreshing it through the server when
  /// expired (the refresh token never leaves the server).
  Future<BandBbsToken?> refreshIfNeeded() async {
    await _credentialRestore;
    var token = state.token;
    if (token == null) {
      await reloadCredentials();
      token = state.token;
    }
    if (token == null) return null;
    if (!token.isExpired) return token;
    final existing = _tokenRefresh;
    if (existing != null) return existing;
    final revision = _credentialRevision;
    late final Future<BandBbsToken?> refresh;
    refresh = _refreshBandBbsToken(token, revision).whenComplete(() {
      if (identical(_tokenRefresh, refresh)) _tokenRefresh = null;
    });
    _tokenRefresh = refresh;
    return refresh;
  }

  Future<BandBbsToken?> _refreshBandBbsToken(
    BandBbsToken token,
    int revision,
  ) async {
    final session = await sessionIfNeeded();
    if (session == null) {
      throw StateError('BandBBS account is not signed in');
    }
    final Response<Object?> response;
    try {
      response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/oauth/bandbbs/token/refresh',
          options: Options(
            headers: {
              ...await _clientHeaders(),
              'Authorization': 'Bearer ${session.accessToken}',
            },
          ),
        ),
      );
    } on DioException catch (error) {
      // A rejected refresh means the server-side credential is dead too;
      // wipe instead of looping on a token that will never work again.
      if (error.response?.statusCode != 401) rethrow;
      if (revision == _credentialRevision &&
          state.token?.accessToken == token.accessToken) {
        await _forgetExpiredCredentials();
      }
      throw const BandBbsSessionExpiredException();
    }
    final refreshed = BandBbsToken.fromTokenResponse(_objectMap(response.data));
    if (revision != _credentialRevision ||
        state.token?.accessToken != token.accessToken) {
      return state.token;
    }
    await _saveToken(refreshed);
    state = state.copyWith(token: refreshed, clearLastError: true);
    return refreshed;
  }

  /// OronBox session for ob-api endpoints, rotated when expired.
  @override
  Future<OronBoxSession?> sessionIfNeeded() async {
    await _credentialRestore;
    var session = state.session;
    // On desktop the OAuth callback may land on the daemon process, which
    // writes the session to SharedPrefs without notifying this (frontend)
    // Notifier. When our in-memory state is empty, try the persisted key
    // once more so the frontend picks up a login that happened in the
    // background.
    if (session == null) {
      final prefs = SharedPrefsService.instance;
      if (prefs.isInitialized) await prefs.reload();
      final raw = prefs.getString(_keySession);
      if (raw != null) {
        final restored = _restore(raw, OronBoxSession.fromJson);
        if (restored != null) {
          session = restored;
          state = state.copyWith(session: session);
        }
      }
    }
    if (session == null) return null;
    if (!session.isExpired) return session;
    final existing = _sessionRefresh;
    if (existing != null) return existing;
    final revision = _credentialRevision;
    late final Future<OronBoxSession?> refresh;
    refresh = _refreshSession(session, revision).whenComplete(() {
      if (identical(_sessionRefresh, refresh)) _sessionRefresh = null;
    });
    _sessionRefresh = refresh;
    return refresh;
  }

  Future<OronBoxSession> _refreshSession(
    OronBoxSession session,
    int revision,
  ) async {
    try {
      final response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/oauth/bandbbs/refresh',
          data: {'refresh_token': session.refreshToken},
          options: Options(headers: await _clientHeaders()),
        ),
      );
      final payload = _objectMap(response.data);
      final refreshed = OronBoxSession.fromTokenResponse(payload);
      if (revision != _credentialRevision ||
          state.session?.refreshToken != session.refreshToken) {
        return state.session ?? refreshed;
      }
      await _saveSession(refreshed);
      await _applyUser(_objectMap(payload['user']));
      state = state.copyWith(session: refreshed, clearLastError: true);
      return refreshed;
    } on DioException catch (error) {
      if (!_isInvalidRefreshToken(error)) rethrow;
      if (revision == _credentialRevision &&
          state.session?.refreshToken == session.refreshToken) {
        await _forgetExpiredCredentials();
      }
      throw const BandBbsSessionExpiredException();
    }
  }

  // Any 401 from the refresh endpoint is terminal for this credential; the
  // specific body code only exists for older server versions.
  bool _isInvalidRefreshToken(DioException error) =>
      error.response?.statusCode == 401;

  Future<void> _forgetExpiredCredentials() async {
    ++_credentialRevision;
    _sessionRefresh = null;
    _tokenRefresh = null;
    state = BandBbsAuthState.empty.copyWith(lastError: 'invalid_refresh_token');
    final prefs = SharedPrefsService.instance;
    await Future.wait([
      prefs.remove(_keyToken),
      prefs.remove(_keySession),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUsername),
      prefs.remove(_keyAvatarUrl),
    ]);
  }

  @override
  Future<void> expireSession() => _forgetExpiredCredentials();

  Future<void> signOut() async {
    ++_credentialRevision;
    _sessionRefresh = null;
    _tokenRefresh = null;
    final session = state.session;
    if (session != null) {
      try {
        await _dio.post<Object?>(
          '/api/session/revoke',
          options: Options(
            headers: {
              ...await _clientHeaders(),
              'Authorization': 'Bearer ${session.accessToken}',
            },
          ),
        );
      } catch (_) {
        _log.warning('OronBox session revoke failed');
      }
    }
    final prefs = SharedPrefsService.instance;
    await prefs.remove(_keyToken);
    await prefs.remove(_keySession);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyAvatarUrl);
    state = BandBbsAuthState.empty;
  }

  Future<Map<String, String>> _clientHeaders() async {
    return {
      'X-OronBox-App-Id': _clientAppId,
      'X-OronBox-Version': BuildInfoService.appVersion,
      'X-OronBox-Build': await BuildInfoService.resolveCommitHash(),
      'X-OronBox-Platform': _platformName(),
    };
  }

  Future<void> _saveToken(BandBbsToken token) async {
    await SharedPrefsService.instance.setString(
      _keyToken,
      jsonEncode(token.toJson()),
    );
  }

  Future<void> _saveSession(OronBoxSession session) async {
    await SharedPrefsService.instance.setString(
      _keySession,
      jsonEncode(session.toJson()),
    );
  }

  Future<void> _fetchCurrentUser(OronBoxSession session) async {
    try {
      final response = await _send<Object?>(
        () async => _dio.get<Object?>(
          '/api/me',
          options: Options(
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          ),
        ),
      );
      await _applyUser(_objectMap(response.data));
    } catch (_) {
      // Session restoration still succeeds; profile can be retried later.
    }
  }

  Future<void> _applyUser(Map<String, Object?> user) async {
    final prefs = SharedPrefsService.instance;
    final userId = user['bandbbs_user_id']?.toString() ?? '';
    final username = user['username']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString() ?? '';
    if (userId.isNotEmpty) await prefs.setString(_keyUserId, userId);
    if (username.isNotEmpty) await prefs.setString(_keyUsername, username);
    if (avatarUrl.isNotEmpty) await prefs.setString(_keyAvatarUrl, avatarUrl);
    state = state.copyWith(
      userId: userId.isNotEmpty ? userId : null,
      username: username.isNotEmpty ? username : null,
      avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
    );
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  Map<String, Object?> _objectMap(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return data.cast<String, Object?>();
    return const {};
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await request();
      stopwatch.stop();
      _logResponse(response, stopwatch.elapsedMilliseconds);
      return response;
    } on DioException catch (e) {
      stopwatch.stop();
      _logDioException(e, stopwatch.elapsedMilliseconds);
      rethrow;
    } catch (e, st) {
      _log.severe('BandBBS OAuth request failed before Dio response', e, st);
      rethrow;
    }
  }

  void _logResponse(Response<Object?> response, int durationMs) {
    final request = response.requestOptions;
    final summary = _responseSummary(request.uri.path, response.data);
    logDiagnostic(
      _log,
      Level.INFO,
      'BandBBS OAuth request completed',
      fields: {
        'method': request.method,
        'endpoint': safeHttpEndpoint(request.uri),
        if (response.statusCode case final status?) 'status': status,
        'durationMs': durationMs,
        if (httpRequestId(response) case final requestId?)
          'requestId': requestId,
        ...summary,
      },
    );
  }

  void _logDioException(DioException error, int durationMs) {
    final request = error.requestOptions;
    final response = error.response;
    final status = response?.statusCode;
    logDiagnostic(
      _log,
      status == null || status >= 500 ? Level.SEVERE : Level.WARNING,
      'BandBBS OAuth request failed',
      fields: {
        'method': request.method,
        'endpoint': safeHttpEndpoint(request.uri),
        if (status != null) 'status': status,
        'durationMs': durationMs,
        'errorType': error.type.name,
        if (httpRequestId(response) case final requestId?)
          'requestId': requestId,
        ...safeHttpErrorSummary(response?.data),
      },
    );
  }

  Map<String, Object?> _responseSummary(String path, Object? data) {
    final root = _objectMap(data);
    if (path == '/api/me') {
      final me = _objectMap(root['me']);
      return {
        if (me['user_id'] != null) 'userId': me['user_id'],
        if (me['username'] != null) 'username': me['username'],
      };
    }
    if (path == '/api/oauth/bandbbs/exchange' ||
        path == '/api/oauth/bandbbs/refresh' ||
        path == '/api/oauth/bandbbs/token/refresh') {
      return {
        if (root['token_type'] != null) 'tokenType': root['token_type'],
        if (root['expires_in'] != null) 'expiresIn': root['expires_in'],
        if (root['scope'] != null) 'scope': root['scope'],
        'accessTokenReceived':
            root['access_token']?.toString().isNotEmpty == true,
      };
    }
    return const {};
  }

  String _endpoint(Uri uri) => '${uri.scheme}://${uri.host}${uri.path}';
}

final bandBbsAuthProvider =
    NotifierProvider<BandBbsAuthNotifier, BandBbsAuthState>(
      BandBbsAuthNotifier.new,
    );
