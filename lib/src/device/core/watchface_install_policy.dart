import 'package:oronbox/src/core/errors/coded_error.dart';

/// Watchface IDs with this prefix are restricted from local installation.
const restrictedWatchfaceIdPrefix = '1209';

bool isRestrictedWatchfaceId(String? id) {
  final normalized = id?.trim();
  return normalized != null &&
      normalized.startsWith(restrictedWatchfaceIdPrefix);
}

/// Reads the embedded Vela watchface ID from a raw watchface payload.
String? extractVelaWatchfaceId(List<int> bytes) {
  const idOffset = 0x28;
  const idLength = 12;
  if (bytes.length < idOffset + idLength) return null;
  final raw = bytes.sublist(idOffset, idOffset + idLength);
  final result = raw
      .takeWhile((byte) => byte != 0)
      .map(String.fromCharCode)
      .join()
      .trim();
  return result.isEmpty ? null : result;
}

/// Returns the first restricted ID found in the payload or install metadata.
String? restrictedWatchfaceIdFor({
  List<int>? payload,
  String? identifier,
  String? analyzedIdentifier,
  String? fallbackIdentifier,
}) {
  final embedded = payload == null ? null : extractVelaWatchfaceId(payload);
  for (final candidate in [
    embedded,
    analyzedIdentifier,
    identifier,
    fallbackIdentifier,
  ]) {
    if (isRestrictedWatchfaceId(candidate)) return candidate!.trim();
  }
  return null;
}

class WatchfaceInstallBlockedException implements CodedError {
  const WatchfaceInstallBlockedException(this.watchfaceId);

  final String watchfaceId;

  @override
  String get code => 'watchface_install_blocked';

  @override
  String get message =>
      '为尊重知识产权及遵守相关政策，应小米方面要求\nOronBox 无法安装疑似来自官方表盘商城的表盘\n如果你认为这是一个误报，请让表盘作者联系我们';

  @override
  Object get details => {
    'watchfaceId': watchfaceId,
    'restrictedPrefix': restrictedWatchfaceIdPrefix,
  };

  @override
  String toString() => message;
}
