enum GlobalModalPriority {
  low,
  normal,
  high,
  urgent,
}

abstract class GlobalModalRequest {
  const GlobalModalRequest();

  String get id;
  GlobalModalPriority get priority;
  DateTime get createdAt;
  bool get isExpired => false;
}

class LocalServerPairingModalRequest extends GlobalModalRequest {
  LocalServerPairingModalRequest({
    required this.pairingId,
    required this.clientName,
    required this.fingerprint,
    required this.scopes,
    required this.expiresAt,
    required this.onApprove,
    required this.onReject,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String pairingId;
  final String clientName;
  final String fingerprint;
  final Set<String> scopes;
  final DateTime expiresAt;
  final void Function(bool remember) onApprove;
  final void Function() onReject;

  @override
  final DateTime createdAt;

  @override
  String get id => 'pairing-$pairingId';

  @override
  GlobalModalPriority get priority => GlobalModalPriority.high;

  @override
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class DeviceWifiPasswordModalRequest extends GlobalModalRequest {
  DeviceWifiPasswordModalRequest({
    required this.deviceId,
    required this.ssid,
    required this.authMode,
    required this.frequency,
    required this.onConnect,
    required this.onCancel,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String deviceId;
  final String ssid;
  final int authMode;
  final int frequency;
  final void Function(String password) onConnect;
  final void Function() onCancel;

  @override
  final DateTime createdAt;

  @override
  String get id => 'wifi-$deviceId-$ssid';

  @override
  GlobalModalPriority get priority => GlobalModalPriority.urgent;
}

class AnnouncementModalRequest extends GlobalModalRequest {
  AnnouncementModalRequest({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.onAcknowledge,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String announcementId;
  final String title;
  final String body;
  final void Function() onAcknowledge;

  @override
  final DateTime createdAt;

  @override
  String get id => 'announcement-$announcementId';

  @override
  GlobalModalPriority get priority => GlobalModalPriority.normal;
}
