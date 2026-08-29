// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TimeSyncPropsImpl _$$TimeSyncPropsImplFromJson(Map<String, dynamic> json) =>
    _$TimeSyncPropsImpl(
      date: SyncDate.fromJson(json['date'] as Map<String, dynamic>),
      time: SyncTime.fromJson(json['time'] as Map<String, dynamic>),
      timezone: SyncTimeZone.fromJson(json['timezone'] as Map<String, dynamic>),
      is12HourFormat: json['is12HourFormat'] as bool? ?? false,
    );

Map<String, dynamic> _$$TimeSyncPropsImplToJson(_$TimeSyncPropsImpl instance) =>
    <String, dynamic>{
      'date': instance.date,
      'time': instance.time,
      'timezone': instance.timezone,
      'is12HourFormat': instance.is12HourFormat,
    };

_$SyncDateImpl _$$SyncDateImplFromJson(Map<String, dynamic> json) =>
    _$SyncDateImpl(
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      day: (json['day'] as num).toInt(),
    );

Map<String, dynamic> _$$SyncDateImplToJson(_$SyncDateImpl instance) =>
    <String, dynamic>{
      'year': instance.year,
      'month': instance.month,
      'day': instance.day,
    };

_$SyncTimeImpl _$$SyncTimeImplFromJson(Map<String, dynamic> json) =>
    _$SyncTimeImpl(
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      second: (json['second'] as num?)?.toInt() ?? 0,
      millisecond: (json['millisecond'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$SyncTimeImplToJson(_$SyncTimeImpl instance) =>
    <String, dynamic>{
      'hour': instance.hour,
      'minute': instance.minute,
      'second': instance.second,
      'millisecond': instance.millisecond,
    };

_$SyncTimeZoneImpl _$$SyncTimeZoneImplFromJson(Map<String, dynamic> json) =>
    _$SyncTimeZoneImpl(
      offset: (json['offset'] as num).toInt(),
      dstOffset: (json['dstOffset'] as num?)?.toInt() ?? 0,
      id: json['id'] as String,
    );

Map<String, dynamic> _$$SyncTimeZoneImplToJson(_$SyncTimeZoneImpl instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'dstOffset': instance.dstOffset,
      'id': instance.id,
    };
