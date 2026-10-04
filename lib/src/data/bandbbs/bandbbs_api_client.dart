import 'package:dio/dio.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

class BandBbsApiClient {
  BandBbsApiClient({
    required this.dio,
    required this.auth,
    this.onSessionExpired,
  });

  final Dio dio;
  final BandBbsAuthNotifier auth;

  /// Runs after a 401 wiped the local credentials; lets the wiring propagate
  /// the expiry to the daemon so every login gate observes it.
  final Future<void> Function()? onSessionExpired;

  static const _baseUrl = 'https://www.bandbbs.cn';
  static const _developerApiBaseUrl = 'https://api.bandbbs.cn';

  Future<List<Map<String, dynamic>>> getMyResources({
    required String creatorId,
    int page = 1,
  }) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resources/',
        queryParameters: {'creator_id': creatorId, 'page': page},
        options: await _authOptions(),
      ),
    );
    return ((_objectMap(response.data)['resources'] as List?) ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> getResource(String resourceId) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resources/$resourceId',
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getResources({
    required int page,
    int? prefixId,
    String? type,
    String? order,
    String? direction,
  }) async {
    final queryParameters = {
      'page': page,
      if (prefixId != null) 'prefix_id': prefixId,
      if (type?.isNotEmpty == true) 'type': type,
      if (order?.isNotEmpty == true) 'order': order,
      if (direction?.isNotEmpty == true) 'direction': direction,
    };
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resources/',
        queryParameters: queryParameters,
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> searchResources({
    required String keywords,
    required int page,
    String? order,
    List<int>? categoryIds,
  }) async {
    final queryParameters = {
      'keywords': keywords,
      'page': page,
      if (order?.isNotEmpty == true) 'search_order': order,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'categories[]': categoryIds,
    };
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-search/',
        queryParameters: queryParameters,
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getCategoryResources({
    required int categoryId,
    required int page,
  }) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-categories/$categoryId/resources',
        queryParameters: {'page': page},
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getFlattenedCategories() async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-categories/flattened',
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<BandBbsResourceLicense> checkLicense(String resourceId) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-check/$resourceId',
        options: await _authOptions(),
      ),
    );
    final data = _objectMap(response.data);
    return BandBbsResourceLicense(
      valid: data['valid'] == true,
      license: data['license']?.toString() ?? '',
      iv: data['iv']?.toString() ?? '',
    );
  }

  Future<Response<List<int>>> downloadFile(
    String url, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    return _send<List<int>>(
      () async => dio.get<List<int>>(
        url,
        options: (await _authOptions()).copyWith(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<Object?>> headFile(String url) async {
    return _send<Object?>(
      () async => dio.head<Object?>(url, options: await _authOptions()),
    );
  }

  Future<BandBbsDecryptInfo> getDecryptInfo({
    required String encryptedFileHash,
    required String verifyLicense,
    required String licenseIv,
  }) async {
    final requestBody = {
      'encrypted_file_hash': encryptedFileHash,
      'verify_license': verifyLicense,
      'license_iv': licenseIv,
    };
    final response = await _send<Object?>(
      () async => dio.post<Object?>(
        '$_developerApiBaseUrl/developerplatform/api/v1/public/files/decrypt',
        data: requestBody,
      ),
      expireSessionOnUnauthorized: false,
    );
    final root = _objectMap(response.data);
    if (root['success'] != true) {
      throw StateError(root['message']?.toString() ?? 'BandBBS decrypt failed');
    }
    final data = _objectMap(root['data']);
    return BandBbsDecryptInfo.fromJson(data);
  }

  Future<Options> _authOptions() async {
    final token = await auth.refreshIfNeeded();
    if (token == null) {
      throw const OronBoxAuthRequiredException();
    }
    return Options(headers: {'Authorization': 'Bearer ${token.accessToken}'});
  }

  Map<String, dynamic> _objectMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw FormatException('BandBBS API returned ${value.runtimeType}');
  }

  Future<Response<T>> _send<T>(
    Future<Response<T>> Function() request, {
    bool expireSessionOnUnauthorized = true,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401 || !expireSessionOnUnauthorized) {
        rethrow;
      }
      // Access token was rejected (401). Try to refresh the token first!
      try {
        final refreshed = await auth.refreshIfNeeded(forceRefresh: true);
        if (refreshed != null) {
          try {
            return await request();
          } on DioException catch (retryError) {
            if (retryError.response?.statusCode != 401) {
              rethrow;
            }
          }
        }
      } catch (refreshError) {
        try {
          await auth.expireSession();
        } catch (_) {}
        try {
          await onSessionExpired?.call();
        } catch (_) {}
        rethrow;
      }
      // The token was rejected and refresh failed: the credential is dead everywhere,
      // wipe it and propagate instead of leaving UI gated on a stale login.
      try {
        await auth.expireSession();
      } catch (_) {}
      try {
        await onSessionExpired?.call();
      } catch (_) {}
      throw const BandBbsSessionExpiredException();
    }
  }
}

class BandBbsResourceLicense {
  const BandBbsResourceLicense({
    required this.valid,
    required this.license,
    required this.iv,
  });

  final bool valid;
  final String license;
  final String iv;
}

class BandBbsDecryptInfo {
  const BandBbsDecryptInfo({
    required this.fileName,
    required this.encryptedFileHash,
    required this.decryptedFileHash,
    required this.decryptToken,
    required this.decryptIv,
    required this.authTag,
  });

  final String fileName;
  final String encryptedFileHash;
  final String decryptedFileHash;
  final String decryptToken;
  final String decryptIv;
  final String authTag;

  factory BandBbsDecryptInfo.fromJson(Map<String, dynamic> json) {
    final fileInfo = _objectMap(json['file_info']);
    final decryptedInfo = _objectMap(json['decrypted_info']);
    return BandBbsDecryptInfo(
      fileName: fileInfo['file_name']?.toString() ?? '',
      encryptedFileHash: fileInfo['encrypted_file_hash']?.toString() ?? '',
      decryptedFileHash: fileInfo['decrypted_file_hash']?.toString() ?? '',
      decryptToken: decryptedInfo['decrypt_token']?.toString() ?? '',
      decryptIv: decryptedInfo['decrypt_iv']?.toString() ?? '',
      authTag: decryptedInfo['auth_tag']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _objectMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }
}
