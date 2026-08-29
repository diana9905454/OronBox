// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bt_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BTDeviceInfoImpl _$$BTDeviceInfoImplFromJson(Map<String, dynamic> json) =>
    _$BTDeviceInfoImpl(
      name: json['name'] as String,
      addr: json['addr'] as String,
      connectType: json['connectType'] as String,
    );

Map<String, dynamic> _$$BTDeviceInfoImplToJson(_$BTDeviceInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'addr': instance.addr,
      'connectType': instance.connectType,
    };

_$MiWearStateImpl _$$MiWearStateImplFromJson(Map<String, dynamic> json) =>
    _$MiWearStateImpl(
      name: json['name'] as String,
      addr: json['addr'] as String,
      connectType: json['connectType'] as String,
      authkey: json['authkey'] as String?,
      codename: json['codename'] as String?,
      disconnected: json['disconnected'] as bool? ?? false,
    );

Map<String, dynamic> _$$MiWearStateImplToJson(_$MiWearStateImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'addr': instance.addr,
      'connectType': instance.connectType,
      'authkey': instance.authkey,
      'codename': instance.codename,
      'disconnected': instance.disconnected,
    };

_$ChargeInfoImpl _$$ChargeInfoImplFromJson(Map<String, dynamic> json) =>
    _$ChargeInfoImpl(
      state: (json['state'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$ChargeInfoImplToJson(_$ChargeInfoImpl instance) =>
    <String, dynamic>{'state': instance.state, 'timestamp': instance.timestamp};

_$BatteryStatusImpl _$$BatteryStatusImplFromJson(Map<String, dynamic> json) =>
    _$BatteryStatusImpl(
      capacity: (json['capacity'] as num).toInt(),
      chargeStatus:
          $enumDecodeNullable(_$ChargeStatusEnumMap, json['chargeStatus']) ??
          ChargeStatus.unknown,
      chargeInfo: json['chargeInfo'] == null
          ? null
          : ChargeInfo.fromJson(json['chargeInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$BatteryStatusImplToJson(_$BatteryStatusImpl instance) =>
    <String, dynamic>{
      'capacity': instance.capacity,
      'chargeStatus': _$ChargeStatusEnumMap[instance.chargeStatus]!,
      'chargeInfo': instance.chargeInfo,
    };

const _$ChargeStatusEnumMap = {
  ChargeStatus.unknown: 'unknown',
  ChargeStatus.charging: 'charging',
  ChargeStatus.notCharging: 'notCharging',
  ChargeStatus.full: 'full',
};

_$AppInfoImpl _$$AppInfoImplFromJson(Map<String, dynamic> json) =>
    _$AppInfoImpl(
      packageName: json['packageName'] as String,
      fingerprint:
          (json['fingerprint'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      canRemove: json['canRemove'] as bool? ?? false,
      appName: json['appName'] as String,
    );

Map<String, dynamic> _$$AppInfoImplToJson(_$AppInfoImpl instance) =>
    <String, dynamic>{
      'packageName': instance.packageName,
      'fingerprint': instance.fingerprint,
      'versionCode': instance.versionCode,
      'canRemove': instance.canRemove,
      'appName': instance.appName,
    };

_$StorageInfoImpl _$$StorageInfoImplFromJson(Map<String, dynamic> json) =>
    _$StorageInfoImpl(
      used: (json['used'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$$StorageInfoImplToJson(_$StorageInfoImpl instance) =>
    <String, dynamic>{'used': instance.used, 'total': instance.total};

_$SystemInfoImpl _$$SystemInfoImplFromJson(Map<String, dynamic> json) =>
    _$SystemInfoImpl(
      serialNumber: json['serialNumber'] as String,
      firmwareVersion: json['firmwareVersion'] as String,
      imei: json['imei'] as String,
      model: json['model'] as String,
      storageInfo: json['storageInfo'] == null
          ? null
          : StorageInfo.fromJson(json['storageInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$SystemInfoImplToJson(_$SystemInfoImpl instance) =>
    <String, dynamic>{
      'serialNumber': instance.serialNumber,
      'firmwareVersion': instance.firmwareVersion,
      'imei': instance.imei,
      'model': instance.model,
      'storageInfo': instance.storageInfo,
    };

_$WatchfaceInfoImpl _$$WatchfaceInfoImplFromJson(Map<String, dynamic> json) =>
    _$WatchfaceInfoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      isCurrent: json['isCurrent'] as bool? ?? false,
      canRemove: json['canRemove'] as bool? ?? false,
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      canEdit: json['canEdit'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as String? ?? '',
      backgroundImage: json['backgroundImage'] as String? ?? '',
      style: json['style'] as String? ?? '',
      backgroundImageList:
          (json['backgroundImageList'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$WatchfaceInfoImplToJson(_$WatchfaceInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isCurrent': instance.isCurrent,
      'canRemove': instance.canRemove,
      'versionCode': instance.versionCode,
      'canEdit': instance.canEdit,
      'backgroundColor': instance.backgroundColor,
      'backgroundImage': instance.backgroundImage,
      'style': instance.style,
      'backgroundImageList': instance.backgroundImageList,
    };
