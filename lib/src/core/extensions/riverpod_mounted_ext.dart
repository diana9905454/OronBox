/// Compatibility shim for riverpod 2.6.1.
///
/// `NotifierProviderRef.mounted` was introduced in riverpod 3.x. In 2.6.1 the
/// getter exists on the runtime element (`NotifierProviderElement`) but is not
/// declared on the `NotifierProviderRef` interface, so `ref.mounted` fails to
/// compile. This extension bridges the gap via a dynamic dispatch — safe
/// because `ref` always returns the backing element at runtime.
import 'package:riverpod/riverpod.dart';

extension NotifierProviderRefMounted<T> on NotifierProviderRef<T> {
  /// Whether the provider element backing this ref is still mounted.
  ///
  /// Returns `false` if the dynamic lookup fails (defensive default).
  bool get mounted {
    final dynamic element = this;
    try {
      return (element.mounted as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
