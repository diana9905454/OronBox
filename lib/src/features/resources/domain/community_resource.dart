import 'dart:typed_data';

import 'package:oronbox/src/data/community/community_source.dart';

enum CommunityResourceType {
  quickApp,
  miniprogram,
  watchface,
  firmware,
  canopus,
}

enum CommunityPaidType { free, paid, forcePaid }

/// Download modes that OronBox cannot process locally.
///
/// AstroBox Creator Console encrypts selected paid downloads before upload and
/// keeps the decryption key in its own purchase/entitlement service. The
/// manifest marker is surfaced as this domain value so every catalog path can
/// make the same decision without exposing AstroBox's raw extension object.
enum CommunityResourceDownloadRestriction { none, astroBoxCreatorEncrypted }

String communityResourceDownloadRestrictionToWire(
  CommunityResourceDownloadRestriction value,
) => switch (value) {
  CommunityResourceDownloadRestriction.none => 'none',
  CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted =>
    'astrobox_creator_encrypted',
};

CommunityResourceDownloadRestriction
communityResourceDownloadRestrictionFromWire(Object? value) =>
    switch (value?.toString().trim().toLowerCase()) {
      'astrobox_creator_encrypted' || 'astroboxcreatorencrypted' =>
        CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted,
      _ => CommunityResourceDownloadRestriction.none,
    };

String communityPaidTypeToWire(CommunityPaidType value) => switch (value) {
  CommunityPaidType.free => 'free',
  CommunityPaidType.paid => 'paid',
  CommunityPaidType.forcePaid => 'force_paid',
};

CommunityPaidType communityPaidTypeFromWire(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'paid' => CommunityPaidType.paid,
    'force_paid' || 'forcepaid' => CommunityPaidType.forcePaid,
    _ => CommunityPaidType.free,
  };
}

enum ResourceContentFormat { plainText, html, markdown }

class ResourceRef {
  const ResourceRef({required this.source, required this.id});

  final CommunitySourceId source;
  final String id;

  String get key => '${source.storageKey}:$id';

  @override
  bool operator ==(Object other) =>
      other is ResourceRef && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);
}

String resourceMediaHeroTag(ResourceRef ref, String role) =>
    'resource-media:${ref.key}:$role';

class CommunityResourceAuthor {
  const CommunityResourceAuthor({required this.name, this.url, this.avatarUrl});

  final String name;
  final Uri? url;
  final Uri? avatarUrl;
}

class CommunityResourceLink {
  const CommunityResourceLink({required this.title, required this.url});

  final String title;
  final Uri url;
}

class CommunityResourceFile {
  const CommunityResourceFile({
    required this.id,
    required this.fileName,
    required this.version,
    this.displayName,
    this.downloadUrl,
    this.size,
    this.supportedDevices = const {},
    this.encrypted = false,
  });

  final String id;
  final String fileName;
  final String version;
  final String? displayName;
  final Uri? downloadUrl;
  final int? size;
  final Set<String> supportedDevices;

  /// The payload is encrypted by the source and must be unlocked before it
  /// can be passed to the device installer.
  final bool encrypted;

  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : fileName;
}

class CommunityResource {
  const CommunityResource({
    required this.ref,
    required this.name,
    required this.type,
    required this.paidType,
    required this.authors,
    required this.supportedDevices,
    this.iconUrl,
    this.coverUrl,
    this.summary = '',
    this.updatedAt,
    this.publicUrl,
    this.tags = const [],
    this.downloadCount,
    this.version,
    this.priceLabel,
    this.coinCount = 0,
    this.curationGrade = 'standard',
    this.collectionId,
    this.collectionName,
    this.isCollection = false,
    this.resourceCount = 0,
    this.sourceSectionId,
    this.sourceRepoOwner,
    this.sourceRepoName,
    this.sourceRepoCommitHash,
  });

  final ResourceRef ref;
  final String name;
  final CommunityResourceType type;
  final CommunityPaidType paidType;
  final List<CommunityResourceAuthor> authors;
  final Set<String> supportedDevices;
  final Uri? iconUrl;
  final Uri? coverUrl;
  final String summary;
  final DateTime? updatedAt;
  final Uri? publicUrl;
  final List<String> tags;
  final int? downloadCount;
  final String? version;
  final String? priceLabel;
  final int coinCount;
  final String curationGrade;
  final String? collectionId;
  final String? collectionName;
  final bool isCollection;
  final int resourceCount;

  /// Platform-specific listing section id (BandBBS resource_category_id);
  /// lets an import bind back to the exact section it came from.
  final String? sourceSectionId;

  /// Repository the external item is published from (AstroBox index
  /// repo_owner/repo_name); recorded into the binding so later publications
  /// update that repo instead of creating a new one.
  final String? sourceRepoOwner;
  final String? sourceRepoName;
  final String? sourceRepoCommitHash;

  String get authorName => authors.firstOrNull?.name ?? '';
}

class CommunityResourceContent {
  const CommunityResourceContent({
    required this.format,
    required this.value,
    this.baseUri,
  });

  final ResourceContentFormat format;
  final String value;
  final Uri? baseUri;
}

class CommunityResourceImage {
  const CommunityResourceImage({
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  final Uri url;
  final Uri? thumbnailUrl;
  final int? width;
  final int? height;
}

class CommunityResourceDetail extends CommunityResource {
  const CommunityResourceDetail({
    required super.ref,
    required super.name,
    required super.type,
    required super.paidType,
    required super.authors,
    required super.supportedDevices,
    required this.content,
    required this.files,
    super.iconUrl,
    super.coverUrl,
    super.summary,
    super.updatedAt,
    super.publicUrl,
    super.tags,
    super.downloadCount,
    super.version,
    super.priceLabel,
    super.coinCount,
    super.curationGrade,
    super.collectionId,
    super.collectionName,
    super.isCollection,
    super.resourceCount,
    super.sourceSectionId,
    super.sourceRepoOwner,
    super.sourceRepoName,
    super.sourceRepoCommitHash,
    this.purchaseLink,
    this.purchasePrice,
    this.purchaseCurrency = '',
    this.previews = const [],
    this.previewImages = const [],
    this.links = const [],
    this.canDownload = true,
    this.downloadRestriction = CommunityResourceDownloadRestriction.none,
  });

  final CommunityResourceContent content;
  final List<CommunityResourceFile> files;
  final Uri? purchaseLink;
  final double? purchasePrice;
  final String purchaseCurrency;
  final List<Uri> previews;
  final List<CommunityResourceImage> previewImages;
  final List<CommunityResourceLink> links;
  final bool canDownload;
  final CommunityResourceDownloadRestriction downloadRestriction;
}

class CommunityResourceDevice {
  const CommunityResourceDevice({
    required this.codename,
    required this.name,
    this.description = '',
  });

  final String codename;
  final String name;
  final String description;
}

class CommunityResourceDownloadResult {
  const CommunityResourceDownloadResult({
    required this.path,
    required this.fileName,
    this.bytes,
  });

  final String path;
  final String fileName;
  final Uint8List? bytes;
}
