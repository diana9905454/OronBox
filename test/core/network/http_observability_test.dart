import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';
import 'package:oronbox/src/features/resources/application/creator/oronbox_creator_api.dart';

void main() {
  test('HTTP diagnostics discard query credentials and summarize errors', () {
    final uri = Uri.parse(
      'https://ob-api.zxor.org/api/v1/oauth/callback?token=secret&state=private',
    );

    expect(safeHttpEndpoint(uri), 'https://ob-api.zxor.org/api/v1/oauth/callback');
    expect(
      safeHttpEndpoint(
        Uri.parse(
          'https://api-user.huami.com/registrations/user@example.com/tokens',
        ),
      ),
      'https://api-user.huami.com/registrations/:redacted/tokens',
    );
    expect(
      safeHttpErrorSummary({
        'error': 'creator_invalid',
        'message': 'image could not be decoded',
        'access_token': 'must-not-be-logged',
      }),
      {
        'serverCode': 'creator_invalid',
        'serverMessage': 'image could not be decoded',
      },
    );
    final textSummary = safeHttpErrorSummary(
      'upstream rejected access_token=secret-value for this request',
    );
    expect(textSummary['responseBody'], startsWith('<text:'));
    expect(textSummary.toString(), isNot(contains('secret-value')));
    expect(
      safeHttpErrorSummary({
        'error': {
          'code': 'creator_invalid',
          'message': 'token=secret-value could not be decoded',
        },
      }),
      {
        'serverCode': 'creator_invalid',
        'serverMessage': 'token=<redacted> could not be decoded',
      },
    );
  });

  test('creator API preserves a structured 400 response', () {
    final request = RequestOptions(
      path: '/api/v1/creator/uploads/upload-id',
      baseUrl: 'https://ob-api.zxor.org',
    );
    final exception = CreatorApiException.fromDio(
      DioException(
        requestOptions: request,
        response: Response<Object?>(
          requestOptions: request,
          statusCode: 400,
          headers: Headers.fromMap({
            'x-request-id': ['request-123'],
          }),
          data: const {
            'error': 'creator_invalid',
            'message': 'image could not be decoded',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
      stage: 'transfer',
    );

    expect(exception.code, 'creator_invalid');
    expect(exception.message, 'image could not be decoded');
    expect(exception.details, {
      'stage': 'transfer',
      'endpoint': 'https://ob-api.zxor.org/api/v1/creator/uploads/upload-id',
      'status': 400,
      'errorType': 'badResponse',
      'requestId': 'request-123',
    });
    expect(exception.toString(), 'image could not be decoded');
  });
}
