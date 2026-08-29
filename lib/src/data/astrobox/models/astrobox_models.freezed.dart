// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'astrobox_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AstroBoxIndexItem _$AstroBoxIndexItemFromJson(Map<String, dynamic> json) {
  return _AstroBoxIndexItem.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxIndexItem {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'restype')
  AstroBoxResourceType get type => throw _privateConstructorUsedError;
  String get repoOwner => throw _privateConstructorUsedError;
  String get repoName => throw _privateConstructorUsedError;
  String get repoCommitHash => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get cover => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_vendors')
  List<String> get deviceVendors => throw _privateConstructorUsedError;
  List<String> get devices => throw _privateConstructorUsedError;
  @JsonKey(name: 'paid_type')
  AstroBoxPaidType get paidType => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxIndexItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxIndexItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxIndexItemCopyWith<AstroBoxIndexItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxIndexItemCopyWith<$Res> {
  factory $AstroBoxIndexItemCopyWith(
    AstroBoxIndexItem value,
    $Res Function(AstroBoxIndexItem) then,
  ) = _$AstroBoxIndexItemCopyWithImpl<$Res, AstroBoxIndexItem>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'restype') AstroBoxResourceType type,
    String repoOwner,
    String repoName,
    String repoCommitHash,
    String icon,
    String cover,
    List<String> tags,
    @JsonKey(name: 'device_vendors') List<String> deviceVendors,
    List<String> devices,
    @JsonKey(name: 'paid_type') AstroBoxPaidType paidType,
  });
}

/// @nodoc
class _$AstroBoxIndexItemCopyWithImpl<$Res, $Val extends AstroBoxIndexItem>
    implements $AstroBoxIndexItemCopyWith<$Res> {
  _$AstroBoxIndexItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxIndexItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? repoOwner = null,
    Object? repoName = null,
    Object? repoCommitHash = null,
    Object? icon = null,
    Object? cover = null,
    Object? tags = null,
    Object? deviceVendors = null,
    Object? devices = null,
    Object? paidType = null,
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
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as AstroBoxResourceType,
            repoOwner: null == repoOwner
                ? _value.repoOwner
                : repoOwner // ignore: cast_nullable_to_non_nullable
                      as String,
            repoName: null == repoName
                ? _value.repoName
                : repoName // ignore: cast_nullable_to_non_nullable
                      as String,
            repoCommitHash: null == repoCommitHash
                ? _value.repoCommitHash
                : repoCommitHash // ignore: cast_nullable_to_non_nullable
                      as String,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            cover: null == cover
                ? _value.cover
                : cover // ignore: cast_nullable_to_non_nullable
                      as String,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            deviceVendors: null == deviceVendors
                ? _value.deviceVendors
                : deviceVendors // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            devices: null == devices
                ? _value.devices
                : devices // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            paidType: null == paidType
                ? _value.paidType
                : paidType // ignore: cast_nullable_to_non_nullable
                      as AstroBoxPaidType,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxIndexItemImplCopyWith<$Res>
    implements $AstroBoxIndexItemCopyWith<$Res> {
  factory _$$AstroBoxIndexItemImplCopyWith(
    _$AstroBoxIndexItemImpl value,
    $Res Function(_$AstroBoxIndexItemImpl) then,
  ) = __$$AstroBoxIndexItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'restype') AstroBoxResourceType type,
    String repoOwner,
    String repoName,
    String repoCommitHash,
    String icon,
    String cover,
    List<String> tags,
    @JsonKey(name: 'device_vendors') List<String> deviceVendors,
    List<String> devices,
    @JsonKey(name: 'paid_type') AstroBoxPaidType paidType,
  });
}

/// @nodoc
class __$$AstroBoxIndexItemImplCopyWithImpl<$Res>
    extends _$AstroBoxIndexItemCopyWithImpl<$Res, _$AstroBoxIndexItemImpl>
    implements _$$AstroBoxIndexItemImplCopyWith<$Res> {
  __$$AstroBoxIndexItemImplCopyWithImpl(
    _$AstroBoxIndexItemImpl _value,
    $Res Function(_$AstroBoxIndexItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxIndexItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? repoOwner = null,
    Object? repoName = null,
    Object? repoCommitHash = null,
    Object? icon = null,
    Object? cover = null,
    Object? tags = null,
    Object? deviceVendors = null,
    Object? devices = null,
    Object? paidType = null,
  }) {
    return _then(
      _$AstroBoxIndexItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as AstroBoxResourceType,
        repoOwner: null == repoOwner
            ? _value.repoOwner
            : repoOwner // ignore: cast_nullable_to_non_nullable
                  as String,
        repoName: null == repoName
            ? _value.repoName
            : repoName // ignore: cast_nullable_to_non_nullable
                  as String,
        repoCommitHash: null == repoCommitHash
            ? _value.repoCommitHash
            : repoCommitHash // ignore: cast_nullable_to_non_nullable
                  as String,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        cover: null == cover
            ? _value.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        deviceVendors: null == deviceVendors
            ? _value._deviceVendors
            : deviceVendors // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        devices: null == devices
            ? _value._devices
            : devices // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        paidType: null == paidType
            ? _value.paidType
            : paidType // ignore: cast_nullable_to_non_nullable
                  as AstroBoxPaidType,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxIndexItemImpl implements _AstroBoxIndexItem {
  const _$AstroBoxIndexItemImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'restype') required this.type,
    required this.repoOwner,
    required this.repoName,
    required this.repoCommitHash,
    required this.icon,
    required this.cover,
    final List<String> tags = const [],
    @JsonKey(name: 'device_vendors')
    final List<String> deviceVendors = const [],
    final List<String> devices = const [],
    @JsonKey(name: 'paid_type') required this.paidType,
  }) : _tags = tags,
       _deviceVendors = deviceVendors,
       _devices = devices;

  factory _$AstroBoxIndexItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxIndexItemImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'restype')
  final AstroBoxResourceType type;
  @override
  final String repoOwner;
  @override
  final String repoName;
  @override
  final String repoCommitHash;
  @override
  final String icon;
  @override
  final String cover;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<String> _deviceVendors;
  @override
  @JsonKey(name: 'device_vendors')
  List<String> get deviceVendors {
    if (_deviceVendors is EqualUnmodifiableListView) return _deviceVendors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_deviceVendors);
  }

  final List<String> _devices;
  @override
  @JsonKey()
  List<String> get devices {
    if (_devices is EqualUnmodifiableListView) return _devices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_devices);
  }

  @override
  @JsonKey(name: 'paid_type')
  final AstroBoxPaidType paidType;

  @override
  String toString() {
    return 'AstroBoxIndexItem(id: $id, name: $name, type: $type, repoOwner: $repoOwner, repoName: $repoName, repoCommitHash: $repoCommitHash, icon: $icon, cover: $cover, tags: $tags, deviceVendors: $deviceVendors, devices: $devices, paidType: $paidType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxIndexItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.repoOwner, repoOwner) ||
                other.repoOwner == repoOwner) &&
            (identical(other.repoName, repoName) ||
                other.repoName == repoName) &&
            (identical(other.repoCommitHash, repoCommitHash) ||
                other.repoCommitHash == repoCommitHash) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.cover, cover) || other.cover == cover) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(
              other._deviceVendors,
              _deviceVendors,
            ) &&
            const DeepCollectionEquality().equals(other._devices, _devices) &&
            (identical(other.paidType, paidType) ||
                other.paidType == paidType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    repoOwner,
    repoName,
    repoCommitHash,
    icon,
    cover,
    const DeepCollectionEquality().hash(_tags),
    const DeepCollectionEquality().hash(_deviceVendors),
    const DeepCollectionEquality().hash(_devices),
    paidType,
  );

  /// Create a copy of AstroBoxIndexItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxIndexItemImplCopyWith<_$AstroBoxIndexItemImpl> get copyWith =>
      __$$AstroBoxIndexItemImplCopyWithImpl<_$AstroBoxIndexItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxIndexItemImplToJson(this);
  }
}

abstract class _AstroBoxIndexItem implements AstroBoxIndexItem {
  const factory _AstroBoxIndexItem({
    required final String id,
    required final String name,
    @JsonKey(name: 'restype') required final AstroBoxResourceType type,
    required final String repoOwner,
    required final String repoName,
    required final String repoCommitHash,
    required final String icon,
    required final String cover,
    final List<String> tags,
    @JsonKey(name: 'device_vendors') final List<String> deviceVendors,
    final List<String> devices,
    @JsonKey(name: 'paid_type') required final AstroBoxPaidType paidType,
  }) = _$AstroBoxIndexItemImpl;

  factory _AstroBoxIndexItem.fromJson(Map<String, dynamic> json) =
      _$AstroBoxIndexItemImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'restype')
  AstroBoxResourceType get type;
  @override
  String get repoOwner;
  @override
  String get repoName;
  @override
  String get repoCommitHash;
  @override
  String get icon;
  @override
  String get cover;
  @override
  List<String> get tags;
  @override
  @JsonKey(name: 'device_vendors')
  List<String> get deviceVendors;
  @override
  List<String> get devices;
  @override
  @JsonKey(name: 'paid_type')
  AstroBoxPaidType get paidType;

  /// Create a copy of AstroBoxIndexItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxIndexItemImplCopyWith<_$AstroBoxIndexItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AstroBoxManifest _$AstroBoxManifestFromJson(Map<String, dynamic> json) {
  return _AstroBoxManifest.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxManifest {
  AstroBoxManifestItem get item => throw _privateConstructorUsedError;
  List<AstroBoxManifestLink> get links => throw _privateConstructorUsedError;
  Map<String, AstroBoxManifestDownload> get downloads =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> get ext => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxManifest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxManifestCopyWith<AstroBoxManifest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxManifestCopyWith<$Res> {
  factory $AstroBoxManifestCopyWith(
    AstroBoxManifest value,
    $Res Function(AstroBoxManifest) then,
  ) = _$AstroBoxManifestCopyWithImpl<$Res, AstroBoxManifest>;
  @useResult
  $Res call({
    AstroBoxManifestItem item,
    List<AstroBoxManifestLink> links,
    Map<String, AstroBoxManifestDownload> downloads,
    Map<String, dynamic> ext,
  });

  $AstroBoxManifestItemCopyWith<$Res> get item;
}

/// @nodoc
class _$AstroBoxManifestCopyWithImpl<$Res, $Val extends AstroBoxManifest>
    implements $AstroBoxManifestCopyWith<$Res> {
  _$AstroBoxManifestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? item = null,
    Object? links = null,
    Object? downloads = null,
    Object? ext = null,
  }) {
    return _then(
      _value.copyWith(
            item: null == item
                ? _value.item
                : item // ignore: cast_nullable_to_non_nullable
                      as AstroBoxManifestItem,
            links: null == links
                ? _value.links
                : links // ignore: cast_nullable_to_non_nullable
                      as List<AstroBoxManifestLink>,
            downloads: null == downloads
                ? _value.downloads
                : downloads // ignore: cast_nullable_to_non_nullable
                      as Map<String, AstroBoxManifestDownload>,
            ext: null == ext
                ? _value.ext
                : ext // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AstroBoxManifestItemCopyWith<$Res> get item {
    return $AstroBoxManifestItemCopyWith<$Res>(_value.item, (value) {
      return _then(_value.copyWith(item: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AstroBoxManifestImplCopyWith<$Res>
    implements $AstroBoxManifestCopyWith<$Res> {
  factory _$$AstroBoxManifestImplCopyWith(
    _$AstroBoxManifestImpl value,
    $Res Function(_$AstroBoxManifestImpl) then,
  ) = __$$AstroBoxManifestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AstroBoxManifestItem item,
    List<AstroBoxManifestLink> links,
    Map<String, AstroBoxManifestDownload> downloads,
    Map<String, dynamic> ext,
  });

  @override
  $AstroBoxManifestItemCopyWith<$Res> get item;
}

/// @nodoc
class __$$AstroBoxManifestImplCopyWithImpl<$Res>
    extends _$AstroBoxManifestCopyWithImpl<$Res, _$AstroBoxManifestImpl>
    implements _$$AstroBoxManifestImplCopyWith<$Res> {
  __$$AstroBoxManifestImplCopyWithImpl(
    _$AstroBoxManifestImpl _value,
    $Res Function(_$AstroBoxManifestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? item = null,
    Object? links = null,
    Object? downloads = null,
    Object? ext = null,
  }) {
    return _then(
      _$AstroBoxManifestImpl(
        item: null == item
            ? _value.item
            : item // ignore: cast_nullable_to_non_nullable
                  as AstroBoxManifestItem,
        links: null == links
            ? _value._links
            : links // ignore: cast_nullable_to_non_nullable
                  as List<AstroBoxManifestLink>,
        downloads: null == downloads
            ? _value._downloads
            : downloads // ignore: cast_nullable_to_non_nullable
                  as Map<String, AstroBoxManifestDownload>,
        ext: null == ext
            ? _value._ext
            : ext // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxManifestImpl implements _AstroBoxManifest {
  const _$AstroBoxManifestImpl({
    required this.item,
    final List<AstroBoxManifestLink> links = const [],
    final Map<String, AstroBoxManifestDownload> downloads = const {},
    final Map<String, dynamic> ext = const {},
  }) : _links = links,
       _downloads = downloads,
       _ext = ext;

  factory _$AstroBoxManifestImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxManifestImplFromJson(json);

  @override
  final AstroBoxManifestItem item;
  final List<AstroBoxManifestLink> _links;
  @override
  @JsonKey()
  List<AstroBoxManifestLink> get links {
    if (_links is EqualUnmodifiableListView) return _links;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_links);
  }

  final Map<String, AstroBoxManifestDownload> _downloads;
  @override
  @JsonKey()
  Map<String, AstroBoxManifestDownload> get downloads {
    if (_downloads is EqualUnmodifiableMapView) return _downloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_downloads);
  }

  final Map<String, dynamic> _ext;
  @override
  @JsonKey()
  Map<String, dynamic> get ext {
    if (_ext is EqualUnmodifiableMapView) return _ext;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_ext);
  }

  @override
  String toString() {
    return 'AstroBoxManifest(item: $item, links: $links, downloads: $downloads, ext: $ext)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxManifestImpl &&
            (identical(other.item, item) || other.item == item) &&
            const DeepCollectionEquality().equals(other._links, _links) &&
            const DeepCollectionEquality().equals(
              other._downloads,
              _downloads,
            ) &&
            const DeepCollectionEquality().equals(other._ext, _ext));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    item,
    const DeepCollectionEquality().hash(_links),
    const DeepCollectionEquality().hash(_downloads),
    const DeepCollectionEquality().hash(_ext),
  );

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxManifestImplCopyWith<_$AstroBoxManifestImpl> get copyWith =>
      __$$AstroBoxManifestImplCopyWithImpl<_$AstroBoxManifestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxManifestImplToJson(this);
  }
}

abstract class _AstroBoxManifest implements AstroBoxManifest {
  const factory _AstroBoxManifest({
    required final AstroBoxManifestItem item,
    final List<AstroBoxManifestLink> links,
    final Map<String, AstroBoxManifestDownload> downloads,
    final Map<String, dynamic> ext,
  }) = _$AstroBoxManifestImpl;

  factory _AstroBoxManifest.fromJson(Map<String, dynamic> json) =
      _$AstroBoxManifestImpl.fromJson;

  @override
  AstroBoxManifestItem get item;
  @override
  List<AstroBoxManifestLink> get links;
  @override
  Map<String, AstroBoxManifestDownload> get downloads;
  @override
  Map<String, dynamic> get ext;

  /// Create a copy of AstroBoxManifest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxManifestImplCopyWith<_$AstroBoxManifestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AstroBoxManifestItem _$AstroBoxManifestItemFromJson(Map<String, dynamic> json) {
  return _AstroBoxManifestItem.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxManifestItem {
  String get id => throw _privateConstructorUsedError;
  AstroBoxResourceType get restype => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get descriptionHtml => throw _privateConstructorUsedError;
  String? get descriptionBaseUrl => throw _privateConstructorUsedError;
  List<String> get preview => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get cover => throw _privateConstructorUsedError;
  AstroBoxPaidType? get paidType => throw _privateConstructorUsedError;
  List<AstroBoxManifestAuthor> get author => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxManifestItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxManifestItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxManifestItemCopyWith<AstroBoxManifestItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxManifestItemCopyWith<$Res> {
  factory $AstroBoxManifestItemCopyWith(
    AstroBoxManifestItem value,
    $Res Function(AstroBoxManifestItem) then,
  ) = _$AstroBoxManifestItemCopyWithImpl<$Res, AstroBoxManifestItem>;
  @useResult
  $Res call({
    String id,
    AstroBoxResourceType restype,
    String name,
    String description,
    String? descriptionHtml,
    String? descriptionBaseUrl,
    List<String> preview,
    String icon,
    String cover,
    AstroBoxPaidType? paidType,
    List<AstroBoxManifestAuthor> author,
  });
}

/// @nodoc
class _$AstroBoxManifestItemCopyWithImpl<
  $Res,
  $Val extends AstroBoxManifestItem
>
    implements $AstroBoxManifestItemCopyWith<$Res> {
  _$AstroBoxManifestItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxManifestItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? restype = null,
    Object? name = null,
    Object? description = null,
    Object? descriptionHtml = freezed,
    Object? descriptionBaseUrl = freezed,
    Object? preview = null,
    Object? icon = null,
    Object? cover = null,
    Object? paidType = freezed,
    Object? author = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            restype: null == restype
                ? _value.restype
                : restype // ignore: cast_nullable_to_non_nullable
                      as AstroBoxResourceType,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            descriptionHtml: freezed == descriptionHtml
                ? _value.descriptionHtml
                : descriptionHtml // ignore: cast_nullable_to_non_nullable
                      as String?,
            descriptionBaseUrl: freezed == descriptionBaseUrl
                ? _value.descriptionBaseUrl
                : descriptionBaseUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            preview: null == preview
                ? _value.preview
                : preview // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            cover: null == cover
                ? _value.cover
                : cover // ignore: cast_nullable_to_non_nullable
                      as String,
            paidType: freezed == paidType
                ? _value.paidType
                : paidType // ignore: cast_nullable_to_non_nullable
                      as AstroBoxPaidType?,
            author: null == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as List<AstroBoxManifestAuthor>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxManifestItemImplCopyWith<$Res>
    implements $AstroBoxManifestItemCopyWith<$Res> {
  factory _$$AstroBoxManifestItemImplCopyWith(
    _$AstroBoxManifestItemImpl value,
    $Res Function(_$AstroBoxManifestItemImpl) then,
  ) = __$$AstroBoxManifestItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    AstroBoxResourceType restype,
    String name,
    String description,
    String? descriptionHtml,
    String? descriptionBaseUrl,
    List<String> preview,
    String icon,
    String cover,
    AstroBoxPaidType? paidType,
    List<AstroBoxManifestAuthor> author,
  });
}

/// @nodoc
class __$$AstroBoxManifestItemImplCopyWithImpl<$Res>
    extends _$AstroBoxManifestItemCopyWithImpl<$Res, _$AstroBoxManifestItemImpl>
    implements _$$AstroBoxManifestItemImplCopyWith<$Res> {
  __$$AstroBoxManifestItemImplCopyWithImpl(
    _$AstroBoxManifestItemImpl _value,
    $Res Function(_$AstroBoxManifestItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxManifestItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? restype = null,
    Object? name = null,
    Object? description = null,
    Object? descriptionHtml = freezed,
    Object? descriptionBaseUrl = freezed,
    Object? preview = null,
    Object? icon = null,
    Object? cover = null,
    Object? paidType = freezed,
    Object? author = null,
  }) {
    return _then(
      _$AstroBoxManifestItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        restype: null == restype
            ? _value.restype
            : restype // ignore: cast_nullable_to_non_nullable
                  as AstroBoxResourceType,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        descriptionHtml: freezed == descriptionHtml
            ? _value.descriptionHtml
            : descriptionHtml // ignore: cast_nullable_to_non_nullable
                  as String?,
        descriptionBaseUrl: freezed == descriptionBaseUrl
            ? _value.descriptionBaseUrl
            : descriptionBaseUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        preview: null == preview
            ? _value._preview
            : preview // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        cover: null == cover
            ? _value.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String,
        paidType: freezed == paidType
            ? _value.paidType
            : paidType // ignore: cast_nullable_to_non_nullable
                  as AstroBoxPaidType?,
        author: null == author
            ? _value._author
            : author // ignore: cast_nullable_to_non_nullable
                  as List<AstroBoxManifestAuthor>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxManifestItemImpl implements _AstroBoxManifestItem {
  const _$AstroBoxManifestItemImpl({
    required this.id,
    required this.restype,
    required this.name,
    required this.description,
    this.descriptionHtml,
    this.descriptionBaseUrl,
    final List<String> preview = const [],
    required this.icon,
    required this.cover,
    this.paidType,
    final List<AstroBoxManifestAuthor> author = const [],
  }) : _preview = preview,
       _author = author;

  factory _$AstroBoxManifestItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxManifestItemImplFromJson(json);

  @override
  final String id;
  @override
  final AstroBoxResourceType restype;
  @override
  final String name;
  @override
  final String description;
  @override
  final String? descriptionHtml;
  @override
  final String? descriptionBaseUrl;
  final List<String> _preview;
  @override
  @JsonKey()
  List<String> get preview {
    if (_preview is EqualUnmodifiableListView) return _preview;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preview);
  }

  @override
  final String icon;
  @override
  final String cover;
  @override
  final AstroBoxPaidType? paidType;
  final List<AstroBoxManifestAuthor> _author;
  @override
  @JsonKey()
  List<AstroBoxManifestAuthor> get author {
    if (_author is EqualUnmodifiableListView) return _author;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_author);
  }

  @override
  String toString() {
    return 'AstroBoxManifestItem(id: $id, restype: $restype, name: $name, description: $description, descriptionHtml: $descriptionHtml, descriptionBaseUrl: $descriptionBaseUrl, preview: $preview, icon: $icon, cover: $cover, paidType: $paidType, author: $author)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxManifestItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.restype, restype) || other.restype == restype) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.descriptionHtml, descriptionHtml) ||
                other.descriptionHtml == descriptionHtml) &&
            (identical(other.descriptionBaseUrl, descriptionBaseUrl) ||
                other.descriptionBaseUrl == descriptionBaseUrl) &&
            const DeepCollectionEquality().equals(other._preview, _preview) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.cover, cover) || other.cover == cover) &&
            (identical(other.paidType, paidType) ||
                other.paidType == paidType) &&
            const DeepCollectionEquality().equals(other._author, _author));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    restype,
    name,
    description,
    descriptionHtml,
    descriptionBaseUrl,
    const DeepCollectionEquality().hash(_preview),
    icon,
    cover,
    paidType,
    const DeepCollectionEquality().hash(_author),
  );

  /// Create a copy of AstroBoxManifestItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxManifestItemImplCopyWith<_$AstroBoxManifestItemImpl>
  get copyWith =>
      __$$AstroBoxManifestItemImplCopyWithImpl<_$AstroBoxManifestItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxManifestItemImplToJson(this);
  }
}

abstract class _AstroBoxManifestItem implements AstroBoxManifestItem {
  const factory _AstroBoxManifestItem({
    required final String id,
    required final AstroBoxResourceType restype,
    required final String name,
    required final String description,
    final String? descriptionHtml,
    final String? descriptionBaseUrl,
    final List<String> preview,
    required final String icon,
    required final String cover,
    final AstroBoxPaidType? paidType,
    final List<AstroBoxManifestAuthor> author,
  }) = _$AstroBoxManifestItemImpl;

  factory _AstroBoxManifestItem.fromJson(Map<String, dynamic> json) =
      _$AstroBoxManifestItemImpl.fromJson;

  @override
  String get id;
  @override
  AstroBoxResourceType get restype;
  @override
  String get name;
  @override
  String get description;
  @override
  String? get descriptionHtml;
  @override
  String? get descriptionBaseUrl;
  @override
  List<String> get preview;
  @override
  String get icon;
  @override
  String get cover;
  @override
  AstroBoxPaidType? get paidType;
  @override
  List<AstroBoxManifestAuthor> get author;

  /// Create a copy of AstroBoxManifestItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxManifestItemImplCopyWith<_$AstroBoxManifestItemImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AstroBoxManifestAuthor _$AstroBoxManifestAuthorFromJson(
  Map<String, dynamic> json,
) {
  return _AstroBoxManifestAuthor.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxManifestAuthor {
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'bindABAccount')
  bool get bindAbAccount => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxManifestAuthor to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxManifestAuthor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxManifestAuthorCopyWith<AstroBoxManifestAuthor> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxManifestAuthorCopyWith<$Res> {
  factory $AstroBoxManifestAuthorCopyWith(
    AstroBoxManifestAuthor value,
    $Res Function(AstroBoxManifestAuthor) then,
  ) = _$AstroBoxManifestAuthorCopyWithImpl<$Res, AstroBoxManifestAuthor>;
  @useResult
  $Res call({String name, @JsonKey(name: 'bindABAccount') bool bindAbAccount});
}

/// @nodoc
class _$AstroBoxManifestAuthorCopyWithImpl<
  $Res,
  $Val extends AstroBoxManifestAuthor
>
    implements $AstroBoxManifestAuthorCopyWith<$Res> {
  _$AstroBoxManifestAuthorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxManifestAuthor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? bindAbAccount = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            bindAbAccount: null == bindAbAccount
                ? _value.bindAbAccount
                : bindAbAccount // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxManifestAuthorImplCopyWith<$Res>
    implements $AstroBoxManifestAuthorCopyWith<$Res> {
  factory _$$AstroBoxManifestAuthorImplCopyWith(
    _$AstroBoxManifestAuthorImpl value,
    $Res Function(_$AstroBoxManifestAuthorImpl) then,
  ) = __$$AstroBoxManifestAuthorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, @JsonKey(name: 'bindABAccount') bool bindAbAccount});
}

/// @nodoc
class __$$AstroBoxManifestAuthorImplCopyWithImpl<$Res>
    extends
        _$AstroBoxManifestAuthorCopyWithImpl<$Res, _$AstroBoxManifestAuthorImpl>
    implements _$$AstroBoxManifestAuthorImplCopyWith<$Res> {
  __$$AstroBoxManifestAuthorImplCopyWithImpl(
    _$AstroBoxManifestAuthorImpl _value,
    $Res Function(_$AstroBoxManifestAuthorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxManifestAuthor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? bindAbAccount = null}) {
    return _then(
      _$AstroBoxManifestAuthorImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        bindAbAccount: null == bindAbAccount
            ? _value.bindAbAccount
            : bindAbAccount // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxManifestAuthorImpl implements _AstroBoxManifestAuthor {
  const _$AstroBoxManifestAuthorImpl({
    required this.name,
    @JsonKey(name: 'bindABAccount') this.bindAbAccount = false,
  });

  factory _$AstroBoxManifestAuthorImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxManifestAuthorImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'bindABAccount')
  final bool bindAbAccount;

  @override
  String toString() {
    return 'AstroBoxManifestAuthor(name: $name, bindAbAccount: $bindAbAccount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxManifestAuthorImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.bindAbAccount, bindAbAccount) ||
                other.bindAbAccount == bindAbAccount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, bindAbAccount);

  /// Create a copy of AstroBoxManifestAuthor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxManifestAuthorImplCopyWith<_$AstroBoxManifestAuthorImpl>
  get copyWith =>
      __$$AstroBoxManifestAuthorImplCopyWithImpl<_$AstroBoxManifestAuthorImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxManifestAuthorImplToJson(this);
  }
}

abstract class _AstroBoxManifestAuthor implements AstroBoxManifestAuthor {
  const factory _AstroBoxManifestAuthor({
    required final String name,
    @JsonKey(name: 'bindABAccount') final bool bindAbAccount,
  }) = _$AstroBoxManifestAuthorImpl;

  factory _AstroBoxManifestAuthor.fromJson(Map<String, dynamic> json) =
      _$AstroBoxManifestAuthorImpl.fromJson;

  @override
  String get name;
  @override
  @JsonKey(name: 'bindABAccount')
  bool get bindAbAccount;

  /// Create a copy of AstroBoxManifestAuthor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxManifestAuthorImplCopyWith<_$AstroBoxManifestAuthorImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AstroBoxManifestLink _$AstroBoxManifestLinkFromJson(Map<String, dynamic> json) {
  return _AstroBoxManifestLink.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxManifestLink {
  String? get icon => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxManifestLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxManifestLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxManifestLinkCopyWith<AstroBoxManifestLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxManifestLinkCopyWith<$Res> {
  factory $AstroBoxManifestLinkCopyWith(
    AstroBoxManifestLink value,
    $Res Function(AstroBoxManifestLink) then,
  ) = _$AstroBoxManifestLinkCopyWithImpl<$Res, AstroBoxManifestLink>;
  @useResult
  $Res call({String? icon, String title, String url});
}

/// @nodoc
class _$AstroBoxManifestLinkCopyWithImpl<
  $Res,
  $Val extends AstroBoxManifestLink
>
    implements $AstroBoxManifestLinkCopyWith<$Res> {
  _$AstroBoxManifestLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxManifestLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? icon = freezed,
    Object? title = null,
    Object? url = null,
  }) {
    return _then(
      _value.copyWith(
            icon: freezed == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxManifestLinkImplCopyWith<$Res>
    implements $AstroBoxManifestLinkCopyWith<$Res> {
  factory _$$AstroBoxManifestLinkImplCopyWith(
    _$AstroBoxManifestLinkImpl value,
    $Res Function(_$AstroBoxManifestLinkImpl) then,
  ) = __$$AstroBoxManifestLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? icon, String title, String url});
}

/// @nodoc
class __$$AstroBoxManifestLinkImplCopyWithImpl<$Res>
    extends _$AstroBoxManifestLinkCopyWithImpl<$Res, _$AstroBoxManifestLinkImpl>
    implements _$$AstroBoxManifestLinkImplCopyWith<$Res> {
  __$$AstroBoxManifestLinkImplCopyWithImpl(
    _$AstroBoxManifestLinkImpl _value,
    $Res Function(_$AstroBoxManifestLinkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxManifestLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? icon = freezed,
    Object? title = null,
    Object? url = null,
  }) {
    return _then(
      _$AstroBoxManifestLinkImpl(
        icon: freezed == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxManifestLinkImpl implements _AstroBoxManifestLink {
  const _$AstroBoxManifestLinkImpl({
    this.icon,
    required this.title,
    required this.url,
  });

  factory _$AstroBoxManifestLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxManifestLinkImplFromJson(json);

  @override
  final String? icon;
  @override
  final String title;
  @override
  final String url;

  @override
  String toString() {
    return 'AstroBoxManifestLink(icon: $icon, title: $title, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxManifestLinkImpl &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, icon, title, url);

  /// Create a copy of AstroBoxManifestLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxManifestLinkImplCopyWith<_$AstroBoxManifestLinkImpl>
  get copyWith =>
      __$$AstroBoxManifestLinkImplCopyWithImpl<_$AstroBoxManifestLinkImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxManifestLinkImplToJson(this);
  }
}

abstract class _AstroBoxManifestLink implements AstroBoxManifestLink {
  const factory _AstroBoxManifestLink({
    final String? icon,
    required final String title,
    required final String url,
  }) = _$AstroBoxManifestLinkImpl;

  factory _AstroBoxManifestLink.fromJson(Map<String, dynamic> json) =
      _$AstroBoxManifestLinkImpl.fromJson;

  @override
  String? get icon;
  @override
  String get title;
  @override
  String get url;

  /// Create a copy of AstroBoxManifestLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxManifestLinkImplCopyWith<_$AstroBoxManifestLinkImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AstroBoxManifestDownload _$AstroBoxManifestDownloadFromJson(
  Map<String, dynamic> json,
) {
  return _AstroBoxManifestDownload.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxManifestDownload {
  String get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'file_name')
  String get fileName => throw _privateConstructorUsedError;
  @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
  int? get versionCode => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;
  String? get sha256 => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxManifestDownload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxManifestDownload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxManifestDownloadCopyWith<AstroBoxManifestDownload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxManifestDownloadCopyWith<$Res> {
  factory $AstroBoxManifestDownloadCopyWith(
    AstroBoxManifestDownload value,
    $Res Function(AstroBoxManifestDownload) then,
  ) = _$AstroBoxManifestDownloadCopyWithImpl<$Res, AstroBoxManifestDownload>;
  @useResult
  $Res call({
    String version,
    @JsonKey(name: 'file_name') String fileName,
    @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
    int? versionCode,
    String? url,
    String? sha256,
    String? displayName,
  });
}

/// @nodoc
class _$AstroBoxManifestDownloadCopyWithImpl<
  $Res,
  $Val extends AstroBoxManifestDownload
>
    implements $AstroBoxManifestDownloadCopyWith<$Res> {
  _$AstroBoxManifestDownloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxManifestDownload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? fileName = null,
    Object? versionCode = freezed,
    Object? url = freezed,
    Object? sha256 = freezed,
    Object? displayName = freezed,
  }) {
    return _then(
      _value.copyWith(
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            versionCode: freezed == versionCode
                ? _value.versionCode
                : versionCode // ignore: cast_nullable_to_non_nullable
                      as int?,
            url: freezed == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String?,
            sha256: freezed == sha256
                ? _value.sha256
                : sha256 // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxManifestDownloadImplCopyWith<$Res>
    implements $AstroBoxManifestDownloadCopyWith<$Res> {
  factory _$$AstroBoxManifestDownloadImplCopyWith(
    _$AstroBoxManifestDownloadImpl value,
    $Res Function(_$AstroBoxManifestDownloadImpl) then,
  ) = __$$AstroBoxManifestDownloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String version,
    @JsonKey(name: 'file_name') String fileName,
    @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
    int? versionCode,
    String? url,
    String? sha256,
    String? displayName,
  });
}

/// @nodoc
class __$$AstroBoxManifestDownloadImplCopyWithImpl<$Res>
    extends
        _$AstroBoxManifestDownloadCopyWithImpl<
          $Res,
          _$AstroBoxManifestDownloadImpl
        >
    implements _$$AstroBoxManifestDownloadImplCopyWith<$Res> {
  __$$AstroBoxManifestDownloadImplCopyWithImpl(
    _$AstroBoxManifestDownloadImpl _value,
    $Res Function(_$AstroBoxManifestDownloadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxManifestDownload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? fileName = null,
    Object? versionCode = freezed,
    Object? url = freezed,
    Object? sha256 = freezed,
    Object? displayName = freezed,
  }) {
    return _then(
      _$AstroBoxManifestDownloadImpl(
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        versionCode: freezed == versionCode
            ? _value.versionCode
            : versionCode // ignore: cast_nullable_to_non_nullable
                  as int?,
        url: freezed == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String?,
        sha256: freezed == sha256
            ? _value.sha256
            : sha256 // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxManifestDownloadImpl implements _AstroBoxManifestDownload {
  const _$AstroBoxManifestDownloadImpl({
    required this.version,
    @JsonKey(name: 'file_name') required this.fileName,
    @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
    this.versionCode,
    this.url,
    this.sha256,
    this.displayName,
  });

  factory _$AstroBoxManifestDownloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxManifestDownloadImplFromJson(json);

  @override
  final String version;
  @override
  @JsonKey(name: 'file_name')
  final String fileName;
  @override
  @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
  final int? versionCode;
  @override
  final String? url;
  @override
  final String? sha256;
  @override
  final String? displayName;

  @override
  String toString() {
    return 'AstroBoxManifestDownload(version: $version, fileName: $fileName, versionCode: $versionCode, url: $url, sha256: $sha256, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxManifestDownloadImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.versionCode, versionCode) ||
                other.versionCode == versionCode) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    version,
    fileName,
    versionCode,
    url,
    sha256,
    displayName,
  );

  /// Create a copy of AstroBoxManifestDownload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxManifestDownloadImplCopyWith<_$AstroBoxManifestDownloadImpl>
  get copyWith =>
      __$$AstroBoxManifestDownloadImplCopyWithImpl<
        _$AstroBoxManifestDownloadImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxManifestDownloadImplToJson(this);
  }
}

abstract class _AstroBoxManifestDownload implements AstroBoxManifestDownload {
  const factory _AstroBoxManifestDownload({
    required final String version,
    @JsonKey(name: 'file_name') required final String fileName,
    @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
    final int? versionCode,
    final String? url,
    final String? sha256,
    final String? displayName,
  }) = _$AstroBoxManifestDownloadImpl;

  factory _AstroBoxManifestDownload.fromJson(Map<String, dynamic> json) =
      _$AstroBoxManifestDownloadImpl.fromJson;

  @override
  String get version;
  @override
  @JsonKey(name: 'file_name')
  String get fileName;
  @override
  @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
  int? get versionCode;
  @override
  String? get url;
  @override
  String? get sha256;
  @override
  String? get displayName;

  /// Create a copy of AstroBoxManifestDownload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxManifestDownloadImplCopyWith<_$AstroBoxManifestDownloadImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AstroBoxDeviceMap _$AstroBoxDeviceMapFromJson(Map<String, dynamic> json) {
  return _AstroBoxDeviceMap.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxDeviceMap {
  Map<String, AstroBoxDevice> get xiaomi => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxDeviceMap to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxDeviceMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxDeviceMapCopyWith<AstroBoxDeviceMap> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxDeviceMapCopyWith<$Res> {
  factory $AstroBoxDeviceMapCopyWith(
    AstroBoxDeviceMap value,
    $Res Function(AstroBoxDeviceMap) then,
  ) = _$AstroBoxDeviceMapCopyWithImpl<$Res, AstroBoxDeviceMap>;
  @useResult
  $Res call({Map<String, AstroBoxDevice> xiaomi});
}

/// @nodoc
class _$AstroBoxDeviceMapCopyWithImpl<$Res, $Val extends AstroBoxDeviceMap>
    implements $AstroBoxDeviceMapCopyWith<$Res> {
  _$AstroBoxDeviceMapCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxDeviceMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? xiaomi = null}) {
    return _then(
      _value.copyWith(
            xiaomi: null == xiaomi
                ? _value.xiaomi
                : xiaomi // ignore: cast_nullable_to_non_nullable
                      as Map<String, AstroBoxDevice>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxDeviceMapImplCopyWith<$Res>
    implements $AstroBoxDeviceMapCopyWith<$Res> {
  factory _$$AstroBoxDeviceMapImplCopyWith(
    _$AstroBoxDeviceMapImpl value,
    $Res Function(_$AstroBoxDeviceMapImpl) then,
  ) = __$$AstroBoxDeviceMapImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, AstroBoxDevice> xiaomi});
}

/// @nodoc
class __$$AstroBoxDeviceMapImplCopyWithImpl<$Res>
    extends _$AstroBoxDeviceMapCopyWithImpl<$Res, _$AstroBoxDeviceMapImpl>
    implements _$$AstroBoxDeviceMapImplCopyWith<$Res> {
  __$$AstroBoxDeviceMapImplCopyWithImpl(
    _$AstroBoxDeviceMapImpl _value,
    $Res Function(_$AstroBoxDeviceMapImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxDeviceMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? xiaomi = null}) {
    return _then(
      _$AstroBoxDeviceMapImpl(
        xiaomi: null == xiaomi
            ? _value._xiaomi
            : xiaomi // ignore: cast_nullable_to_non_nullable
                  as Map<String, AstroBoxDevice>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxDeviceMapImpl implements _AstroBoxDeviceMap {
  const _$AstroBoxDeviceMapImpl({
    final Map<String, AstroBoxDevice> xiaomi = const {},
  }) : _xiaomi = xiaomi;

  factory _$AstroBoxDeviceMapImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxDeviceMapImplFromJson(json);

  final Map<String, AstroBoxDevice> _xiaomi;
  @override
  @JsonKey()
  Map<String, AstroBoxDevice> get xiaomi {
    if (_xiaomi is EqualUnmodifiableMapView) return _xiaomi;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_xiaomi);
  }

  @override
  String toString() {
    return 'AstroBoxDeviceMap(xiaomi: $xiaomi)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxDeviceMapImpl &&
            const DeepCollectionEquality().equals(other._xiaomi, _xiaomi));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_xiaomi));

  /// Create a copy of AstroBoxDeviceMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxDeviceMapImplCopyWith<_$AstroBoxDeviceMapImpl> get copyWith =>
      __$$AstroBoxDeviceMapImplCopyWithImpl<_$AstroBoxDeviceMapImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxDeviceMapImplToJson(this);
  }
}

abstract class _AstroBoxDeviceMap implements AstroBoxDeviceMap {
  const factory _AstroBoxDeviceMap({final Map<String, AstroBoxDevice> xiaomi}) =
      _$AstroBoxDeviceMapImpl;

  factory _AstroBoxDeviceMap.fromJson(Map<String, dynamic> json) =
      _$AstroBoxDeviceMapImpl.fromJson;

  @override
  Map<String, AstroBoxDevice> get xiaomi;

  /// Create a copy of AstroBoxDeviceMap
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxDeviceMapImplCopyWith<_$AstroBoxDeviceMapImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AstroBoxDevice _$AstroBoxDeviceFromJson(Map<String, dynamic> json) {
  return _AstroBoxDevice.fromJson(json);
}

/// @nodoc
mixin _$AstroBoxDevice {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  AstroBoxDeviceChip get chip => throw _privateConstructorUsedError;
  bool get fetch => throw _privateConstructorUsedError;

  /// Serializes this AstroBoxDevice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AstroBoxDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AstroBoxDeviceCopyWith<AstroBoxDevice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AstroBoxDeviceCopyWith<$Res> {
  factory $AstroBoxDeviceCopyWith(
    AstroBoxDevice value,
    $Res Function(AstroBoxDevice) then,
  ) = _$AstroBoxDeviceCopyWithImpl<$Res, AstroBoxDevice>;
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    AstroBoxDeviceChip chip,
    bool fetch,
  });
}

/// @nodoc
class _$AstroBoxDeviceCopyWithImpl<$Res, $Val extends AstroBoxDevice>
    implements $AstroBoxDeviceCopyWith<$Res> {
  _$AstroBoxDeviceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AstroBoxDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? chip = null,
    Object? fetch = null,
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
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            chip: null == chip
                ? _value.chip
                : chip // ignore: cast_nullable_to_non_nullable
                      as AstroBoxDeviceChip,
            fetch: null == fetch
                ? _value.fetch
                : fetch // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AstroBoxDeviceImplCopyWith<$Res>
    implements $AstroBoxDeviceCopyWith<$Res> {
  factory _$$AstroBoxDeviceImplCopyWith(
    _$AstroBoxDeviceImpl value,
    $Res Function(_$AstroBoxDeviceImpl) then,
  ) = __$$AstroBoxDeviceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    AstroBoxDeviceChip chip,
    bool fetch,
  });
}

/// @nodoc
class __$$AstroBoxDeviceImplCopyWithImpl<$Res>
    extends _$AstroBoxDeviceCopyWithImpl<$Res, _$AstroBoxDeviceImpl>
    implements _$$AstroBoxDeviceImplCopyWith<$Res> {
  __$$AstroBoxDeviceImplCopyWithImpl(
    _$AstroBoxDeviceImpl _value,
    $Res Function(_$AstroBoxDeviceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AstroBoxDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? chip = null,
    Object? fetch = null,
  }) {
    return _then(
      _$AstroBoxDeviceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        chip: null == chip
            ? _value.chip
            : chip // ignore: cast_nullable_to_non_nullable
                  as AstroBoxDeviceChip,
        fetch: null == fetch
            ? _value.fetch
            : fetch // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AstroBoxDeviceImpl implements _AstroBoxDevice {
  const _$AstroBoxDeviceImpl({
    required this.id,
    required this.name,
    required this.description,
    required this.chip,
    this.fetch = false,
  });

  factory _$AstroBoxDeviceImpl.fromJson(Map<String, dynamic> json) =>
      _$$AstroBoxDeviceImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final AstroBoxDeviceChip chip;
  @override
  @JsonKey()
  final bool fetch;

  @override
  String toString() {
    return 'AstroBoxDevice(id: $id, name: $name, description: $description, chip: $chip, fetch: $fetch)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AstroBoxDeviceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.chip, chip) || other.chip == chip) &&
            (identical(other.fetch, fetch) || other.fetch == fetch));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, description, chip, fetch);

  /// Create a copy of AstroBoxDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AstroBoxDeviceImplCopyWith<_$AstroBoxDeviceImpl> get copyWith =>
      __$$AstroBoxDeviceImplCopyWithImpl<_$AstroBoxDeviceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AstroBoxDeviceImplToJson(this);
  }
}

abstract class _AstroBoxDevice implements AstroBoxDevice {
  const factory _AstroBoxDevice({
    required final String id,
    required final String name,
    required final String description,
    required final AstroBoxDeviceChip chip,
    final bool fetch,
  }) = _$AstroBoxDeviceImpl;

  factory _AstroBoxDevice.fromJson(Map<String, dynamic> json) =
      _$AstroBoxDeviceImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  AstroBoxDeviceChip get chip;
  @override
  bool get fetch;

  /// Create a copy of AstroBoxDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AstroBoxDeviceImplCopyWith<_$AstroBoxDeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
