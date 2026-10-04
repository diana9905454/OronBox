import 'package:dio/dio.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

export 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart'
    show OronBoxAuthRequiredException;

class OronBoxSessionClient {
  const OronBoxSessionClient(this._sessions);

  final OronBoxSessionAccess _sessions;

  Future<Response<T>> send<T>(
    Future<Response<T>> Function(Options authorization) operation,
  ) async {
    final session = await _sessions.sessionIfNeeded();
    if (session == null) throw const OronBoxAuthRequiredException();
    try {
      return await operation(
        Options(headers: {'Authorization': 'Bearer ${session.accessToken}'}),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;

      // Access token was rejected (401). Try to refresh it with the refresh token.
      final refreshed = await _sessions.sessionIfNeeded(forceRefresh: true);
      if (refreshed != null) {
        try {
          return await operation(
            Options(
              headers: {'Authorization': 'Bearer ${refreshed.accessToken}'},
            ),
          );
        } on DioException catch (retryError) {
          if (retryError.response?.statusCode != 401) rethrow;
        }
      }

      // The refresh token itself is expired/invalid; now expire the session.
      try {
        await _sessions.expireSession();
      } catch (_) {
        // The authenticated request already proved the session invalid.
        // Failure to notify the host must not hide the user-facing expiry.
      }
      throw const BandBbsSessionExpiredException();
    }
  }
}
