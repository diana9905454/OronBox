// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TimeSyncProps _$TimeSyncPropsFromJson(Map<String, dynamic> json) {
  return _TimeSyncProps.fromJson(json);
}

/// @nodoc
mixin _$TimeSyncProps {
  SyncDate get date => throw _privateConstructorUsedError;
  SyncTime get time => throw _privateConstructorUsedError;
  SyncTimeZone get timezone => throw _privateConstructorUsedError;
  bool get is12HourFormat => throw _privateConstructorUsedError;

  /// Serializes this TimeSyncProps to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimeSyncPropsCopyWith<TimeSyncProps> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimeSyncPropsCopyWith<$Res> {
  factory $TimeSyncPropsCopyWith(
    TimeSyncProps value,
    $Res Function(TimeSyncProps) then,
  ) = _$TimeSyncPropsCopyWithImpl<$Res, TimeSyncProps>;
  @useResult
  $Res call({
    SyncDate date,
    SyncTime time,
    SyncTimeZone timezone,
    bool is12HourFormat,
  });

  $SyncDateCopyWith<$Res> get date;
  $SyncTimeCopyWith<$Res> get time;
  $SyncTimeZoneCopyWith<$Res> get timezone;
}

/// @nodoc
class _$TimeSyncPropsCopyWithImpl<$Res, $Val extends TimeSyncProps>
    implements $TimeSyncPropsCopyWith<$Res> {
  _$TimeSyncPropsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? time = null,
    Object? timezone = null,
    Object? is12HourFormat = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as SyncDate,
            time: null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                      as SyncTime,
            timezone: null == timezone
                ? _value.timezone
                : timezone // ignore: cast_nullable_to_non_nullable
                      as SyncTimeZone,
            is12HourFormat: null == is12HourFormat
                ? _value.is12HourFormat
                : is12HourFormat // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SyncDateCopyWith<$Res> get date {
    return $SyncDateCopyWith<$Res>(_value.date, (value) {
      return _then(_value.copyWith(date: value) as $Val);
    });
  }

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SyncTimeCopyWith<$Res> get time {
    return $SyncTimeCopyWith<$Res>(_value.time, (value) {
      return _then(_value.copyWith(time: value) as $Val);
    });
  }

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SyncTimeZoneCopyWith<$Res> get timezone {
    return $SyncTimeZoneCopyWith<$Res>(_value.timezone, (value) {
      return _then(_value.copyWith(timezone: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TimeSyncPropsImplCopyWith<$Res>
    implements $TimeSyncPropsCopyWith<$Res> {
  factory _$$TimeSyncPropsImplCopyWith(
    _$TimeSyncPropsImpl value,
    $Res Function(_$TimeSyncPropsImpl) then,
  ) = __$$TimeSyncPropsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SyncDate date,
    SyncTime time,
    SyncTimeZone timezone,
    bool is12HourFormat,
  });

  @override
  $SyncDateCopyWith<$Res> get date;
  @override
  $SyncTimeCopyWith<$Res> get time;
  @override
  $SyncTimeZoneCopyWith<$Res> get timezone;
}

/// @nodoc
class __$$TimeSyncPropsImplCopyWithImpl<$Res>
    extends _$TimeSyncPropsCopyWithImpl<$Res, _$TimeSyncPropsImpl>
    implements _$$TimeSyncPropsImplCopyWith<$Res> {
  __$$TimeSyncPropsImplCopyWithImpl(
    _$TimeSyncPropsImpl _value,
    $Res Function(_$TimeSyncPropsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? time = null,
    Object? timezone = null,
    Object? is12HourFormat = null,
  }) {
    return _then(
      _$TimeSyncPropsImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as SyncDate,
        time: null == time
            ? _value.time
            : time // ignore: cast_nullable_to_non_nullable
                  as SyncTime,
        timezone: null == timezone
            ? _value.timezone
            : timezone // ignore: cast_nullable_to_non_nullable
                  as SyncTimeZone,
        is12HourFormat: null == is12HourFormat
            ? _value.is12HourFormat
            : is12HourFormat // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeSyncPropsImpl implements _TimeSyncProps {
  const _$TimeSyncPropsImpl({
    required this.date,
    required this.time,
    required this.timezone,
    this.is12HourFormat = false,
  });

  factory _$TimeSyncPropsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeSyncPropsImplFromJson(json);

  @override
  final SyncDate date;
  @override
  final SyncTime time;
  @override
  final SyncTimeZone timezone;
  @override
  @JsonKey()
  final bool is12HourFormat;

  @override
  String toString() {
    return 'TimeSyncProps(date: $date, time: $time, timezone: $timezone, is12HourFormat: $is12HourFormat)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeSyncPropsImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.is12HourFormat, is12HourFormat) ||
                other.is12HourFormat == is12HourFormat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, date, time, timezone, is12HourFormat);

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeSyncPropsImplCopyWith<_$TimeSyncPropsImpl> get copyWith =>
      __$$TimeSyncPropsImplCopyWithImpl<_$TimeSyncPropsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeSyncPropsImplToJson(this);
  }
}

abstract class _TimeSyncProps implements TimeSyncProps {
  const factory _TimeSyncProps({
    required final SyncDate date,
    required final SyncTime time,
    required final SyncTimeZone timezone,
    final bool is12HourFormat,
  }) = _$TimeSyncPropsImpl;

  factory _TimeSyncProps.fromJson(Map<String, dynamic> json) =
      _$TimeSyncPropsImpl.fromJson;

  @override
  SyncDate get date;
  @override
  SyncTime get time;
  @override
  SyncTimeZone get timezone;
  @override
  bool get is12HourFormat;

  /// Create a copy of TimeSyncProps
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeSyncPropsImplCopyWith<_$TimeSyncPropsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncDate _$SyncDateFromJson(Map<String, dynamic> json) {
  return _SyncDate.fromJson(json);
}

/// @nodoc
mixin _$SyncDate {
  int get year => throw _privateConstructorUsedError;
  int get month => throw _privateConstructorUsedError;
  int get day => throw _privateConstructorUsedError;

  /// Serializes this SyncDate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SyncDate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncDateCopyWith<SyncDate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncDateCopyWith<$Res> {
  factory $SyncDateCopyWith(SyncDate value, $Res Function(SyncDate) then) =
      _$SyncDateCopyWithImpl<$Res, SyncDate>;
  @useResult
  $Res call({int year, int month, int day});
}

/// @nodoc
class _$SyncDateCopyWithImpl<$Res, $Val extends SyncDate>
    implements $SyncDateCopyWith<$Res> {
  _$SyncDateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncDate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? year = null, Object? month = null, Object? day = null}) {
    return _then(
      _value.copyWith(
            year: null == year
                ? _value.year
                : year // ignore: cast_nullable_to_non_nullable
                      as int,
            month: null == month
                ? _value.month
                : month // ignore: cast_nullable_to_non_nullable
                      as int,
            day: null == day
                ? _value.day
                : day // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncDateImplCopyWith<$Res>
    implements $SyncDateCopyWith<$Res> {
  factory _$$SyncDateImplCopyWith(
    _$SyncDateImpl value,
    $Res Function(_$SyncDateImpl) then,
  ) = __$$SyncDateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int year, int month, int day});
}

/// @nodoc
class __$$SyncDateImplCopyWithImpl<$Res>
    extends _$SyncDateCopyWithImpl<$Res, _$SyncDateImpl>
    implements _$$SyncDateImplCopyWith<$Res> {
  __$$SyncDateImplCopyWithImpl(
    _$SyncDateImpl _value,
    $Res Function(_$SyncDateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncDate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? year = null, Object? month = null, Object? day = null}) {
    return _then(
      _$SyncDateImpl(
        year: null == year
            ? _value.year
            : year // ignore: cast_nullable_to_non_nullable
                  as int,
        month: null == month
            ? _value.month
            : month // ignore: cast_nullable_to_non_nullable
                  as int,
        day: null == day
            ? _value.day
            : day // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncDateImpl implements _SyncDate {
  const _$SyncDateImpl({
    required this.year,
    required this.month,
    required this.day,
  });

  factory _$SyncDateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncDateImplFromJson(json);

  @override
  final int year;
  @override
  final int month;
  @override
  final int day;

  @override
  String toString() {
    return 'SyncDate(year: $year, month: $month, day: $day)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncDateImpl &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, year, month, day);

  /// Create a copy of SyncDate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncDateImplCopyWith<_$SyncDateImpl> get copyWith =>
      __$$SyncDateImplCopyWithImpl<_$SyncDateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncDateImplToJson(this);
  }
}

abstract class _SyncDate implements SyncDate {
  const factory _SyncDate({
    required final int year,
    required final int month,
    required final int day,
  }) = _$SyncDateImpl;

  factory _SyncDate.fromJson(Map<String, dynamic> json) =
      _$SyncDateImpl.fromJson;

  @override
  int get year;
  @override
  int get month;
  @override
  int get day;

  /// Create a copy of SyncDate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncDateImplCopyWith<_$SyncDateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncTime _$SyncTimeFromJson(Map<String, dynamic> json) {
  return _SyncTime.fromJson(json);
}

/// @nodoc
mixin _$SyncTime {
  int get hour => throw _privateConstructorUsedError;
  int get minute => throw _privateConstructorUsedError;
  int get second => throw _privateConstructorUsedError;
  int get millisecond => throw _privateConstructorUsedError;

  /// Serializes this SyncTime to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SyncTime
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncTimeCopyWith<SyncTime> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncTimeCopyWith<$Res> {
  factory $SyncTimeCopyWith(SyncTime value, $Res Function(SyncTime) then) =
      _$SyncTimeCopyWithImpl<$Res, SyncTime>;
  @useResult
  $Res call({int hour, int minute, int second, int millisecond});
}

/// @nodoc
class _$SyncTimeCopyWithImpl<$Res, $Val extends SyncTime>
    implements $SyncTimeCopyWith<$Res> {
  _$SyncTimeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncTime
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hour = null,
    Object? minute = null,
    Object? second = null,
    Object? millisecond = null,
  }) {
    return _then(
      _value.copyWith(
            hour: null == hour
                ? _value.hour
                : hour // ignore: cast_nullable_to_non_nullable
                      as int,
            minute: null == minute
                ? _value.minute
                : minute // ignore: cast_nullable_to_non_nullable
                      as int,
            second: null == second
                ? _value.second
                : second // ignore: cast_nullable_to_non_nullable
                      as int,
            millisecond: null == millisecond
                ? _value.millisecond
                : millisecond // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncTimeImplCopyWith<$Res>
    implements $SyncTimeCopyWith<$Res> {
  factory _$$SyncTimeImplCopyWith(
    _$SyncTimeImpl value,
    $Res Function(_$SyncTimeImpl) then,
  ) = __$$SyncTimeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int hour, int minute, int second, int millisecond});
}

/// @nodoc
class __$$SyncTimeImplCopyWithImpl<$Res>
    extends _$SyncTimeCopyWithImpl<$Res, _$SyncTimeImpl>
    implements _$$SyncTimeImplCopyWith<$Res> {
  __$$SyncTimeImplCopyWithImpl(
    _$SyncTimeImpl _value,
    $Res Function(_$SyncTimeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncTime
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hour = null,
    Object? minute = null,
    Object? second = null,
    Object? millisecond = null,
  }) {
    return _then(
      _$SyncTimeImpl(
        hour: null == hour
            ? _value.hour
            : hour // ignore: cast_nullable_to_non_nullable
                  as int,
        minute: null == minute
            ? _value.minute
            : minute // ignore: cast_nullable_to_non_nullable
                  as int,
        second: null == second
            ? _value.second
            : second // ignore: cast_nullable_to_non_nullable
                  as int,
        millisecond: null == millisecond
            ? _value.millisecond
            : millisecond // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncTimeImpl implements _SyncTime {
  const _$SyncTimeImpl({
    required this.hour,
    required this.minute,
    this.second = 0,
    this.millisecond = 0,
  });

  factory _$SyncTimeImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncTimeImplFromJson(json);

  @override
  final int hour;
  @override
  final int minute;
  @override
  @JsonKey()
  final int second;
  @override
  @JsonKey()
  final int millisecond;

  @override
  String toString() {
    return 'SyncTime(hour: $hour, minute: $minute, second: $second, millisecond: $millisecond)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncTimeImpl &&
            (identical(other.hour, hour) || other.hour == hour) &&
            (identical(other.minute, minute) || other.minute == minute) &&
            (identical(other.second, second) || other.second == second) &&
            (identical(other.millisecond, millisecond) ||
                other.millisecond == millisecond));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, hour, minute, second, millisecond);

  /// Create a copy of SyncTime
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncTimeImplCopyWith<_$SyncTimeImpl> get copyWith =>
      __$$SyncTimeImplCopyWithImpl<_$SyncTimeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncTimeImplToJson(this);
  }
}

abstract class _SyncTime implements SyncTime {
  const factory _SyncTime({
    required final int hour,
    required final int minute,
    final int second,
    final int millisecond,
  }) = _$SyncTimeImpl;

  factory _SyncTime.fromJson(Map<String, dynamic> json) =
      _$SyncTimeImpl.fromJson;

  @override
  int get hour;
  @override
  int get minute;
  @override
  int get second;
  @override
  int get millisecond;

  /// Create a copy of SyncTime
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncTimeImplCopyWith<_$SyncTimeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncTimeZone _$SyncTimeZoneFromJson(Map<String, dynamic> json) {
  return _SyncTimeZone.fromJson(json);
}

/// @nodoc
mixin _$SyncTimeZone {
  int get offset => throw _privateConstructorUsedError;
  int get dstOffset => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;

  /// Serializes this SyncTimeZone to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SyncTimeZone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncTimeZoneCopyWith<SyncTimeZone> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncTimeZoneCopyWith<$Res> {
  factory $SyncTimeZoneCopyWith(
    SyncTimeZone value,
    $Res Function(SyncTimeZone) then,
  ) = _$SyncTimeZoneCopyWithImpl<$Res, SyncTimeZone>;
  @useResult
  $Res call({int offset, int dstOffset, String id});
}

/// @nodoc
class _$SyncTimeZoneCopyWithImpl<$Res, $Val extends SyncTimeZone>
    implements $SyncTimeZoneCopyWith<$Res> {
  _$SyncTimeZoneCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncTimeZone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? offset = null,
    Object? dstOffset = null,
    Object? id = null,
  }) {
    return _then(
      _value.copyWith(
            offset: null == offset
                ? _value.offset
                : offset // ignore: cast_nullable_to_non_nullable
                      as int,
            dstOffset: null == dstOffset
                ? _value.dstOffset
                : dstOffset // ignore: cast_nullable_to_non_nullable
                      as int,
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncTimeZoneImplCopyWith<$Res>
    implements $SyncTimeZoneCopyWith<$Res> {
  factory _$$SyncTimeZoneImplCopyWith(
    _$SyncTimeZoneImpl value,
    $Res Function(_$SyncTimeZoneImpl) then,
  ) = __$$SyncTimeZoneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int offset, int dstOffset, String id});
}

/// @nodoc
class __$$SyncTimeZoneImplCopyWithImpl<$Res>
    extends _$SyncTimeZoneCopyWithImpl<$Res, _$SyncTimeZoneImpl>
    implements _$$SyncTimeZoneImplCopyWith<$Res> {
  __$$SyncTimeZoneImplCopyWithImpl(
    _$SyncTimeZoneImpl _value,
    $Res Function(_$SyncTimeZoneImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncTimeZone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? offset = null,
    Object? dstOffset = null,
    Object? id = null,
  }) {
    return _then(
      _$SyncTimeZoneImpl(
        offset: null == offset
            ? _value.offset
            : offset // ignore: cast_nullable_to_non_nullable
                  as int,
        dstOffset: null == dstOffset
            ? _value.dstOffset
            : dstOffset // ignore: cast_nullable_to_non_nullable
                  as int,
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncTimeZoneImpl implements _SyncTimeZone {
  const _$SyncTimeZoneImpl({
    required this.offset,
    this.dstOffset = 0,
    required this.id,
  });

  factory _$SyncTimeZoneImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncTimeZoneImplFromJson(json);

  @override
  final int offset;
  @override
  @JsonKey()
  final int dstOffset;
  @override
  final String id;

  @override
  String toString() {
    return 'SyncTimeZone(offset: $offset, dstOffset: $dstOffset, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncTimeZoneImpl &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.dstOffset, dstOffset) ||
                other.dstOffset == dstOffset) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, offset, dstOffset, id);

  /// Create a copy of SyncTimeZone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncTimeZoneImplCopyWith<_$SyncTimeZoneImpl> get copyWith =>
      __$$SyncTimeZoneImplCopyWithImpl<_$SyncTimeZoneImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncTimeZoneImplToJson(this);
  }
}

abstract class _SyncTimeZone implements SyncTimeZone {
  const factory _SyncTimeZone({
    required final int offset,
    final int dstOffset,
    required final String id,
  }) = _$SyncTimeZoneImpl;

  factory _SyncTimeZone.fromJson(Map<String, dynamic> json) =
      _$SyncTimeZoneImpl.fromJson;

  @override
  int get offset;
  @override
  int get dstOffset;
  @override
  String get id;

  /// Create a copy of SyncTimeZone
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncTimeZoneImplCopyWith<_$SyncTimeZoneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
