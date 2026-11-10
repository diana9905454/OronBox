import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract class MiAccountTwoFactorResolver {
  Future<String> resolve(BuildContext context, Uri notificationUrl);
}

MiAccountTwoFactorResolver createMiAccountTwoFactorResolver() {
  if (!kIsWeb) {
    return const NativeMiAccountTwoFactorResolver();
  }
  return const UnsupportedMiAccountTwoFactorResolver();
}

class NativeMiAccountTwoFactorResolver implements MiAccountTwoFactorResolver {
  const NativeMiAccountTwoFactorResolver();

  static const _method = MethodChannel('oronbox/mi_account_2fa');

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) async {
    final cookieHeader = await _method.invokeMethod<String>('resolve', {
      'url': notificationUrl.toString(),
    });
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      throw StateError('Xiaomi 2FA did not return account cookies');
    }
    return cookieHeader;
  }
}

class UnsupportedMiAccountTwoFactorResolver
    implements MiAccountTwoFactorResolver {
  const UnsupportedMiAccountTwoFactorResolver();

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) {
    throw UnsupportedError(
      kIsWeb
          ? 'Xiaomi 2FA is not available on web because browser cookie access is isolated'
          : 'This platform does not support Xiaomi 2FA WebView',
    );
  }
}
