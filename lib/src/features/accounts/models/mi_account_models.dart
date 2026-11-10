class MiAccountToken {
  const MiAccountToken({
    required this.userId,
    required this.deviceId,
    required this.ssecurity,
    required this.serviceToken,
    required this.cUserId,
    required this.passToken,
    required this.psecurity,
  });

  final String userId;
  final String deviceId;
  final String ssecurity;
  final String serviceToken;
  final String cUserId;
  final String passToken;
  final String psecurity;

  bool get isValid => ssecurity.isNotEmpty && serviceToken.isNotEmpty;

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'device_id': deviceId,
    'ssecurity': ssecurity,
    'service_token': serviceToken,
    'c_user_id': cUserId,
    'pass_token': passToken,
    'psecurity': psecurity,
  };

  static MiAccountToken? fromJson(Map<String, Object?> json) {
    final token = MiAccountToken(
      userId: json['user_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      ssecurity: json['ssecurity']?.toString() ?? '',
      serviceToken: json['service_token']?.toString() ?? '',
      cUserId: json['c_user_id']?.toString() ?? '',
      passToken: json['pass_token']?.toString() ?? '',
      psecurity: json['psecurity']?.toString() ?? '',
    );
    return token.isValid ? token : null;
  }
}

class MiCloudDevice {
  const MiCloudDevice({
    required this.name,
    required this.model,
    required this.mac,
    required this.authKey,
    required this.firmwareVersion,
    required this.serialNumber,
  });

  final String name;
  final String model;
  final String mac;
  final String authKey;
  final String firmwareVersion;
  final String serialNumber;

  /// Whether this record contains the complete Bluetooth address required by
  /// the device manager. Xiaomi Fitness redacts the leading bytes in some
  /// exported logs, so a record may still contain a key while only exposing a
  /// short address suffix.
  bool get hasAuthKey =>
      _isCompleteBluetoothAddress(mac) && authKey.trim().isNotEmpty;

  factory MiCloudDevice.fromJson(Map<String, dynamic> json) {
    final root = _mapValue(json['deviceInfo']) ?? json;
    final device = _mapValue(root['device']) ?? root;
    final detail =
        _mapValue(device['detail']) ??
        _mapValue(root['detail']) ??
        const <String, dynamic>{};
    return MiCloudDevice(
      name: _firstString([
        device['name'],
        root['name'],
        _mapValue(device['product'])?['productName'],
      ]),
      model: _firstString([
        device['model'],
        root['model'],
        _mapValue(device['product'])?['model'],
      ]),
      mac: _firstString([
        detail['mac'],
        detail['macAddress'],
        detail['mac_address'],
        device['mac'],
        device['macAddress'],
        root['mac'],
        root['macAddress'],
      ]),
      authKey: _firstString([
        detail['encrypt_key'],
        detail['encryptKey'],
        detail['auth_key'],
        detail['authKey'],
        detail['huamiAuthKey'],
        device['encryptKey'],
        device['authKey'],
        root['encryptKey'],
        root['authKey'],
      ]),
      firmwareVersion: _firstString([
        detail['fw_ver'],
        detail['fwVer'],
        detail['firmwareVersion'],
        device['firmwareVersion'],
        root['firmwareVersion'],
      ]),
      serialNumber: _firstString([
        detail['sn'],
        detail['serialNumber'],
        device['sn'],
        device['serialNumber'],
        root['sn'],
        root['serialNumber'],
      ]),
    );
  }
}

/// Resolves a redacted address suffix against complete candidate addresses.
/// Ambiguous or unknown suffixes are deliberately not guessed.
String? resolveMiCloudDeviceAddress(
  MiCloudDevice device,
  Iterable<String> knownAddresses,
) {
  if (device.authKey.trim().isEmpty) return null;
  final direct = _normalizeCompleteBluetoothAddress(device.mac);
  if (direct != null) return direct;

  final suffix = _normalizeMacSuffix(device.mac);
  if (suffix == null) return null;
  final matches = <String>{};
  for (final address in knownAddresses) {
    final normalized = _normalizeCompleteBluetoothAddress(address);
    if (normalized != null && normalized.replaceAll(':', '').endsWith(suffix)) {
      matches.add(normalized);
    }
  }
  return matches.length == 1 ? matches.single : null;
}

Map<String, dynamic>? _mapValue(Object? value) {
  return value is Map ? value.cast<String, dynamic>() : null;
}

String _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

bool _isCompleteBluetoothAddress(String value) =>
    RegExp(r'^[0-9a-fA-F]{2}([:-][0-9a-fA-F]{2}){5}$').hasMatch(value.trim());

String? _normalizeCompleteBluetoothAddress(String value) {
  if (!_isCompleteBluetoothAddress(value)) return null;
  final hex = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  return [
    for (var index = 0; index < hex.length; index += 2)
      hex.substring(index, index + 2),
  ].join(':');
}

String? _normalizeMacSuffix(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^[0-9a-fA-F]{2}([:-][0-9a-fA-F]{2}){1,5}$').hasMatch(trimmed)) {
    return null;
  }
  return trimmed.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
}

class MiAccountTwoFactorRequired implements Exception {
  MiAccountTwoFactorRequired({required this.url, required this.deviceId});

  final String url;
  final String deviceId;

  @override
  String toString() => 'Xiaomi account requires two-factor verification: $url';
}

class MiAccountSessionExpired implements Exception {
  const MiAccountSessionExpired({this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'Xiaomi account session expired';
}
