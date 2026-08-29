// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bt_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BTDeviceInfo _$BTDeviceInfoFromJson(Map<String, dynamic> json) {
  return _BTDeviceInfo.fromJson(json);
}

/// @nodoc
mixin _$BTDeviceInfo {
  String get name => throw _privateConstructorUsedError;
  String get addr => throw _privateConstructorUsedError;
  String get connectType => throw _privateConstructorUsedError;

  /// Serializes this BTDeviceInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BTDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BTDeviceInfoCopyWith<BTDeviceInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BTDeviceInfoCopyWith<$Res> {
  factory $BTDeviceInfoCopyWith(
    BTDeviceInfo value,
    $Res Function(BTDeviceInfo) then,
  ) = _$BTDeviceInfoCopyWithImpl<$Res, BTDeviceInfo>;
  @useResult
  $Res call({String name, String addr, String connectType});
}

/// @nodoc
class _$BTDeviceInfoCopyWithImpl<$Res, $Val extends BTDeviceInfo>
    implements $BTDeviceInfoCopyWith<$Res> {
  _$BTDeviceInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BTDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? addr = null,
    Object? connectType = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            addr: null == addr
                ? _value.addr
                : addr // ignore: cast_nullable_to_non_nullable
                      as String,
            connectType: null == connectType
                ? _value.connectType
                : connectType // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BTDeviceInfoImplCopyWith<$Res>
    implements $BTDeviceInfoCopyWith<$Res> {
  factory _$$BTDeviceInfoImplCopyWith(
    _$BTDeviceInfoImpl value,
    $Res Function(_$BTDeviceInfoImpl) then,
  ) = __$$BTDeviceInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String addr, String connectType});
}

/// @nodoc
class __$$BTDeviceInfoImplCopyWithImpl<$Res>
    extends _$BTDeviceInfoCopyWithImpl<$Res, _$BTDeviceInfoImpl>
    implements _$$BTDeviceInfoImplCopyWith<$Res> {
  __$$BTDeviceInfoImplCopyWithImpl(
    _$BTDeviceInfoImpl _value,
    $Res Function(_$BTDeviceInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BTDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? addr = null,
    Object? connectType = null,
  }) {
    return _then(
      _$BTDeviceInfoImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        addr: null == addr
            ? _value.addr
            : addr // ignore: cast_nullable_to_non_nullable
                  as String,
        connectType: null == connectType
            ? _value.connectType
            : connectType // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BTDeviceInfoImpl implements _BTDeviceInfo {
  const _$BTDeviceInfoImpl({
    required this.name,
    required this.addr,
    required this.connectType,
  });

  factory _$BTDeviceInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$BTDeviceInfoImplFromJson(json);

  @override
  final String name;
  @override
  final String addr;
  @override
  final String connectType;

  @override
  String toString() {
    return 'BTDeviceInfo(name: $name, addr: $addr, connectType: $connectType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BTDeviceInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.addr, addr) || other.addr == addr) &&
            (identical(other.connectType, connectType) ||
                other.connectType == connectType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, addr, connectType);

  /// Create a copy of BTDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BTDeviceInfoImplCopyWith<_$BTDeviceInfoImpl> get copyWith =>
      __$$BTDeviceInfoImplCopyWithImpl<_$BTDeviceInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BTDeviceInfoImplToJson(this);
  }
}

abstract class _BTDeviceInfo implements BTDeviceInfo {
  const factory _BTDeviceInfo({
    required final String name,
    required final String addr,
    required final String connectType,
  }) = _$BTDeviceInfoImpl;

  factory _BTDeviceInfo.fromJson(Map<String, dynamic> json) =
      _$BTDeviceInfoImpl.fromJson;

  @override
  String get name;
  @override
  String get addr;
  @override
  String get connectType;

  /// Create a copy of BTDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BTDeviceInfoImplCopyWith<_$BTDeviceInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MiWearState _$MiWearStateFromJson(Map<String, dynamic> json) {
  return _MiWearState.fromJson(json);
}

/// @nodoc
mixin _$MiWearState {
  String get name => throw _privateConstructorUsedError;
  String get addr => throw _privateConstructorUsedError;
  String get connectType => throw _privateConstructorUsedError;
  String? get authkey => throw _privateConstructorUsedError;
  String? get codename => throw _privateConstructorUsedError;
  bool get disconnected => throw _privateConstructorUsedError;

  /// Serializes this MiWearState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MiWearState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MiWearStateCopyWith<MiWearState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MiWearStateCopyWith<$Res> {
  factory $MiWearStateCopyWith(
    MiWearState value,
    $Res Function(MiWearState) then,
  ) = _$MiWearStateCopyWithImpl<$Res, MiWearState>;
  @useResult
  $Res call({
    String name,
    String addr,
    String connectType,
    String? authkey,
    String? codename,
    bool disconnected,
  });
}

/// @nodoc
class _$MiWearStateCopyWithImpl<$Res, $Val extends MiWearState>
    implements $MiWearStateCopyWith<$Res> {
  _$MiWearStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MiWearState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? addr = null,
    Object? connectType = null,
    Object? authkey = freezed,
    Object? codename = freezed,
    Object? disconnected = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            addr: null == addr
                ? _value.addr
                : addr // ignore: cast_nullable_to_non_nullable
                      as String,
            connectType: null == connectType
                ? _value.connectType
                : connectType // ignore: cast_nullable_to_non_nullable
                      as String,
            authkey: freezed == authkey
                ? _value.authkey
                : authkey // ignore: cast_nullable_to_non_nullable
                      as String?,
            codename: freezed == codename
                ? _value.codename
                : codename // ignore: cast_nullable_to_non_nullable
                      as String?,
            disconnected: null == disconnected
                ? _value.disconnected
                : disconnected // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MiWearStateImplCopyWith<$Res>
    implements $MiWearStateCopyWith<$Res> {
  factory _$$MiWearStateImplCopyWith(
    _$MiWearStateImpl value,
    $Res Function(_$MiWearStateImpl) then,
  ) = __$$MiWearStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String addr,
    String connectType,
    String? authkey,
    String? codename,
    bool disconnected,
  });
}

/// @nodoc
class __$$MiWearStateImplCopyWithImpl<$Res>
    extends _$MiWearStateCopyWithImpl<$Res, _$MiWearStateImpl>
    implements _$$MiWearStateImplCopyWith<$Res> {
  __$$MiWearStateImplCopyWithImpl(
    _$MiWearStateImpl _value,
    $Res Function(_$MiWearStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MiWearState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? addr = null,
    Object? connectType = null,
    Object? authkey = freezed,
    Object? codename = freezed,
    Object? disconnected = null,
  }) {
    return _then(
      _$MiWearStateImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        addr: null == addr
            ? _value.addr
            : addr // ignore: cast_nullable_to_non_nullable
                  as String,
        connectType: null == connectType
            ? _value.connectType
            : connectType // ignore: cast_nullable_to_non_nullable
                  as String,
        authkey: freezed == authkey
            ? _value.authkey
            : authkey // ignore: cast_nullable_to_non_nullable
                  as String?,
        codename: freezed == codename
            ? _value.codename
            : codename // ignore: cast_nullable_to_non_nullable
                  as String?,
        disconnected: null == disconnected
            ? _value.disconnected
            : disconnected // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MiWearStateImpl implements _MiWearState {
  const _$MiWearStateImpl({
    required this.name,
    required this.addr,
    required this.connectType,
    this.authkey,
    this.codename,
    this.disconnected = false,
  });

  factory _$MiWearStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$MiWearStateImplFromJson(json);

  @override
  final String name;
  @override
  final String addr;
  @override
  final String connectType;
  @override
  final String? authkey;
  @override
  final String? codename;
  @override
  @JsonKey()
  final bool disconnected;

  @override
  String toString() {
    return 'MiWearState(name: $name, addr: $addr, connectType: $connectType, authkey: $authkey, codename: $codename, disconnected: $disconnected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MiWearStateImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.addr, addr) || other.addr == addr) &&
            (identical(other.connectType, connectType) ||
                other.connectType == connectType) &&
            (identical(other.authkey, authkey) || other.authkey == authkey) &&
            (identical(other.codename, codename) ||
                other.codename == codename) &&
            (identical(other.disconnected, disconnected) ||
                other.disconnected == disconnected));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    addr,
    connectType,
    authkey,
    codename,
    disconnected,
  );

  /// Create a copy of MiWearState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MiWearStateImplCopyWith<_$MiWearStateImpl> get copyWith =>
      __$$MiWearStateImplCopyWithImpl<_$MiWearStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MiWearStateImplToJson(this);
  }
}

abstract class _MiWearState implements MiWearState {
  const factory _MiWearState({
    required final String name,
    required final String addr,
    required final String connectType,
    final String? authkey,
    final String? codename,
    final bool disconnected,
  }) = _$MiWearStateImpl;

  factory _MiWearState.fromJson(Map<String, dynamic> json) =
      _$MiWearStateImpl.fromJson;

  @override
  String get name;
  @override
  String get addr;
  @override
  String get connectType;
  @override
  String? get authkey;
  @override
  String? get codename;
  @override
  bool get disconnected;

  /// Create a copy of MiWearState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MiWearStateImplCopyWith<_$MiWearStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChargeInfo _$ChargeInfoFromJson(Map<String, dynamic> json) {
  return _ChargeInfo.fromJson(json);
}

/// @nodoc
mixin _$ChargeInfo {
  int get state => throw _privateConstructorUsedError;
  int? get timestamp => throw _privateConstructorUsedError;

  /// Serializes this ChargeInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChargeInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChargeInfoCopyWith<ChargeInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChargeInfoCopyWith<$Res> {
  factory $ChargeInfoCopyWith(
    ChargeInfo value,
    $Res Function(ChargeInfo) then,
  ) = _$ChargeInfoCopyWithImpl<$Res, ChargeInfo>;
  @useResult
  $Res call({int state, int? timestamp});
}

/// @nodoc
class _$ChargeInfoCopyWithImpl<$Res, $Val extends ChargeInfo>
    implements $ChargeInfoCopyWith<$Res> {
  _$ChargeInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChargeInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? state = null, Object? timestamp = freezed}) {
    return _then(
      _value.copyWith(
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as int,
            timestamp: freezed == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChargeInfoImplCopyWith<$Res>
    implements $ChargeInfoCopyWith<$Res> {
  factory _$$ChargeInfoImplCopyWith(
    _$ChargeInfoImpl value,
    $Res Function(_$ChargeInfoImpl) then,
  ) = __$$ChargeInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int state, int? timestamp});
}

/// @nodoc
class __$$ChargeInfoImplCopyWithImpl<$Res>
    extends _$ChargeInfoCopyWithImpl<$Res, _$ChargeInfoImpl>
    implements _$$ChargeInfoImplCopyWith<$Res> {
  __$$ChargeInfoImplCopyWithImpl(
    _$ChargeInfoImpl _value,
    $Res Function(_$ChargeInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChargeInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? state = null, Object? timestamp = freezed}) {
    return _then(
      _$ChargeInfoImpl(
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as int,
        timestamp: freezed == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChargeInfoImpl implements _ChargeInfo {
  const _$ChargeInfoImpl({this.state = 0, this.timestamp});

  factory _$ChargeInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChargeInfoImplFromJson(json);

  @override
  @JsonKey()
  final int state;
  @override
  final int? timestamp;

  @override
  String toString() {
    return 'ChargeInfo(state: $state, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChargeInfoImpl &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, state, timestamp);

  /// Create a copy of ChargeInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChargeInfoImplCopyWith<_$ChargeInfoImpl> get copyWith =>
      __$$ChargeInfoImplCopyWithImpl<_$ChargeInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChargeInfoImplToJson(this);
  }
}

abstract class _ChargeInfo implements ChargeInfo {
  const factory _ChargeInfo({final int state, final int? timestamp}) =
      _$ChargeInfoImpl;

  factory _ChargeInfo.fromJson(Map<String, dynamic> json) =
      _$ChargeInfoImpl.fromJson;

  @override
  int get state;
  @override
  int? get timestamp;

  /// Create a copy of ChargeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChargeInfoImplCopyWith<_$ChargeInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BatteryStatus _$BatteryStatusFromJson(Map<String, dynamic> json) {
  return _BatteryStatus.fromJson(json);
}

/// @nodoc
mixin _$BatteryStatus {
  int get capacity => throw _privateConstructorUsedError;
  ChargeStatus get chargeStatus => throw _privateConstructorUsedError;
  ChargeInfo? get chargeInfo => throw _privateConstructorUsedError;

  /// Serializes this BatteryStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BatteryStatusCopyWith<BatteryStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BatteryStatusCopyWith<$Res> {
  factory $BatteryStatusCopyWith(
    BatteryStatus value,
    $Res Function(BatteryStatus) then,
  ) = _$BatteryStatusCopyWithImpl<$Res, BatteryStatus>;
  @useResult
  $Res call({int capacity, ChargeStatus chargeStatus, ChargeInfo? chargeInfo});

  $ChargeInfoCopyWith<$Res>? get chargeInfo;
}

/// @nodoc
class _$BatteryStatusCopyWithImpl<$Res, $Val extends BatteryStatus>
    implements $BatteryStatusCopyWith<$Res> {
  _$BatteryStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? capacity = null,
    Object? chargeStatus = null,
    Object? chargeInfo = freezed,
  }) {
    return _then(
      _value.copyWith(
            capacity: null == capacity
                ? _value.capacity
                : capacity // ignore: cast_nullable_to_non_nullable
                      as int,
            chargeStatus: null == chargeStatus
                ? _value.chargeStatus
                : chargeStatus // ignore: cast_nullable_to_non_nullable
                      as ChargeStatus,
            chargeInfo: freezed == chargeInfo
                ? _value.chargeInfo
                : chargeInfo // ignore: cast_nullable_to_non_nullable
                      as ChargeInfo?,
          )
          as $Val,
    );
  }

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChargeInfoCopyWith<$Res>? get chargeInfo {
    if (_value.chargeInfo == null) {
      return null;
    }

    return $ChargeInfoCopyWith<$Res>(_value.chargeInfo!, (value) {
      return _then(_value.copyWith(chargeInfo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BatteryStatusImplCopyWith<$Res>
    implements $BatteryStatusCopyWith<$Res> {
  factory _$$BatteryStatusImplCopyWith(
    _$BatteryStatusImpl value,
    $Res Function(_$BatteryStatusImpl) then,
  ) = __$$BatteryStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int capacity, ChargeStatus chargeStatus, ChargeInfo? chargeInfo});

  @override
  $ChargeInfoCopyWith<$Res>? get chargeInfo;
}

/// @nodoc
class __$$BatteryStatusImplCopyWithImpl<$Res>
    extends _$BatteryStatusCopyWithImpl<$Res, _$BatteryStatusImpl>
    implements _$$BatteryStatusImplCopyWith<$Res> {
  __$$BatteryStatusImplCopyWithImpl(
    _$BatteryStatusImpl _value,
    $Res Function(_$BatteryStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? capacity = null,
    Object? chargeStatus = null,
    Object? chargeInfo = freezed,
  }) {
    return _then(
      _$BatteryStatusImpl(
        capacity: null == capacity
            ? _value.capacity
            : capacity // ignore: cast_nullable_to_non_nullable
                  as int,
        chargeStatus: null == chargeStatus
            ? _value.chargeStatus
            : chargeStatus // ignore: cast_nullable_to_non_nullable
                  as ChargeStatus,
        chargeInfo: freezed == chargeInfo
            ? _value.chargeInfo
            : chargeInfo // ignore: cast_nullable_to_non_nullable
                  as ChargeInfo?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BatteryStatusImpl implements _BatteryStatus {
  const _$BatteryStatusImpl({
    required this.capacity,
    this.chargeStatus = ChargeStatus.unknown,
    this.chargeInfo,
  });

  factory _$BatteryStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$BatteryStatusImplFromJson(json);

  @override
  final int capacity;
  @override
  @JsonKey()
  final ChargeStatus chargeStatus;
  @override
  final ChargeInfo? chargeInfo;

  @override
  String toString() {
    return 'BatteryStatus(capacity: $capacity, chargeStatus: $chargeStatus, chargeInfo: $chargeInfo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BatteryStatusImpl &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.chargeStatus, chargeStatus) ||
                other.chargeStatus == chargeStatus) &&
            (identical(other.chargeInfo, chargeInfo) ||
                other.chargeInfo == chargeInfo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, capacity, chargeStatus, chargeInfo);

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BatteryStatusImplCopyWith<_$BatteryStatusImpl> get copyWith =>
      __$$BatteryStatusImplCopyWithImpl<_$BatteryStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BatteryStatusImplToJson(this);
  }
}

abstract class _BatteryStatus implements BatteryStatus {
  const factory _BatteryStatus({
    required final int capacity,
    final ChargeStatus chargeStatus,
    final ChargeInfo? chargeInfo,
  }) = _$BatteryStatusImpl;

  factory _BatteryStatus.fromJson(Map<String, dynamic> json) =
      _$BatteryStatusImpl.fromJson;

  @override
  int get capacity;
  @override
  ChargeStatus get chargeStatus;
  @override
  ChargeInfo? get chargeInfo;

  /// Create a copy of BatteryStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BatteryStatusImplCopyWith<_$BatteryStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppInfo _$AppInfoFromJson(Map<String, dynamic> json) {
  return _AppInfo.fromJson(json);
}

/// @nodoc
mixin _$AppInfo {
  String get packageName => throw _privateConstructorUsedError;
  List<int> get fingerprint => throw _privateConstructorUsedError;
  int get versionCode => throw _privateConstructorUsedError;
  bool get canRemove => throw _privateConstructorUsedError;
  String get appName => throw _privateConstructorUsedError;

  /// Serializes this AppInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppInfoCopyWith<AppInfo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppInfoCopyWith<$Res> {
  factory $AppInfoCopyWith(AppInfo value, $Res Function(AppInfo) then) =
      _$AppInfoCopyWithImpl<$Res, AppInfo>;
  @useResult
  $Res call({
    String packageName,
    List<int> fingerprint,
    int versionCode,
    bool canRemove,
    String appName,
  });
}

/// @nodoc
class _$AppInfoCopyWithImpl<$Res, $Val extends AppInfo>
    implements $AppInfoCopyWith<$Res> {
  _$AppInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? packageName = null,
    Object? fingerprint = null,
    Object? versionCode = null,
    Object? canRemove = null,
    Object? appName = null,
  }) {
    return _then(
      _value.copyWith(
            packageName: null == packageName
                ? _value.packageName
                : packageName // ignore: cast_nullable_to_non_nullable
                      as String,
            fingerprint: null == fingerprint
                ? _value.fingerprint
                : fingerprint // ignore: cast_nullable_to_non_nullable
                      as List<int>,
            versionCode: null == versionCode
                ? _value.versionCode
                : versionCode // ignore: cast_nullable_to_non_nullable
                      as int,
            canRemove: null == canRemove
                ? _value.canRemove
                : canRemove // ignore: cast_nullable_to_non_nullable
                      as bool,
            appName: null == appName
                ? _value.appName
                : appName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppInfoImplCopyWith<$Res> implements $AppInfoCopyWith<$Res> {
  factory _$$AppInfoImplCopyWith(
    _$AppInfoImpl value,
    $Res Function(_$AppInfoImpl) then,
  ) = __$$AppInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String packageName,
    List<int> fingerprint,
    int versionCode,
    bool canRemove,
    String appName,
  });
}

/// @nodoc
class __$$AppInfoImplCopyWithImpl<$Res>
    extends _$AppInfoCopyWithImpl<$Res, _$AppInfoImpl>
    implements _$$AppInfoImplCopyWith<$Res> {
  __$$AppInfoImplCopyWithImpl(
    _$AppInfoImpl _value,
    $Res Function(_$AppInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? packageName = null,
    Object? fingerprint = null,
    Object? versionCode = null,
    Object? canRemove = null,
    Object? appName = null,
  }) {
    return _then(
      _$AppInfoImpl(
        packageName: null == packageName
            ? _value.packageName
            : packageName // ignore: cast_nullable_to_non_nullable
                  as String,
        fingerprint: null == fingerprint
            ? _value._fingerprint
            : fingerprint // ignore: cast_nullable_to_non_nullable
                  as List<int>,
        versionCode: null == versionCode
            ? _value.versionCode
            : versionCode // ignore: cast_nullable_to_non_nullable
                  as int,
        canRemove: null == canRemove
            ? _value.canRemove
            : canRemove // ignore: cast_nullable_to_non_nullable
                  as bool,
        appName: null == appName
            ? _value.appName
            : appName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppInfoImpl implements _AppInfo {
  const _$AppInfoImpl({
    required this.packageName,
    final List<int> fingerprint = const <int>[],
    this.versionCode = 0,
    this.canRemove = false,
    required this.appName,
  }) : _fingerprint = fingerprint;

  factory _$AppInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppInfoImplFromJson(json);

  @override
  final String packageName;
  final List<int> _fingerprint;
  @override
  @JsonKey()
  List<int> get fingerprint {
    if (_fingerprint is EqualUnmodifiableListView) return _fingerprint;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fingerprint);
  }

  @override
  @JsonKey()
  final int versionCode;
  @override
  @JsonKey()
  final bool canRemove;
  @override
  final String appName;

  @override
  String toString() {
    return 'AppInfo(packageName: $packageName, fingerprint: $fingerprint, versionCode: $versionCode, canRemove: $canRemove, appName: $appName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppInfoImpl &&
            (identical(other.packageName, packageName) ||
                other.packageName == packageName) &&
            const DeepCollectionEquality().equals(
              other._fingerprint,
              _fingerprint,
            ) &&
            (identical(other.versionCode, versionCode) ||
                other.versionCode == versionCode) &&
            (identical(other.canRemove, canRemove) ||
                other.canRemove == canRemove) &&
            (identical(other.appName, appName) || other.appName == appName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    packageName,
    const DeepCollectionEquality().hash(_fingerprint),
    versionCode,
    canRemove,
    appName,
  );

  /// Create a copy of AppInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppInfoImplCopyWith<_$AppInfoImpl> get copyWith =>
      __$$AppInfoImplCopyWithImpl<_$AppInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppInfoImplToJson(this);
  }
}

abstract class _AppInfo implements AppInfo {
  const factory _AppInfo({
    required final String packageName,
    final List<int> fingerprint,
    final int versionCode,
    final bool canRemove,
    required final String appName,
  }) = _$AppInfoImpl;

  factory _AppInfo.fromJson(Map<String, dynamic> json) = _$AppInfoImpl.fromJson;

  @override
  String get packageName;
  @override
  List<int> get fingerprint;
  @override
  int get versionCode;
  @override
  bool get canRemove;
  @override
  String get appName;

  /// Create a copy of AppInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppInfoImplCopyWith<_$AppInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StorageInfo _$StorageInfoFromJson(Map<String, dynamic> json) {
  return _StorageInfo.fromJson(json);
}

/// @nodoc
mixin _$StorageInfo {
  int get used => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Serializes this StorageInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StorageInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StorageInfoCopyWith<StorageInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StorageInfoCopyWith<$Res> {
  factory $StorageInfoCopyWith(
    StorageInfo value,
    $Res Function(StorageInfo) then,
  ) = _$StorageInfoCopyWithImpl<$Res, StorageInfo>;
  @useResult
  $Res call({int used, int total});
}

/// @nodoc
class _$StorageInfoCopyWithImpl<$Res, $Val extends StorageInfo>
    implements $StorageInfoCopyWith<$Res> {
  _$StorageInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StorageInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? used = null, Object? total = null}) {
    return _then(
      _value.copyWith(
            used: null == used
                ? _value.used
                : used // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StorageInfoImplCopyWith<$Res>
    implements $StorageInfoCopyWith<$Res> {
  factory _$$StorageInfoImplCopyWith(
    _$StorageInfoImpl value,
    $Res Function(_$StorageInfoImpl) then,
  ) = __$$StorageInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int used, int total});
}

/// @nodoc
class __$$StorageInfoImplCopyWithImpl<$Res>
    extends _$StorageInfoCopyWithImpl<$Res, _$StorageInfoImpl>
    implements _$$StorageInfoImplCopyWith<$Res> {
  __$$StorageInfoImplCopyWithImpl(
    _$StorageInfoImpl _value,
    $Res Function(_$StorageInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StorageInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? used = null, Object? total = null}) {
    return _then(
      _$StorageInfoImpl(
        used: null == used
            ? _value.used
            : used // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StorageInfoImpl implements _StorageInfo {
  const _$StorageInfoImpl({required this.used, required this.total});

  factory _$StorageInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$StorageInfoImplFromJson(json);

  @override
  final int used;
  @override
  final int total;

  @override
  String toString() {
    return 'StorageInfo(used: $used, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StorageInfoImpl &&
            (identical(other.used, used) || other.used == used) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, used, total);

  /// Create a copy of StorageInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StorageInfoImplCopyWith<_$StorageInfoImpl> get copyWith =>
      __$$StorageInfoImplCopyWithImpl<_$StorageInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StorageInfoImplToJson(this);
  }
}

abstract class _StorageInfo implements StorageInfo {
  const factory _StorageInfo({
    required final int used,
    required final int total,
  }) = _$StorageInfoImpl;

  factory _StorageInfo.fromJson(Map<String, dynamic> json) =
      _$StorageInfoImpl.fromJson;

  @override
  int get used;
  @override
  int get total;

  /// Create a copy of StorageInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StorageInfoImplCopyWith<_$StorageInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) {
  return _SystemInfo.fromJson(json);
}

/// @nodoc
mixin _$SystemInfo {
  String get serialNumber => throw _privateConstructorUsedError;
  String get firmwareVersion => throw _privateConstructorUsedError;
  String get imei => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  StorageInfo? get storageInfo => throw _privateConstructorUsedError;

  /// Serializes this SystemInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemInfoCopyWith<SystemInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemInfoCopyWith<$Res> {
  factory $SystemInfoCopyWith(
    SystemInfo value,
    $Res Function(SystemInfo) then,
  ) = _$SystemInfoCopyWithImpl<$Res, SystemInfo>;
  @useResult
  $Res call({
    String serialNumber,
    String firmwareVersion,
    String imei,
    String model,
    StorageInfo? storageInfo,
  });

  $StorageInfoCopyWith<$Res>? get storageInfo;
}

/// @nodoc
class _$SystemInfoCopyWithImpl<$Res, $Val extends SystemInfo>
    implements $SystemInfoCopyWith<$Res> {
  _$SystemInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNumber = null,
    Object? firmwareVersion = null,
    Object? imei = null,
    Object? model = null,
    Object? storageInfo = freezed,
  }) {
    return _then(
      _value.copyWith(
            serialNumber: null == serialNumber
                ? _value.serialNumber
                : serialNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            firmwareVersion: null == firmwareVersion
                ? _value.firmwareVersion
                : firmwareVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            imei: null == imei
                ? _value.imei
                : imei // ignore: cast_nullable_to_non_nullable
                      as String,
            model: null == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String,
            storageInfo: freezed == storageInfo
                ? _value.storageInfo
                : storageInfo // ignore: cast_nullable_to_non_nullable
                      as StorageInfo?,
          )
          as $Val,
    );
  }

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StorageInfoCopyWith<$Res>? get storageInfo {
    if (_value.storageInfo == null) {
      return null;
    }

    return $StorageInfoCopyWith<$Res>(_value.storageInfo!, (value) {
      return _then(_value.copyWith(storageInfo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SystemInfoImplCopyWith<$Res>
    implements $SystemInfoCopyWith<$Res> {
  factory _$$SystemInfoImplCopyWith(
    _$SystemInfoImpl value,
    $Res Function(_$SystemInfoImpl) then,
  ) = __$$SystemInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String serialNumber,
    String firmwareVersion,
    String imei,
    String model,
    StorageInfo? storageInfo,
  });

  @override
  $StorageInfoCopyWith<$Res>? get storageInfo;
}

/// @nodoc
class __$$SystemInfoImplCopyWithImpl<$Res>
    extends _$SystemInfoCopyWithImpl<$Res, _$SystemInfoImpl>
    implements _$$SystemInfoImplCopyWith<$Res> {
  __$$SystemInfoImplCopyWithImpl(
    _$SystemInfoImpl _value,
    $Res Function(_$SystemInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNumber = null,
    Object? firmwareVersion = null,
    Object? imei = null,
    Object? model = null,
    Object? storageInfo = freezed,
  }) {
    return _then(
      _$SystemInfoImpl(
        serialNumber: null == serialNumber
            ? _value.serialNumber
            : serialNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        firmwareVersion: null == firmwareVersion
            ? _value.firmwareVersion
            : firmwareVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        imei: null == imei
            ? _value.imei
            : imei // ignore: cast_nullable_to_non_nullable
                  as String,
        model: null == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String,
        storageInfo: freezed == storageInfo
            ? _value.storageInfo
            : storageInfo // ignore: cast_nullable_to_non_nullable
                  as StorageInfo?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SystemInfoImpl implements _SystemInfo {
  const _$SystemInfoImpl({
    required this.serialNumber,
    required this.firmwareVersion,
    required this.imei,
    required this.model,
    this.storageInfo,
  });

  factory _$SystemInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$SystemInfoImplFromJson(json);

  @override
  final String serialNumber;
  @override
  final String firmwareVersion;
  @override
  final String imei;
  @override
  final String model;
  @override
  final StorageInfo? storageInfo;

  @override
  String toString() {
    return 'SystemInfo(serialNumber: $serialNumber, firmwareVersion: $firmwareVersion, imei: $imei, model: $model, storageInfo: $storageInfo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemInfoImpl &&
            (identical(other.serialNumber, serialNumber) ||
                other.serialNumber == serialNumber) &&
            (identical(other.firmwareVersion, firmwareVersion) ||
                other.firmwareVersion == firmwareVersion) &&
            (identical(other.imei, imei) || other.imei == imei) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.storageInfo, storageInfo) ||
                other.storageInfo == storageInfo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    serialNumber,
    firmwareVersion,
    imei,
    model,
    storageInfo,
  );

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemInfoImplCopyWith<_$SystemInfoImpl> get copyWith =>
      __$$SystemInfoImplCopyWithImpl<_$SystemInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SystemInfoImplToJson(this);
  }
}

abstract class _SystemInfo implements SystemInfo {
  const factory _SystemInfo({
    required final String serialNumber,
    required final String firmwareVersion,
    required final String imei,
    required final String model,
    final StorageInfo? storageInfo,
  }) = _$SystemInfoImpl;

  factory _SystemInfo.fromJson(Map<String, dynamic> json) =
      _$SystemInfoImpl.fromJson;

  @override
  String get serialNumber;
  @override
  String get firmwareVersion;
  @override
  String get imei;
  @override
  String get model;
  @override
  StorageInfo? get storageInfo;

  /// Create a copy of SystemInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemInfoImplCopyWith<_$SystemInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WatchfaceInfo _$WatchfaceInfoFromJson(Map<String, dynamic> json) {
  return _WatchfaceInfo.fromJson(json);
}

/// @nodoc
mixin _$WatchfaceInfo {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  bool get isCurrent => throw _privateConstructorUsedError;
  bool get canRemove => throw _privateConstructorUsedError;
  int get versionCode => throw _privateConstructorUsedError;
  bool get canEdit => throw _privateConstructorUsedError;
  String get backgroundColor => throw _privateConstructorUsedError;
  String get backgroundImage => throw _privateConstructorUsedError;
  String get style => throw _privateConstructorUsedError;
  List<String> get backgroundImageList => throw _privateConstructorUsedError;

  /// Serializes this WatchfaceInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WatchfaceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WatchfaceInfoCopyWith<WatchfaceInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WatchfaceInfoCopyWith<$Res> {
  factory $WatchfaceInfoCopyWith(
    WatchfaceInfo value,
    $Res Function(WatchfaceInfo) then,
  ) = _$WatchfaceInfoCopyWithImpl<$Res, WatchfaceInfo>;
  @useResult
  $Res call({
    String id,
    String name,
    bool isCurrent,
    bool canRemove,
    int versionCode,
    bool canEdit,
    String backgroundColor,
    String backgroundImage,
    String style,
    List<String> backgroundImageList,
  });
}

/// @nodoc
class _$WatchfaceInfoCopyWithImpl<$Res, $Val extends WatchfaceInfo>
    implements $WatchfaceInfoCopyWith<$Res> {
  _$WatchfaceInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WatchfaceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isCurrent = null,
    Object? canRemove = null,
    Object? versionCode = null,
    Object? canEdit = null,
    Object? backgroundColor = null,
    Object? backgroundImage = null,
    Object? style = null,
    Object? backgroundImageList = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            isCurrent: null == isCurrent
                ? _value.isCurrent
                : isCurrent // ignore: cast_nullable_to_non_nullable
                      as bool,
            canRemove: null == canRemove
                ? _value.canRemove
                : canRemove // ignore: cast_nullable_to_non_nullable
                      as bool,
            versionCode: null == versionCode
                ? _value.versionCode
                : versionCode // ignore: cast_nullable_to_non_nullable
                      as int,
            canEdit: null == canEdit
                ? _value.canEdit
                : canEdit // ignore: cast_nullable_to_non_nullable
                      as bool,
            backgroundColor: null == backgroundColor
                ? _value.backgroundColor
                : backgroundColor // ignore: cast_nullable_to_non_nullable
                      as String,
            backgroundImage: null == backgroundImage
                ? _value.backgroundImage
                : backgroundImage // ignore: cast_nullable_to_non_nullable
                      as String,
            style: null == style
                ? _value.style
                : style // ignore: cast_nullable_to_non_nullable
                      as String,
            backgroundImageList: null == backgroundImageList
                ? _value.backgroundImageList
                : backgroundImageList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WatchfaceInfoImplCopyWith<$Res>
    implements $WatchfaceInfoCopyWith<$Res> {
  factory _$$WatchfaceInfoImplCopyWith(
    _$WatchfaceInfoImpl value,
    $Res Function(_$WatchfaceInfoImpl) then,
  ) = __$$WatchfaceInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    bool isCurrent,
    bool canRemove,
    int versionCode,
    bool canEdit,
    String backgroundColor,
    String backgroundImage,
    String style,
    List<String> backgroundImageList,
  });
}

/// @nodoc
class __$$WatchfaceInfoImplCopyWithImpl<$Res>
    extends _$WatchfaceInfoCopyWithImpl<$Res, _$WatchfaceInfoImpl>
    implements _$$WatchfaceInfoImplCopyWith<$Res> {
  __$$WatchfaceInfoImplCopyWithImpl(
    _$WatchfaceInfoImpl _value,
    $Res Function(_$WatchfaceInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WatchfaceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isCurrent = null,
    Object? canRemove = null,
    Object? versionCode = null,
    Object? canEdit = null,
    Object? backgroundColor = null,
    Object? backgroundImage = null,
    Object? style = null,
    Object? backgroundImageList = null,
  }) {
    return _then(
      _$WatchfaceInfoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        isCurrent: null == isCurrent
            ? _value.isCurrent
            : isCurrent // ignore: cast_nullable_to_non_nullable
                  as bool,
        canRemove: null == canRemove
            ? _value.canRemove
            : canRemove // ignore: cast_nullable_to_non_nullable
                  as bool,
        versionCode: null == versionCode
            ? _value.versionCode
            : versionCode // ignore: cast_nullable_to_non_nullable
                  as int,
        canEdit: null == canEdit
            ? _value.canEdit
            : canEdit // ignore: cast_nullable_to_non_nullable
                  as bool,
        backgroundColor: null == backgroundColor
            ? _value.backgroundColor
            : backgroundColor // ignore: cast_nullable_to_non_nullable
                  as String,
        backgroundImage: null == backgroundImage
            ? _value.backgroundImage
            : backgroundImage // ignore: cast_nullable_to_non_nullable
                  as String,
        style: null == style
            ? _value.style
            : style // ignore: cast_nullable_to_non_nullable
                  as String,
        backgroundImageList: null == backgroundImageList
            ? _value._backgroundImageList
            : backgroundImageList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WatchfaceInfoImpl implements _WatchfaceInfo {
  const _$WatchfaceInfoImpl({
    required this.id,
    required this.name,
    this.isCurrent = false,
    this.canRemove = false,
    this.versionCode = 0,
    this.canEdit = false,
    this.backgroundColor = '',
    this.backgroundImage = '',
    this.style = '',
    final List<String> backgroundImageList = const <String>[],
  }) : _backgroundImageList = backgroundImageList;

  factory _$WatchfaceInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$WatchfaceInfoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey()
  final bool isCurrent;
  @override
  @JsonKey()
  final bool canRemove;
  @override
  @JsonKey()
  final int versionCode;
  @override
  @JsonKey()
  final bool canEdit;
  @override
  @JsonKey()
  final String backgroundColor;
  @override
  @JsonKey()
  final String backgroundImage;
  @override
  @JsonKey()
  final String style;
  final List<String> _backgroundImageList;
  @override
  @JsonKey()
  List<String> get backgroundImageList {
    if (_backgroundImageList is EqualUnmodifiableListView)
      return _backgroundImageList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_backgroundImageList);
  }

  @override
  String toString() {
    return 'WatchfaceInfo(id: $id, name: $name, isCurrent: $isCurrent, canRemove: $canRemove, versionCode: $versionCode, canEdit: $canEdit, backgroundColor: $backgroundColor, backgroundImage: $backgroundImage, style: $style, backgroundImageList: $backgroundImageList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WatchfaceInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.isCurrent, isCurrent) ||
                other.isCurrent == isCurrent) &&
            (identical(other.canRemove, canRemove) ||
                other.canRemove == canRemove) &&
            (identical(other.versionCode, versionCode) ||
                other.versionCode == versionCode) &&
            (identical(other.canEdit, canEdit) || other.canEdit == canEdit) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.backgroundImage, backgroundImage) ||
                other.backgroundImage == backgroundImage) &&
            (identical(other.style, style) || other.style == style) &&
            const DeepCollectionEquality().equals(
              other._backgroundImageList,
              _backgroundImageList,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    isCurrent,
    canRemove,
    versionCode,
    canEdit,
    backgroundColor,
    backgroundImage,
    style,
    const DeepCollectionEquality().hash(_backgroundImageList),
  );

  /// Create a copy of WatchfaceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WatchfaceInfoImplCopyWith<_$WatchfaceInfoImpl> get copyWith =>
      __$$WatchfaceInfoImplCopyWithImpl<_$WatchfaceInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WatchfaceInfoImplToJson(this);
  }
}

abstract class _WatchfaceInfo implements WatchfaceInfo {
  const factory _WatchfaceInfo({
    required final String id,
    required final String name,
    final bool isCurrent,
    final bool canRemove,
    final int versionCode,
    final bool canEdit,
    final String backgroundColor,
    final String backgroundImage,
    final String style,
    final List<String> backgroundImageList,
  }) = _$WatchfaceInfoImpl;

  factory _WatchfaceInfo.fromJson(Map<String, dynamic> json) =
      _$WatchfaceInfoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  bool get isCurrent;
  @override
  bool get canRemove;
  @override
  int get versionCode;
  @override
  bool get canEdit;
  @override
  String get backgroundColor;
  @override
  String get backgroundImage;
  @override
  String get style;
  @override
  List<String> get backgroundImageList;

  /// Create a copy of WatchfaceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WatchfaceInfoImplCopyWith<_$WatchfaceInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
