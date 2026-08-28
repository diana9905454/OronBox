import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

/// Error codes understood by the OronBox client.
///
/// Keep this list in sync with the server's `errorBody` codes. It is also
/// used when a code is embedded in a plain exception string.
const oronBoxKnownErrorCodes = <String>{
  'admin_coin_failed',
  'already_exists',
  'announcement_read_failed',
  'announcements_read_failed',
  'attributes_failed',
  'auth_required',
  'bandbbs_grant_invalid',
  'bandbbs_refresh_failed',
  'bandbbs_scope_forbidden',
  'banned',
  'blob_failed',
  'blob_not_found',
  'blog_failed',
  'cancelled',
  'coin_account_failed',
  'coin_account_too_new',
  'coin_balance_insufficient',
  'coin_checkin_failed',
  'coin_own_resource',
  'coin_resource_limit',
  'coin_status_failed',
  'coin_vote_failed',
  'coin_voting_frozen',
  'collaborations_failed',
  'collection_failed',
  'collection_not_found',
  'collection_review_failed',
  'collections_failed',
  'comment_blocked',
  'comment_create_failed',
  'comment_delete_failed',
  'comment_not_found',
  'comment_rate_limited',
  'comment_target_not_found',
  'comments_read_failed',
  'conflict',
  'connection_error',
  'creator_coin_stats_failed',
  'creator_failed',
  'creator_frozen',
  'creator_invalid',
  'daemon_disconnected',
  'database_failed',
  'devices_failed',
  'document_not_found',
  'document_read_failed',
  'feedback_closed',
  'feedback_create_failed',
  'feedback_list_failed',
  'feedback_not_found',
  'feedback_read_failed',
  'feedback_reply_failed',
  'file_too_large',
  'forbidden',
  'github_not_configured',
  'github_oauth_failed',
  'grants_failed',
  'home_failed',
  'host_unavailable',
  'import_failed',
  'internal',
  'invalid_app',
  'invalid_argument',
  'invalid_before',
  'invalid_blob',
  'invalid_comment',
  'invalid_flow',
  'invalid_kind',
  'invalid_operation',
  'invalid_refresh_token',
  'invalid_reply',
  'invalid_request',
  'invalid_response',
  'invalid_target',
  'invalid_ticket',
  'invalid_upload',
  'invalid_url',
  'list_failed',
  'message_read_failed',
  'messages_clear_failed',
  'messages_read_failed',
  'moderation_settings_failed',
  'moderation_unavailable',
  'network_error',
  'not_found',
  'not_installed',
  'oauth_start_failed',
  'payload_too_large',
  'plugin_delete_failed',
  'plugin_hook_failed',
  'plugin_invalid',
  'plugin_error',
  'plugin_not_found',
  'plugin_not_owned',
  'plugin_save_failed',
  'plugins_failed',
  'post_not_found',
  'publish_failed',
  'quota_exceeded',
  'r2_unavailable',
  'rate_limited',
  'release_not_found',
  'release_read_failed',
  'resource_not_found',
  'service_unavailable',
  'session_expired',
  'xiaomi_account_session_expired',
  'target_lookup_failed',
  'token_create_failed',
  'token_decrypt_failed',
  'unauthenticated',
  'unauthorized',
  'upload_failed',
  'usage',
  'unsupported',
  'validation',
};

String localizedErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = _flattenError(error);
  final normalized = raw.toLowerCase();
  final code = _errorCode(error, normalized);
  final backendMessage = _backendMessage(error);
  if (backendMessage != null) return backendMessage;

  switch (code) {
    case 'invalid_refresh_token':
    case 'session_expired':
    case 'http_401':
      return l10n.errorOronBoxSessionExpired;
    case 'xiaomi_account_session_expired':
      return l10n.errorXiaomiAccountSessionExpired;
    case 'auth_required':
    case 'unauthenticated':
    case 'bandbbs_grant_invalid':
      return l10n.settingsBandBbsAccountRequired;
    case 'forbidden':
    case 'banned':
    case 'creator_frozen':
    case 'bandbbs_scope_forbidden':
    case 'plugin_not_owned':
    case 'http_403':
      return l10n.errorPermissionDenied;
    case 'not_found':
    case 'resource_not_found':
    case 'collection_not_found':
    case 'comment_not_found':
    case 'feedback_not_found':
    case 'document_not_found':
    case 'blob_not_found':
    case 'post_not_found':
    case 'plugin_not_found':
    case 'release_not_found':
    case 'comment_target_not_found':
    case 'http_404':
      return l10n.errorContentNotFound;
    case 'conflict':
    case 'already_exists':
    case 'feedback_closed':
    case 'http_409':
      return l10n.errorRequestConflict;
    case 'comment_blocked':
      return l10n.commentBlocked;
    case 'coin_balance_insufficient':
      return l10n.errorCoinBalanceInsufficient;
    case 'coin_resource_limit':
      return l10n.errorCoinResourceLimit;
    case 'coin_own_resource':
      return l10n.errorCoinOwnResource;
    case 'coin_voting_frozen':
      return l10n.errorCoinVotingFrozen;
    case 'coin_account_too_new':
      return l10n.errorCoinAccountTooNew;
    case 'coin_vote_failed':
    case 'coin_checkin_failed':
    case 'admin_coin_failed':
    case 'creator_coin_stats_failed':
      return l10n.errorCoinOperationFailed;
    case 'coin_status_failed':
      return l10n.errorCoinStatusUnavailable;
    case 'rate_limited':
    case 'http_429':
      return l10n.errorRateLimited;
    case 'comment_rate_limited':
      return l10n.commentRateLimited;
    case 'quota_exceeded':
      return l10n.errorDownloadQuotaExceeded;
    case 'payload_too_large':
    case 'file_too_large':
    case 'http_413':
      return l10n.errorFileTooLarge;
    case 'invalid_argument':
    case 'invalid_request':
    case 'creator_invalid':
    case 'invalid_before':
    case 'invalid_blob':
    case 'invalid_comment':
    case 'invalid_flow':
    case 'invalid_kind':
    case 'invalid_reply':
    case 'invalid_target':
    case 'invalid_ticket':
    case 'invalid_upload':
    case 'invalid_response':
    case 'invalid_app':
    case 'invalid_operation':
    case 'invalid_url':
    case 'not_installed':
    case 'unsupported':
    case 'validation':
    case 'usage':
    case 'http_400':
    case 'http_422':
      return l10n.errorInvalidRequest;
    case 'network_error':
    case 'connection_error':
    case 'host_unavailable':
    case 'daemon_disconnected':
      return l10n.errorNetworkUnavailable;
    case 'service_unavailable':
    case 'coin_account_failed':
    case 'database_failed':
    case 'home_failed':
    case 'blog_failed':
    case 'list_failed':
    case 'attributes_failed':
    case 'collections_failed':
    case 'collection_failed':
    case 'devices_failed':
    case 'announcements_read_failed':
    case 'announcement_read_failed':
    case 'document_read_failed':
    case 'plugins_failed':
    case 'release_read_failed':
    case 'grants_failed':
    case 'r2_unavailable':
    case 'http_500':
    case 'http_502':
    case 'http_503':
    case 'http_504':
      return l10n.errorServiceUnavailable;
    case 'cancelled':
      return l10n.errorOperationCancelled;
    case 'github_not_configured':
      return l10n.errorGitHubNotConfigured;
    case 'moderation_unavailable':
      return l10n.commentModerationUnavailable;
    case 'bandbbs_refresh_failed':
    case 'blob_failed':
    case 'collaborations_failed':
    case 'collection_review_failed':
    case 'comment_create_failed':
    case 'comment_delete_failed':
    case 'comments_read_failed':
    case 'feedback_create_failed':
    case 'feedback_list_failed':
    case 'feedback_read_failed':
    case 'feedback_reply_failed':
    case 'github_oauth_failed':
    case 'messages_clear_failed':
    case 'message_read_failed':
    case 'messages_read_failed':
    case 'oauth_start_failed':
    case 'plugin_delete_failed':
    case 'plugin_hook_failed':
    case 'plugin_invalid':
    case 'plugin_error':
    case 'plugin_save_failed':
    case 'target_lookup_failed':
    case 'token_create_failed':
    case 'token_decrypt_failed':
    case 'upload_failed':
    case 'creator_failed':
    case 'import_failed':
    case 'publish_failed':
    case 'internal':
      return l10n.errorOperationFailed;
  }

  if (code == 'unauthorized' &&
      (normalized.contains('expired') ||
          normalized.contains('invalid') ||
          normalized.contains('token'))) {
    return l10n.errorOronBoxSessionExpired;
  }

  // Raw Dio calls (resource catalogs, home feed, update checks, and similar
  // APIs) do not all have a feature-specific exception wrapper. Keep their
  // transport and HTTP failures on the same localized path as command errors.
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code']?.toString().trim().isNotEmpty == true) {
      // A coded response without message or details has nothing useful to
      // expose, so retain a localized fallback.
      return l10n.errorUnknown;
    }
    final status = error.response?.statusCode;
    if (status != null) {
      if (status >= 500) return l10n.errorServiceUnavailable;
      if (status >= 400) return l10n.errorInvalidRequest;
    }
    return switch (error.type) {
      DioExceptionType.cancel => l10n.errorOperationCancelled,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => l10n.errorOperationTimeout,
      DioExceptionType.connectionError => l10n.errorNetworkUnavailable,
      DioExceptionType.badCertificate =>
        l10n.errorCertificateVerificationFailed,
      _ => l10n.errorUnknown,
    };
  }

  // A coded error reaches this branch only when both message and details are
  // empty. Non-empty backend diagnostics return before code localization.
  if (error is CodedError) {
    return l10n.errorUnknown;
  }

  if (raw == DeviceManager.errorBluetoothUnavailable ||
      normalized.contains('bluetooth is not available') ||
      normalized.contains('bluetooth not available') ||
      normalized.contains('availabilitystate.unsupported')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('web serial api is not available')) {
    return l10n.errorWebSerialUnavailable;
  }

  if (normalized.contains('no rfcomm channel available')) {
    return l10n.errorUnknownWithDetail(_trimPlatformNoise(raw));
  }

  if (normalized.contains('certificate_verify_failed') ||
      normalized.contains('self signed certificate') ||
      normalized.contains('handshakeexception') ||
      normalized.contains('certificate verify failed')) {
    return l10n.errorCertificateVerificationFailed;
  }

  if (normalized.contains('ble connect failed: timeout') ||
      normalized.contains('ble connect failed: service discovery timed out') ||
      normalized.contains('ble notification subscription timed out')) {
    // All connection-failure causes (timeout or refused) share one message:
    // permissions, radio off, device occupied, or wrong device mode.
    return l10n.errorBluetoothConnectFailed;
  }

  // The BLE and SPP drivers normalize native failures into these stable
  // shapes at the Dart boundary; match the shape, not native wording.
  if (normalized.contains('ble connect failed') ||
      normalized.contains('spp connect failed') ||
      normalized.contains('ble device was not discovered') ||
      normalized.contains('unknown deviceid')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('ble write timed out')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('bluetooth permission is required')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('timeout') ||
      normalized.contains('timed out') ||
      normalized.contains('future not completed') ||
      normalized.contains('操作超时')) {
    // Preserve the connection stage carried by the error instead of reducing
    // every failure to the same unactionable timeout message.
    final detail = _trimPlatformNoise(raw);
    return detail.isEmpty
        ? l10n.errorOperationTimeout
        : l10n.errorUnknownWithDetail(detail);
  }

  if (normalized.contains('device not ready')) {
    return l10n.errorDeviceNotReady;
  }

  if (normalized.contains('unsupported or unrecognized file type') ||
      normalized.contains('unsupported file type') ||
      normalized.contains('unsupported file')) {
    return l10n.errorUnsupportedFileType;
  }

  if (normalized.contains('required ble characteristics not found') ||
      normalized.contains('characteristic') &&
          normalized.contains('not found')) {
    final detail = _trimPlatformNoise(raw);
    return normalized.contains('discovered:')
        ? l10n.errorUnknownWithDetail(detail)
        : l10n.errorBleCharacteristicsMissing;
  }

  if (normalized.contains('send_failed') ||
      normalized.contains('disconnected') ||
      normalized.contains('not connected') ||
      normalized.contains('传输端点尚未连接') ||
      normalized.contains('socket is not connected')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('connect_failed') ||
      normalized.contains('connect failed on channel') ||
      normalized.contains('universalble.connect failed') ||
      normalized.contains('连接被拒绝') ||
      normalized.contains('设备或资源忙') ||
      normalized.contains('无法分配内存')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('username or password is incorrect')) {
    return l10n.errorAccountPasswordIncorrect;
  }

  if (normalized.contains('bandbbs account is not signed in')) {
    return l10n.settingsBandBbsAccountRequired;
  }

  if (normalized.contains('huami account is not signed in')) {
    return l10n.settingsHuamiAccountRequired;
  }

  if (normalized.contains('xiaomi_account_session_expired') ||
      normalized.contains('xiaomi account session expired')) {
    return l10n.errorXiaomiAccountSessionExpired;
  }

  if (normalized.contains('2fa') ||
      normalized.contains('two-factor') ||
      normalized.contains('did not return account cookies')) {
    return l10n.errorAccountTwoFactorIncomplete;
  }

  if (raw.trim().isEmpty) {
    return l10n.error;
  }

  return l10n.errorUnknownWithDetail(_trimPlatformNoise(raw));
}

String _errorCode(Object? error, String normalized) {
  if (error is CodedError) return error.code.trim().toLowerCase();
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final responseCode = data['code']?.toString().trim().toLowerCase();
      if (responseCode != null && responseCode.isNotEmpty) {
        return responseCode;
      }
    }
    final status = error.response?.statusCode;
    if (status != null) return 'http_$status';
  }
  if (normalized.contains('oronbox session expired')) return 'session_expired';
  var text = normalized.trim();
  for (final prefix in const ['exception: ', 'bad state: ']) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  final http = RegExp(
    r'\bhttp[_ ](400|401|403|404|409|413|422|429|500|502|503|504)\b',
  ).firstMatch(text);
  return http == null ? '' : 'http_${http.group(1)}';
}

String _flattenError(Object? error) {
  if (error == null) {
    return '';
  }
  if (error is PlatformException) {
    return [
      error.code,
      if (error.message != null) error.message!,
      if (error.details != null) error.details.toString(),
    ].join(' ');
  }
  return error.toString();
}

String? _backendMessage(Object? error) {
  String? message;
  if (error is CodedError) {
    message = error.message;
  } else if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          message = value;
          break;
        }
      }
    }
  }
  if (message == null) return null;
  final visibleMessage = _firstErrorLine(message);
  return visibleMessage.isEmpty ? null : visibleMessage;
}

String _trimPlatformNoise(String raw) {
  var text = _firstErrorLine(raw);
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  if (text.startsWith('Bad state: ')) {
    text = text.substring('Bad state: '.length);
  }
  return text;
}

String _firstErrorLine(String text) =>
    text.replaceAll('\r\n', '\n').split('\n').first.trim();
