import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_models.freezed.dart';
part 'sync_models.g.dart';

@freezed
abstract class TimeSyncProps with _$TimeSyncProps {
  const factory TimeSyncProps({
    required SyncDate date,
    required SyncTime time,
    required SyncTimeZone timezone,
    @Default(false) bool is12HourFormat,
  }) = _TimeSyncProps;

  factory TimeSyncProps.fromJson(Map<String, Object?> json) =>
      _$TimeSyncPropsFromJson(json);
}

@freezed
abstract class SyncDate with _$SyncDate {
  const factory SyncDate({
    required int year,
    required int month,
    required int day,
  }) = _SyncDate;

  factory SyncDate.fromJson(Map<String, Object?> json) =>
      _$SyncDateFromJson(json);
}

@freezed
abstract class SyncTime with _$SyncTime {
  const factory SyncTime({
    required int hour,
    required int minute,
    @Default(0) int second,
    @Default(0) int millisecond,
  }) = _SyncTime;

  factory SyncTime.fromJson(Map<String, Object?> json) =>
      _$SyncTimeFromJson(json);
}

@freezed
abstract class SyncTimeZone with _$SyncTimeZone {
  const factory SyncTimeZone({
    /// Signed offset in 15-minute blocks, as required by Xiaomi's protobuf.
    required int offset,
    /// Daylight-saving adjustment in the same signed 15-minute units.
    @Default(0) int dstOffset,
    required String id,
  }) = _SyncTimeZone;

  factory SyncTimeZone.fromJson(Map<String, Object?> json) =>
      _$SyncTimeZoneFromJson(json);
}
