Future<T> withPlatformCredentialLock<T>(Future<T> Function() action) =>
    action();
