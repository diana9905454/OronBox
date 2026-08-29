// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'astrobox_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AstroBoxIndexItemImpl _$$AstroBoxIndexItemImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxIndexItemImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$AstroBoxResourceTypeEnumMap, json['restype']),
  repoOwner: json['repoOwner'] as String,
  repoName: json['repoName'] as String,
  repoCommitHash: json['repoCommitHash'] as String,
  icon: json['icon'] as String,
  cover: json['cover'] as String,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  deviceVendors:
      (json['device_vendors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  devices:
      (json['devices'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  paidType: $enumDecode(_$AstroBoxPaidTypeEnumMap, json['paid_type']),
);

Map<String, dynamic> _$$AstroBoxIndexItemImplToJson(
  _$AstroBoxIndexItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'restype': _$AstroBoxResourceTypeEnumMap[instance.type]!,
  'repoOwner': instance.repoOwner,
  'repoName': instance.repoName,
  'repoCommitHash': instance.repoCommitHash,
  'icon': instance.icon,
  'cover': instance.cover,
  'tags': instance.tags,
  'device_vendors': instance.deviceVendors,
  'devices': instance.devices,
  'paid_type': _$AstroBoxPaidTypeEnumMap[instance.paidType]!,
};

const _$AstroBoxResourceTypeEnumMap = {
  AstroBoxResourceType.quickApp: 'quick_app',
  AstroBoxResourceType.watchface: 'watchface',
  AstroBoxResourceType.firmware: 'firmware',
  AstroBoxResourceType.canopus: 'canopus',
};

const _$AstroBoxPaidTypeEnumMap = {
  AstroBoxPaidType.free: 'free',
  AstroBoxPaidType.paid: 'paid',
  AstroBoxPaidType.forcePaid: 'force_paid',
};

_$AstroBoxManifestImpl _$$AstroBoxManifestImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxManifestImpl(
  item: AstroBoxManifestItem.fromJson(json['item'] as Map<String, dynamic>),
  links:
      (json['links'] as List<dynamic>?)
          ?.map((e) => AstroBoxManifestLink.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  downloads:
      (json['downloads'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          AstroBoxManifestDownload.fromJson(e as Map<String, dynamic>),
        ),
      ) ??
      const {},
  ext: json['ext'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$AstroBoxManifestImplToJson(
  _$AstroBoxManifestImpl instance,
) => <String, dynamic>{
  'item': instance.item,
  'links': instance.links,
  'downloads': instance.downloads,
  'ext': instance.ext,
};

_$AstroBoxManifestItemImpl _$$AstroBoxManifestItemImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxManifestItemImpl(
  id: json['id'] as String,
  restype: $enumDecode(_$AstroBoxResourceTypeEnumMap, json['restype']),
  name: json['name'] as String,
  description: json['description'] as String,
  descriptionHtml: json['descriptionHtml'] as String?,
  descriptionBaseUrl: json['descriptionBaseUrl'] as String?,
  preview:
      (json['preview'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  icon: json['icon'] as String,
  cover: json['cover'] as String,
  paidType: $enumDecodeNullable(_$AstroBoxPaidTypeEnumMap, json['paidType']),
  author:
      (json['author'] as List<dynamic>?)
          ?.map(
            (e) => AstroBoxManifestAuthor.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$$AstroBoxManifestItemImplToJson(
  _$AstroBoxManifestItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'restype': _$AstroBoxResourceTypeEnumMap[instance.restype]!,
  'name': instance.name,
  'description': instance.description,
  'descriptionHtml': instance.descriptionHtml,
  'descriptionBaseUrl': instance.descriptionBaseUrl,
  'preview': instance.preview,
  'icon': instance.icon,
  'cover': instance.cover,
  'paidType': _$AstroBoxPaidTypeEnumMap[instance.paidType],
  'author': instance.author,
};

_$AstroBoxManifestAuthorImpl _$$AstroBoxManifestAuthorImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxManifestAuthorImpl(
  name: json['name'] as String,
  bindAbAccount: json['bindABAccount'] as bool? ?? false,
);

Map<String, dynamic> _$$AstroBoxManifestAuthorImplToJson(
  _$AstroBoxManifestAuthorImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'bindABAccount': instance.bindAbAccount,
};

_$AstroBoxManifestLinkImpl _$$AstroBoxManifestLinkImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxManifestLinkImpl(
  icon: json['icon'] as String?,
  title: json['title'] as String,
  url: json['url'] as String,
);

Map<String, dynamic> _$$AstroBoxManifestLinkImplToJson(
  _$AstroBoxManifestLinkImpl instance,
) => <String, dynamic>{
  'icon': instance.icon,
  'title': instance.title,
  'url': instance.url,
};

_$AstroBoxManifestDownloadImpl _$$AstroBoxManifestDownloadImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxManifestDownloadImpl(
  version: json['version'] as String,
  fileName: json['file_name'] as String,
  versionCode: _versionCodeFromJson(json['version_code']),
  url: json['url'] as String?,
  sha256: json['sha256'] as String?,
  displayName: json['displayName'] as String?,
);

Map<String, dynamic> _$$AstroBoxManifestDownloadImplToJson(
  _$AstroBoxManifestDownloadImpl instance,
) => <String, dynamic>{
  'version': instance.version,
  'file_name': instance.fileName,
  'version_code': instance.versionCode,
  'url': instance.url,
  'sha256': instance.sha256,
  'displayName': instance.displayName,
};

_$AstroBoxDeviceMapImpl _$$AstroBoxDeviceMapImplFromJson(
  Map<String, dynamic> json,
) => _$AstroBoxDeviceMapImpl(
  xiaomi:
      (json['xiaomi'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, AstroBoxDevice.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
);

Map<String, dynamic> _$$AstroBoxDeviceMapImplToJson(
  _$AstroBoxDeviceMapImpl instance,
) => <String, dynamic>{'xiaomi': instance.xiaomi};

_$AstroBoxDeviceImpl _$$AstroBoxDeviceImplFromJson(Map<String, dynamic> json) =>
    _$AstroBoxDeviceImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      chip: $enumDecode(_$AstroBoxDeviceChipEnumMap, json['chip']),
      fetch: json['fetch'] as bool? ?? false,
    );

Map<String, dynamic> _$$AstroBoxDeviceImplToJson(
  _$AstroBoxDeviceImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'chip': _$AstroBoxDeviceChipEnumMap[instance.chip]!,
  'fetch': instance.fetch,
};

const _$AstroBoxDeviceChipEnumMap = {
  AstroBoxDeviceChip.xring: 'xring',
  AstroBoxDeviceChip.bes: 'bes',
};
