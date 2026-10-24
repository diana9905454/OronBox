import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:oronbox/src/core/services/oauth_credential_store.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_session_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
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
    this.rotationId = '',
    this.user = const {},
    this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String rotationId;
  final Map<String, Object?> user;
  final DateTime? refreshExpiresAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(
    expiresAt.subtract(const Duration(minutes: 2)),
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'rotation_id': rotationId,
    'user': user,
    if (refreshExpiresAt != null)
      'refresh_expires_at': refreshExpiresAt!.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
  };

  static OronBoxSession fromTokenResponse(Map<String, Object?> json) {
    final expiresIn = BandBbsToken._asInt(json['expires_in']);
    final serverExpiry = DateTime.tryParse(
      json['expires_at']?.toString() ?? '',
    );
    final accessToken = json['access_token']?.toString().trim() ?? '';
    final refreshToken = json['refresh_token']?.toString().trim() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty || expiresIn <= 0) {
      throw const FormatException('Invalid OronBox session response');
    }
    return OronBoxSession(
      rotationId: json['rotation_id']?.toString() ?? const Uuid().v4(),
      user: json['user'] is Map
          ? (json['user'] as Map).cast<String, Object?>()
          : const {},
      refreshExpiresAt: DateTime.tryParse(
        json['refresh_expires_at']?.toString() ?? '',
      ),
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt:
          serverExpiry?.toUtc() ??
          DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
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
      rotationId: json['rotation_id']?.toString() ?? const Uuid().v4(),
      user: json['user'] is Map
          ? (json['user'] as Map).cast<String, Object?>()
          : const {},
      refreshExpiresAt: DateTime.tryParse(
        json['refresh_expires_at']?.toString() ?? '',
      ),
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

abstract interface class OronBoxSessionAccess {
  Future<OronBoxSession?> sessionIfNeeded({bool forceRefresh = false});

  Future<void> expireSession();
}

class OronBoxAuthRequiredException implements CodedError {
  const OronBoxAuthRequiredException();

  @override
  String get code => 'auth_required';

  @override
  String get message => 'BandBBS account is not signed in';

  @override
  Object? get details => null;

  @override
  String toString() => message;
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

  BandBbsAuthNotifier({Dio? dio})
    : _dio =
          dio ??
          createAppHttpTransport(
            options: BaseOptions(
              baseUrl: oronBoxServerBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
  final Dio _dio;

  @override
  BandBbsAuthState build() {
    final prefs = SharedPrefsService.instance;
    final initial = BandBbsAuthState.empty.copyWith(
      userId: prefs.getString(_keyUserId),
      username: prefs.getString(_keyUsername),
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
    scheduleMicrotask(() {
      if (!ref.mounted) return;
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
    });
    ref.onDispose(() => unawaited(_hostEvents?.cancel()));
    _credentialRestore = Future.microtask(_restoreCredentials);
    return initial;
  }

  Future<void> _restoreCredentials() async {
    final revision = _credentialRevision;
    try {
      final credentials = await OAuthCredentialStore.locked(
        () async => (
          await OAuthCredentialStore.read(_keyToken),
          await OAuthCredentialStore.read(_keySession),
        ),
      );
      final tokenRaw = credentials.$1;
      final sessionRaw = credentials.$2;
      if (!ref.mounted || revision != _credentialRevision) return;
      final token = _restore(tokenRaw, BandBbsToken.fromJson);
      final session = _restore(sessionRaw, OronBoxSession.fromJson);
      state = state.copyWith(token: token, session: session);
      if (session != null && session.user.isNotEmpty) {
        await _applyUser(session.user);
      }
      if (session != null && state.username == null) {
        unawaited(
          Future<void>(() async {
            try {
              final validSession = await sessionIfNeeded();
              if (validSession != null) await _fetchCurrentUser(validSession);
            } catch (error) {
              _log.warning('Unable to refresh restored session', error);
            }
          }),
        );
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
    final revision = _credentialRevision;
    final prefs = SharedPrefsService.instance;
    if (prefs.isInitialized) await prefs.reload();
    final credentials = await OAuthCredentialStore.locked(
      () async => (
        await OAuthCredentialStore.read(_keyToken),
        await OAuthCredentialStore.read(_keySession),
      ),
    );
    final tokenRaw = credentials.$1;
    final sessionRaw = credentials.$2;
    if (!ref.mounted || revision != _credentialRevision) return;
    if (sessionRaw == null && !clearWhenMissing) return;
    final session = _restore(sessionRaw, OronBoxSession.fromJson);
    final token = _restore(tokenRaw, BandBbsToken.fromJson);
    final storedUser = session?.user;
    final userId = storedUser?.isNotEmpty == true
        ? storedUser!['bandbbs_user_id']?.toString()
        : (prefs.isInitialized ? prefs.getString(_keyUserId) : null);
    if (state.session != null &&
        (session == null ||
            (userId != null &&
                state.userId != null &&
                userId != state.userId))) {
      ++_credentialRevision;
    }
    state = state.copyWith(
      token: token,
      clearToken: token == null,
      session: session,
      clearSession: session == null,
      userId: userId,
      clearUserId: session == null,
      clearUsername: session == null,
      clearAvatarUrl: session == null,
    );
    if (storedUser?.isNotEmpty == true) await _applyUser(storedUser!);
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
        final response = await OronBoxSessionClient(this).send<Object?>(
          (authorization) => _dio.post<Object?>(
            '/api/v1/oauth/bandbbs/publish/start',
            data: {'return_uri': returnUri},
            options: authorization,
          ),
        );
        uri = Uri.parse(
          _objectMap(response.data)['authorization_url']!.toString(),
        );
      } else {
        final response = await _send<Object?>(
          () async => _dio.post<Object?>(
            '/api/v1/oauth/bandbbs/start',
            data: {'return_uri': returnUri},
            options: Options(headers: await _clientHeaders()),
          ),
        );
        uri = Uri.parse(
          _objectMap(response.data)['authorization_url']!.toString(),
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

  Future<void> exchangeTicket(String ticket) =>
      OAuthCredentialStore.locked(() => _exchangeTicket(ticket));

  Future<void> _exchangeTicket(String ticket) async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/v1/oauth/bandbbs/exchange',
          data: {'ticket': ticket},
          options: Options(headers: await _clientHeaders()),
        ),
      );
      final payload = _objectMap(response.data);
      final session = OronBoxSession.fromTokenResponse(payload);
      ++_credentialRevision;
      _sessionRefresh = null;
      _tokenRefresh = null;
      // Login tickets carry the read-only BandBBS access token; publish
      // authorization tickets do not, so the existing read token survives.
      final bandbbs = payload['bandbbs'];
      BandBbsToken? token;
      if (bandbbs is Map) {
        token = BandBbsToken.fromTokenResponse(bandbbs.cast<String, Object?>());
      }
      await OAuthCredentialStore.writePair(
        jsonEncode(session.toJson()),
        token != null
            ? jsonEncode(token.toJson())
            : await OAuthCredentialStore.read(_keyToken),
      );
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
  Future<BandBbsToken?> refreshIfNeeded({bool forceRefresh = false}) async {
    await _credentialRestore;
    await reloadCredentials(clearWhenMissing: true);
    var token = state.token;
    if (token == null) {
      await reloadCredentials();
      token = state.token;
    }
    if (token != null && !token.isExpired && !forceRefresh) return token;
    final session = await sessionIfNeeded();
    if (session == null) return null;
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
    BandBbsToken? token,
    int revision,
  ) async {
    try {
      final response = await OronBoxSessionClient(this).send<Object?>(
        (authorization) async => _dio.post<Object?>(
          '/api/v1/oauth/bandbbs/token/refresh',
          data: {'rejected_access_token': token?.accessToken ?? ''},
          options: authorization,
        ),
      );
      final refreshed = BandBbsToken.fromTokenResponse(
        _objectMap(response.data),
      );
      return await OAuthCredentialStore.locked(() async {
        if (revision != _credentialRevision) return state.token;
        final current = _restore(
          await OAuthCredentialStore.read(_keySession),
          OronBoxSession.fromJson,
        );
        if (current == null ||
            current.refreshToken != state.session?.refreshToken) {
          return state.token;
        }
        await _saveToken(refreshed);
        state = state.copyWith(token: refreshed, clearLastError: true);
        return refreshed;
      });
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map &&
          (data['error'] ?? data['code']) ==
              'bandbbs_reauthorization_required') {
        await OAuthCredentialStore.locked(() async {
          if (revision != _credentialRevision) return;
          final current = _restore(
            await OAuthCredentialStore.read(_keySession),
            OronBoxSession.fromJson,
          );
          if (current?.refreshToken != state.session?.refreshToken) return;
          await OAuthCredentialStore.remove(_keyToken);
          state = state.copyWith(
            clearToken: true,
            lastError: 'bandbbs_reauthorization_required',
          );
        });
      }
      rethrow;
    }
  }

  /// OronBox session for ob-api endpoints, rotated when expired.
  @override
  Future<OronBoxSession?> sessionIfNeeded({bool forceRefresh = false}) async {
    await _credentialRestore;
    await reloadCredentials(clearWhenMissing: true);
    final session = state.session;
    if (session == null) return null;
    if (!session.isExpired && !forceRefresh) return session;
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

  Future<OronBoxSession?> _refreshSession(
    OronBoxSession session,
    int revision,
  ) => OAuthCredentialStore.locked(() async {
    final current = _restore(
      await OAuthCredentialStore.read(_keySession),
      OronBoxSession.fromJson,
    );
    if (revision != _credentialRevision) return state.session;
    if (current == null) {
      state = BandBbsAuthState.empty;
      return null;
    }
    if (current.refreshToken != session.refreshToken) {
      final readToken = _restore(
        await OAuthCredentialStore.read(_keyToken),
        BandBbsToken.fromJson,
      );
      state = state.copyWith(
        session: current,
        token: readToken,
        clearToken: readToken == null,
      );
      if (current.user.isNotEmpty) await _applyUser(current.user);
      return current;
    }
    final rotationId = current.rotationId.isEmpty
        ? const Uuid().v4()
        : current.rotationId;
    // Save the id before sending so a lost response can retry the same rotation.
    await OAuthCredentialStore.write(
      _keySession,
      jsonEncode({...current.toJson(), 'rotation_id': rotationId}),
    );
    try {
      final response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/v1/oauth/bandbbs/refresh',
          data: {
            'refresh_token': current.refreshToken,
            'rotation_id': rotationId,
          },
          options: Options(headers: await _clientHeaders()),
        ),
      );
      final payload = _objectMap(response.data);
      final refreshed = OronBoxSession.fromTokenResponse(payload);
      if (revision != _credentialRevision) return state.session;
      await _saveSession(refreshed);
      await _applyUser(_objectMap(payload['user']));
      state = state.copyWith(session: refreshed, clearLastError: true);
      return refreshed;
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['error'] ?? data['code'] : null;
      if (error.response?.statusCode != 401 ||
          code != 'invalid_refresh_token') {
        rethrow;
      }
      if (revision != _credentialRevision) return state.session;
      await _forgetExpiredCredentials();
      throw const BandBbsSessionExpiredException();
    }
  });

  Future<void> _forgetExpiredCredentials({bool expired = true}) async {
    ++_credentialRevision;
    _sessionRefresh = null;
    _tokenRefresh = null;
    state = expired
        ? BandBbsAuthState.empty.copyWith(lastError: 'invalid_refresh_token')
        : BandBbsAuthState.empty;
    final prefs = SharedPrefsService.instance;
    await Future.wait([
      OAuthCredentialStore.clear(),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUsername),
      prefs.remove(_keyAvatarUrl),
    ]);
    // The frontend and daemon may each cache account state. Ask the host to
    // reread the now-cleared record; never instruct it to infer RT expiry.
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const OronBoxCommand(method: 'account.credentials.reload'))
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              _log.warning('Unable to notify host of credential change', error);
            },
          ),
    );
  }

  @override
  Future<void> expireSession() =>
      OAuthCredentialStore.locked(_forgetExpiredCredentials);

  Future<void> signOut() => OAuthCredentialStore.locked(() async {
    final session = _restore(
      await OAuthCredentialStore.read(_keySession),
      OronBoxSession.fromJson,
    );
    if (session != null) {
      // Keep the login and report failure if the server cannot confirm logout.
      // An expired AT can revoke; the RT also covers a lost rotation response.
      await _dio.post<Object?>(
        '/api/v1/session/revoke',
        data: {'refresh_token': session.refreshToken},
        options: Options(
          headers: {
            ...await _clientHeaders(),
            'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );
    }
    await _forgetExpiredCredentials(expired: false);
    state = BandBbsAuthState.empty;
  });

  Future<Map<String, String>> _clientHeaders() async {
    return {
      'X-OronBox-App-Id': _clientAppId,
      'X-OronBox-Version': BuildInfoService.appVersion,
      'X-OronBox-Build': await BuildInfoService.resolveCommitHash(),
      'X-OronBox-Platform': _platformName(),
    };
  }

  Future<void> _saveToken(BandBbsToken token) async {
    await OAuthCredentialStore.write(_keyToken, jsonEncode(token.toJson()));
  }

  Future<void> _saveSession(OronBoxSession session) async {
    await OAuthCredentialStore.write(_keySession, jsonEncode(session.toJson()));
  }

  Future<void> _fetchCurrentUser(OronBoxSession session) async {
    try {
      final response = await _send<Object?>(
        () async => _dio.get<Object?>(
          '/api/v1/me',
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
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyAvatarUrl, avatarUrl);
    state = state.copyWith(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
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
    if (path == '/api/v1/me') {
      final me = _objectMap(root['me']);
      return {
        if (me['user_id'] != null) 'userId': me['user_id'],
        if (me['username'] != null) 'username': me['username'],
      };
    }
    if (path == '/api/v1/oauth/bandbbs/exchange' ||
        path == '/api/v1/oauth/bandbbs/refresh' ||
        path == '/api/v1/oauth/bandbbs/token/refresh') {
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

/// Build signature/clock failures must never discard account credentials.
bool isSessionAuthenticationFailure(DioException error) {
  if (error.response?.statusCode != 401) return false;
  final data = error.response?.data;
  final code = data is Map ? data['error'] ?? data['code'] : null;
  return code == 'unauthorized';
}
