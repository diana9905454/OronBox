import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/storage/managed_temporary_files.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';

class OronBoxResourceCatalog implements CommunityResourceCatalog {
  OronBoxResourceCatalog({Dio? dio}) : _dio = dio ?? createAppHttpTransport();

  final Dio _dio;

  @override
  CommunitySourceId get sourceId => CommunitySourceId.oronBox;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(serverSort: true);

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/resources',
      queryParameters: {
        'limit': query.pageSize,
        'offset': query.page * query.pageSize,
        if (query.seed != null) 'seed': query.seed,
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.type != null) 'type': _typeName(query.type!),
        if (query.selectedDevices.isNotEmpty)
          'devices': query.selectedDevices.join(','),
        if (query.selectedAttributes.isNotEmpty)
          'attributes': query.selectedAttributes.join(','),
        if (query.hidePaid) 'hide_paid': '1',
        if (query.hideForcePaid) 'hide_force_paid': '1',
        if (query.featured) 'featured': '1',
        'sort': query.sort.name,
      },
    );
    final root = _map(response.data);
    final items = (root['resources'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _summary(value.cast<String, Object?>()))
        .toList();
    return CommunityResourcePage(
      items: items,
      page: query.page,
      hasMore: items.length == query.pageSize,
      total: (root['total'] as num?)?.toInt(),
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _requireSource(ref);
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/resources/${Uri.encodeComponent(ref.id)}',
    );
    final json = _map(response.data);
    final summary = _summary(json);
    final media = (json['media'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList();
    final artifacts = (json['artifacts'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList();
    final previewImages = parseOronBoxPreviewImages(
      media,
      blobUri: _imageBlobUri,
    );
    final previews = previewImages.map((image) => image.url).toList();
    final collaborators = (json['collaborators'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .where((value) => value['accepted_at'] != null)
        .map((value) {
          final avatar = Uri.tryParse(value['avatar_url']?.toString() ?? '');
          return CommunityResourceAuthor(
            name: value['username']?.toString() ?? '',
            avatarUrl: avatar?.hasScheme == true ? avatar : null,
          );
        })
        .where((author) => author.name.isNotEmpty);
    final source = json['source'] is Map
        ? (json['source'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final sourceUrl = Uri.tryParse(source['source_url']?.toString() ?? '');
    final purchaseLink = Uri.tryParse(json['purchase_link']?.toString() ?? '');
    return CommunityResourceDetail(
      ref: summary.ref,
      name: summary.name,
      type: summary.type,
      paidType: summary.paidType,
      authors: [...summary.authors, ...collaborators],
      supportedDevices: summary.supportedDevices,
      iconUrl: summary.iconUrl,
      coverUrl: summary.coverUrl,
      summary: summary.summary,
      updatedAt: summary.updatedAt,
      version: summary.version,
      purchaseLink: purchaseLink?.hasScheme == true ? purchaseLink : null,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      purchaseCurrency: purchaseLink?.hasScheme == true ? 'CNY' : '',
      downloadCount: summary.downloadCount,
      coinCount: summary.coinCount,
      curationGrade: summary.curationGrade,
      collectionId: summary.collectionId,
      collectionName: summary.collectionName,
      tags: summary.tags,
      content: CommunityResourceContent(
        format: json['description_format'] == 'markdown'
            ? ResourceContentFormat.markdown
            : ResourceContentFormat.plainText,
        value: json['description']?.toString() ?? '',
      ),
      previews: previews,
      previewImages: previewImages,
      links: [
        for (final item in (json['links'] as List? ?? const []))
          if (item is Map)
            () {
              final value = item.cast<String, Object?>();
              final url = Uri.tryParse(value['url']?.toString() ?? '');
              return url?.hasScheme == true
                  ? CommunityResourceLink(
                      title: value['title']?.toString() ?? url!.host,
                      url: url!,
                    )
                  : null;
            }(),
        if (sourceUrl?.hasScheme == true)
          CommunityResourceLink(
            title: source['license_name']?.toString().trim().isNotEmpty == true
                ? source['license_name']!.toString()
                : source['author_name']?.toString().trim().isNotEmpty == true
                ? source['author_name']!.toString()
                : sourceUrl!.host,
            url: sourceUrl!,
          ),
      ].whereType<CommunityResourceLink>().toList(),
      files: artifacts.map((item) {
        final digest =
            (item['sha256'] ?? item['blob_sha256'])?.toString() ?? '';
        return CommunityResourceFile(
          id: item['id']?.toString() ?? digest,
          fileName: item['original_name']?.toString() ?? 'resource',
          version: item['version']?.toString() ?? '',
          downloadUrl: _blobUri(digest),
          supportedDevices:
              (item['device_ids'] as List? ??
                      item['devices'] as List? ??
                      const [])
                  .map((value) => value.toString())
                  .toSet(),
        );
      }).toList(),
    );
  }

  Future<OronBoxCollectionDetail> getCollection(String id) async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/collections/${Uri.encodeComponent(id)}',
    );
    final json = _map(response.data);
    final resources = (json['resources'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _summary(value.cast<String, Object?>()))
        .toList();
    final representative = switch (json['representative']) {
      Map value => _summary(value.cast<String, Object?>()),
      _ =>
        resources
            .where(
              (resource) =>
                  resource.ref.id ==
                  json['representative_resource_id']?.toString(),
            )
            .firstOrNull,
    };
    return OronBoxCollectionDetail(
      description: json['description']?.toString() ?? '',
      iconUrl: _blobUri(json['icon_sha256']?.toString() ?? ''),
      coverUrl: _blobUri(json['cover_sha256']?.toString() ?? ''),
      id: json['id']?.toString() ?? id,
      name: json['name']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      coinCount: (json['coin_count'] as num?)?.toInt() ?? 0,
      type: _parseType(json['kind']?.toString()),
      representative: representative ?? resources.firstOrNull,
      resourceCount:
          (json['resource_count'] as num?)?.toInt() ?? resources.length,
      resources: resources,
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/devices',
    );
    return (_map(response.data)['devices'] as List? ?? const [])
        .whereType<Map>()
        .map((value) {
          final json = value.cast<String, Object?>();
          return CommunityResourceDevice(
            codename: json['codename']?.toString() ?? '',
            name: json['name']?.toString() ?? '',
            description: json['platform']?.toString() ?? '',
          );
        })
        .toList();
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    final url = request.file.downloadUrl;
    if (url == null) throw StateError('OronBox resource has no download URL');
    final fileName = _safeName(request.file.label);
    if (kIsWeb) {
      final bytes = await _downloadBytesWithFallback(url, request);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('OronBox resource download returned empty data');
      }
      return CommunityResourceDownloadResult(
        path: '/oronbox_downloads/$fileName',
        fileName: fileName,
        bytes: bytes,
      );
    }
    final destination = await ManagedTemporaryFiles.create(
      TemporaryFilePurpose.downloads,
      fileName,
      (path) => _downloadFileWithFallback(url, path, request),
    );
    return CommunityResourceDownloadResult(
      path: destination,
      fileName: fileName,
    );
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    final url = file.downloadUrl;
    if (url == null) return null;
    Response<Object?> response;
    try {
      response = await _dio.head<Object?>(_line(url, 'r2').toString());
    } on DioException {
      response = await _dio.head<Object?>(_line(url, 'local').toString());
    }
    return int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
  }

  Future<Uint8List?> _downloadBytesWithFallback(
    Uri url,
    CommunityDownloadRequest request,
  ) async {
    try {
      return (await _dio.get<Uint8List>(
        _line(url, 'r2').toString(),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'r2'),
      )).data;
    } on DioException {
      return (await _dio.get<Uint8List>(
        _line(url, 'local').toString(),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'local'),
      )).data;
    }
  }

  Future<void> _downloadFileWithFallback(
    Uri url,
    String destination,
    CommunityDownloadRequest request,
  ) async {
    try {
      await _dio.download(
        _line(url, 'r2').toString(),
        destination,
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'r2'),
      );
    } on DioException {
      await _dio.download(
        _line(url, 'local').toString(),
        destination,
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'local'),
      );
    }
  }

  Uri _line(Uri url, String line) =>
      url.replace(queryParameters: {...url.queryParameters, 'line': line});

  void _reportProgress(
    CommunityDownloadRequest request,
    int received,
    int total,
    String line,
  ) {
    if (total > 0) request.onProgress?.call(received / total, status: line);
  }

  /// Converts the compact resource payload used by both the catalog and the
  /// home feed into the shared community model.
  CommunityResource summaryFromWire(Map<String, Object?> json) =>
      _summary(json);

  CommunityResource _summary(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final preview = json['preview_sha256']?.toString() ?? '';
    final icon = json['icon_sha256']?.toString() ?? '';
    final cover = json['cover_sha256']?.toString() ?? '';
    final iconDigest = icon.isNotEmpty ? icon : preview;
    final coverDigest = cover.isNotEmpty ? cover : iconDigest;
    final owner = json['owner']?.toString() ?? '';
    final ownerAvatar = Uri.tryParse(
      json['owner_avatar_url']?.toString() ?? '',
    );
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: id),
      name: json['name']?.toString() ?? '',
      type: _parseType(json['kind']?.toString()),
      paidType: communityPaidTypeFromWire(json['paid_type']),
      authors: [
        if (owner.isNotEmpty)
          CommunityResourceAuthor(
            name: owner,
            avatarUrl: ownerAvatar?.hasScheme == true ? ownerAvatar : null,
          ),
      ],
      supportedDevices: (json['devices'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet(),
      iconUrl: _imageBlobUri(iconDigest),
      coverUrl: _imageBlobUri(coverDigest),
      summary: json['summary']?.toString() ?? '',
      tags: (json['attributes'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      version: json['version']?.toString(),
      downloadCount: (json['download_count'] as num?)?.toInt(),
      coinCount: (json['coin_count'] as num?)?.toInt() ?? 0,
      curationGrade: json['curation_grade']?.toString() ?? 'standard',
      collectionId: json['collection_id']?.toString().trim().isNotEmpty == true
          ? json['collection_id']!.toString()
          : null,
      collectionName:
          json['collection_name']?.toString().trim().isNotEmpty == true
          ? json['collection_name']!.toString()
          : null,
      isCollection: json['card_type']?.toString() == 'collection',
      resourceCount: (json['resource_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(
        json['published_at']?.toString() ??
            json['updated_at']?.toString() ??
            '',
      ),
    );
  }

  Uri? _blobUri(String digest) => digest.length == 64
      ? Uri.parse('$oronBoxServerBaseUrl/api/v1/blobs/$digest')
      : null;

  Uri? _imageBlobUri(String digest) => digest.length == 64
      ? Uri.parse('$oronBoxServerBaseUrl/api/v1/blobs/$digest?line=local')
      : null;

  CommunityResourceType _parseType(String? value) => switch (value) {
    'zepp_app' => CommunityResourceType.miniprogram,
    'watchface' => CommunityResourceType.watchface,
    'firmware' => CommunityResourceType.firmware,
    'canopus' => CommunityResourceType.canopus,
    _ => CommunityResourceType.quickApp,
  };

  String _typeName(CommunityResourceType type) => switch (type) {
    CommunityResourceType.quickApp => 'quickapp',
    CommunityResourceType.miniprogram => 'zepp_app',
    CommunityResourceType.watchface => 'watchface',
    CommunityResourceType.firmware => 'firmware',
    CommunityResourceType.canopus => 'canopus',
  };

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');

  String _safeName(String value) {
    final name = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name.isEmpty || name == '.' || name == '..' ? 'resource' : name;
  }

  void _requireSource(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw ArgumentError.value(ref, 'ref', 'Wrong resource source');
    }
  }
}

class OronBoxCollectionDetail {
  final String description;
  final Uri? iconUrl, coverUrl;
  const OronBoxCollectionDetail({
    this.description = '',
    this.iconUrl,
    this.coverUrl,
    required this.id,
    required this.name,
    required this.summary,
    required this.owner,
    required this.coinCount,
    this.type = CommunityResourceType.quickApp,
    this.representative,
    this.resourceCount = 0,
    required this.resources,
  });

  final String id;
  final String name;
  final String summary;
  final String owner;
  final int coinCount;
  final CommunityResourceType type;
  final CommunityResource? representative;
  final int resourceCount;
  final List<CommunityResource> resources;
}

List<CommunityResourceImage> parseOronBoxPreviewImages(
  List<Map<String, Object?>> media, {
  required Uri? Function(String digest) blobUri,
}) => media
    .where((item) => item['role'] == 'preview')
    .map((item) {
      final digest = (item['sha256'] ?? item['blob_sha256'])?.toString() ?? '';
      final url = blobUri(digest);
      if (url == null) return null;
      return CommunityResourceImage(
        url: url,
        width: (item['width'] as num?)?.toInt(),
        height: (item['height'] as num?)?.toInt(),
      );
    })
    .whereType<CommunityResourceImage>()
    .toList();
