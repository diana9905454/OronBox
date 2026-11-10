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
      if (!isSessionAuthenticationFailure(error)) rethrow;

      // Access token was rejected (401). Try to refresh it with the refresh token.
      final current = await _sessions.sessionIfNeeded();
      final refreshed =
          current != null && current.accessToken != session.accessToken
          ? current
          : await _sessions.sessionIfNeeded(forceRefresh: true);
      if (refreshed == null) throw const OronBoxAuthRequiredException();
      return operation(
        Options(headers: {'Authorization': 'Bearer ${refreshed.accessToken}'}),
      );
    }
  }
}
