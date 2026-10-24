import 'package:oronbox/src/features/resources/domain/community_resource.dart';

enum CreatorResourceKind { quickApp, watchface }

enum CreatorExternalPurchaseIssue { link, amount }

const creatorExternalPurchaseMaximumCny = 9999999999.99;
const creatorExternalPurchaseLinkMaximumLength = 2048;

bool creatorBandBbsVersionFieldsComplete(String title, String message) {
  return title.trim().isEmpty == message.trim().isEmpty;
}

CreatorExternalPurchaseIssue? validateCreatorExternalPurchase({
  required bool enabled,
  required CommunityPaidType paidType,
  required String link,
  required String amount,
  required bool requireAmount,
  required bool requireHttps,
}) {
  if (!enabled) return null;
  final purchaseUrl = Uri.tryParse(link.trim());
  final validScheme = requireHttps
      ? purchaseUrl?.scheme == 'https'
      : purchaseUrl?.scheme == 'http' || purchaseUrl?.scheme == 'https';
  if (paidType == CommunityPaidType.free ||
      purchaseUrl == null ||
      link.trim().length > creatorExternalPurchaseLinkMaximumLength ||
      purchaseUrl.host.isEmpty ||
      !validScheme) {
    return CreatorExternalPurchaseIssue.link;
  }

  final rawAmount = amount.trim();
  if (rawAmount.isEmpty && !requireAmount) return null;
  if (!RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,2})?$').hasMatch(rawAmount)) {
    return CreatorExternalPurchaseIssue.amount;
  }
  final parsedAmount = double.tryParse(rawAmount);
  if (parsedAmount == null ||
      !parsedAmount.isFinite ||
      parsedAmount < 0.01 ||
      parsedAmount > creatorExternalPurchaseMaximumCny) {
    return CreatorExternalPurchaseIssue.amount;
  }
  return null;
}

class CreatorWorkspace {
  const CreatorWorkspace({
    required this.resource,
    this.currentRevision,
    this.revisions = const [],
    this.artifacts = const [],
    this.media = const [],
    this.links = const [],
    this.review,
    this.publications = const [],
    this.bindings = const [],
  });

  final CreatorResource resource;
  final CreatorRevision? currentRevision;
  final List<CreatorRevision> revisions;
  final List<CreatorArtifact> artifacts;
  final List<CreatorMedia> media;
  final List<CreatorLink> links;
  final Map<String, Object?>? review;
  final List<Map<String, Object?>> publications;

  /// External identities this resource is bound to (BandBBS / AstroBox).
  final List<Map<String, Object?>> bindings;

  /// Latest revision, which is the editing baseline for the next publish.
  CreatorRevision? get latestRevision =>
      revisions.isEmpty ? null : revisions.first;

  factory CreatorWorkspace.fromJson(Map<String, Object?> json) {
    final revisions = _maps(json['revisions'])
        .map(CreatorRevision.fromJson)
        .toList();
    return CreatorWorkspace(
      resource: CreatorResource.fromJson(_map(json['resource'])),
      currentRevision: json['current_revision'] is Map
          ? CreatorRevision.fromJson(_map(json['current_revision']))
          : null,
      revisions: revisions,
      artifacts: _maps(json['artifacts'])
          .map(CreatorArtifact.fromJson)
          .toList(),
      media: _maps(json['media']).map(CreatorMedia.fromJson).toList(),
      links: _maps(json['links']).map(CreatorLink.fromJson).toList(),
      review: json['review'] is Map ? _map(json['review']) : null,
      publications: _maps(json['publications']),
      bindings: _maps(json['bindings']),
    );
  }
}

class CreatorLink {
  const CreatorLink({required this.title, required this.url});

  final String title;
  final String url;

  factory CreatorLink.fromJson(Map<String, Object?> json) => CreatorLink(
    title: json['title']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );
}

class CreatorResource {
  const CreatorResource({
    required this.id,
    required this.slug,
    required this.kind,
    this.editVersion = 0,
    this.draftName = '',
    this.moderationState = 'visible',
    this.moderationBy = '',
    this.moderationReason = '',
    this.downloadCount = 0,
    this.collectionId = '',
    this.collectionPosition = 0,
    this.updatedAt,
  });
  final String id;
  final String slug;
  final int editVersion;
  final String draftName;
  final CreatorResourceKind kind;
  final String moderationState;
  final String moderationBy;
  final String moderationReason;
  final int downloadCount;
  final String collectionId;
  final int collectionPosition;
  final DateTime? updatedAt;

  bool get isSuspended => moderationState == 'suspended';
  bool get isFrozen => moderationState == 'frozen';
  bool get canRestore => isSuspended && moderationBy == 'owner';

  factory CreatorResource.fromJson(Map<String, Object?> json) =>
      CreatorResource(
        id: json['id']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        editVersion: (json['edit_version'] as num?)?.toInt() ?? 0,
        draftName: json['draft_name']?.toString() ?? '',
        kind: json['kind'] == 'watchface'
            ? CreatorResourceKind.watchface
            : CreatorResourceKind.quickApp,
        moderationState: json['moderation_state']?.toString() ?? 'visible',
        moderationBy: json['moderation_by']?.toString() ?? '',
        moderationReason: json['moderation_reason']?.toString() ?? '',
        downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
        collectionId: json['collection_id']?.toString() ?? '',
        collectionPosition: (json['collection_position'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );
}

class CreatorRevision {
  const CreatorRevision({
    required this.id,
    required this.number,
    required this.name,
    required this.summary,
    this.description = '',
    this.descriptionFormat = 'plain',
    required this.state,
    this.paidType = CommunityPaidType.free,
    this.purchaseLink = '',
    this.purchasePrice,
    this.purchaseCurrency = '',
    this.attributes = const [],
    this.publicationPlan,
    this.bindingClaims = const [],
  });
  final List<Map<String, Object?>> bindingClaims;
  final String id;
  final int number;
  final String name;
  final String summary;
  final String description;
  final String descriptionFormat;
  final String state;
  final CommunityPaidType paidType;
  final String purchaseLink;
  final double? purchasePrice;
  final String purchaseCurrency;
  final List<String> attributes;

  /// Saved publish intent ({target, config} entries); editor baseline, never
  /// a dispatchable job. Null means no intent was ever saved (fresh import),
  /// so the editor derives one from the imported bindings instead.
  final List<Map<String, Object?>>? publicationPlan;

  factory CreatorRevision.fromJson(Map<String, Object?> json) =>
      CreatorRevision(
        bindingClaims: _maps(json['binding_claims']),
        id: json['id']?.toString() ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        descriptionFormat: json['description_format']?.toString() ?? 'plain',
        state: json['state']?.toString() ?? '',
        paidType: communityPaidTypeFromWire(json['paid_type']),
        purchaseLink: json['purchase_link']?.toString() ?? '',
        purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
        purchaseCurrency:
            (json['purchase_link']?.toString().trim().isNotEmpty ?? false)
            ? 'CNY'
            : '',
        attributes: (json['attributes'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        publicationPlan: json['publication_plan'] == null
            ? null
            : _maps(json['publication_plan']),
      );
}

class CreatorArtifact {
  const CreatorArtifact({
    required this.id,
    required this.name,
    required this.sha256,
    required this.packageId,
    required this.version,
    required this.devices,
    this.sizeBytes = 0,
    this.analysisKind = '',
  });

  final String id;
  final String name;
  final String sha256;
  final String packageId;
  final String version;
  final List<String> devices;
  final int sizeBytes;
  final String analysisKind;

  factory CreatorArtifact.fromJson(Map<String, Object?> json) =>
      CreatorArtifact(
        id: json['id']?.toString() ?? '',
        name: json['original_name']?.toString() ?? '',
        sha256: json['sha256']?.toString() ?? '',
        packageId: json['package_id']?.toString() ?? '',
        version: json['package_version']?.toString() ?? '',
        devices: (json['device_ids'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        analysisKind: (json['analysis'] as Map?)?['kind']?.toString() ?? '',
      );
}

class CreatorMedia {
  const CreatorMedia({
    required this.id,
    required this.role,
    this.sha256 = '',
    this.position = 0,
    this.width = 0,
    this.height = 0,
    this.sizeBytes = 0,
  });
  final String id;
  final String role;
  final String sha256;
  final int position;
  final int width;
  final int height;
  final int sizeBytes;

  factory CreatorMedia.fromJson(Map<String, Object?> json) => CreatorMedia(
    id: json['id']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    sha256: json['sha256']?.toString() ?? '',
    position: (json['position'] as num?)?.toInt() ?? 0,
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
  );
}

class CreatorDevice {
  const CreatorDevice({
    required this.id,
    required this.codename,
    required this.name,
    this.platform = '',
    this.astroBoxId = '',
    this.vendor = '',
  });

  final String id;
  final String codename;
  final String name;
  final String platform;
  final String astroBoxId;
  final String vendor;

  factory CreatorDevice.fromJson(Map<String, Object?> json) => CreatorDevice(
    id: json['id']?.toString() ?? '',
    codename: json['codename']?.toString() ?? '',
    name: json['name']?.toString() ?? json['display_name']?.toString() ?? '',
    platform: json['platform']?.toString() ?? '',
    astroBoxId: json['astrobox_id']?.toString() ?? '',
    vendor: json['vendor']?.toString() ?? '',
  );
}

Map<String, Object?> _map(Object? value) =>
    (value as Map?)?.cast<String, Object?>() ?? const {};

List<Map<String, Object?>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => item.cast<String, Object?>())
    .toList();
