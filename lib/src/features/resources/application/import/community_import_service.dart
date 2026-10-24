import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/resources/services/resource_image_processor.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

const communityImportMaxPreviews = 12;
const communityImportMaxNameRunes = 120;
const communityImportMaxSummaryRunes = 4000;
const _communityImportRetryCount = 3;

bool _isRetryableImportError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == null ||
        status == 408 ||
        status == 425 ||
        status == 429 ||
        status >= 500;
  }
  if (error is SocketException || error is TimeoutException) return true;
  final message = error.toString().toLowerCase();
  return message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('network') ||
      message.contains('temporarily unavailable') ||
      message.contains('http 408') ||
      message.contains('http 429') ||
      message.contains('http 5');
}

Future<T> _retryImportOperation<T>(Future<T> Function() operation) async {
  Future<T> attempt(int number) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (number >= _communityImportRetryCount ||
          !_isRetryableImportError(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      await Future<void>.delayed(Duration(seconds: 1 << (number - 1)));
      return attempt(number + 1);
    }
  }

  return attempt(1);
}

bool communityImportSourceSupported(CommunitySourceId source) =>
    source == CommunitySourceId.bandbbs ||
    source == CommunitySourceId.astroboxRepo;

String normalizeCommunityImportTitle(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Server slug rule: ^[a-z0-9][a-z0-9._-]{1,63}$
String communityImportSlug(String title, {String fallback = 'import'}) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp('-{2,}'), '-')
      .replaceAll(RegExp('^[._-]+|[._-]+\$'), '');
  var result = slug.length > 64 ? slug.substring(0, 64) : slug;
  result = result.replaceAll(RegExp('[._-]+\$'), '');
  if (result.length < 2 || !RegExp('^[a-z0-9]').hasMatch(result)) {
    result = fallback;
  }
  return result;
}

String communityImportSummaryText(CommunityResourceDetail detail) {
  var value = detail.content.value;
  if (detail.content.format == ResourceContentFormat.html) {
    value = value
        .replaceAll(RegExp('<br\\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp('</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAllMapped(
          RegExp(
            '<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
            caseSensitive: false,
            dotAll: true,
          ),
          (match) => '[${match[2]}](${match[1]})',
        )
        .replaceAll(RegExp('<[^>]+>'), '');
    value = _unescapeHtmlEntities(value);
  }
  value = value.replaceAll(RegExp('\n{3,}'), '\n\n').trim();
  return _truncateRunes(value, communityImportMaxSummaryRunes);
}

String _unescapeHtmlEntities(String value) => value
    .replaceAllMapped(
      RegExp('&#(\\d+);'),
      (match) => String.fromCharCode(int.parse(match[1]!)),
    )
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

String _truncateRunes(String value, int maxRunes) {
  final runes = value.runes.toList();
  if (runes.length <= maxRunes) return value;
  return String.fromCharCodes(runes.take(maxRunes));
}

int _richness(CommunityResourceDetail detail) =>
    (detail.iconUrl != null ? 2 : 0) +
    (detail.coverUrl != null ? 2 : 0) +
    (detail.content.value.length > 200 ? 1 : 0) +
    detail.previewImages.length.clamp(0, 2);

/// One selection is one resource: AstroBox entries come first (they are the
/// canonical source), BandBBS entries follow, richest first within a source.
List<CommunityResourceDetail> communityImportOrder(
  List<CommunityResourceDetail> details,
) {
  bool isAstroBox(CommunityResourceDetail detail) =>
      detail.ref.source == CommunitySourceId.astroboxRepo;
  return [...details]..sort((a, b) {
    if (isAstroBox(a) != isAstroBox(b)) return isAstroBox(a) ? -1 : 1;
    return _richness(b).compareTo(_richness(a));
  });
}

enum CommunityImportStage { fetchingDetail, downloading, media, uploading }

typedef CommunityImportProgress = void Function(
  CommunityImportStage stage,
  int current,
  int total,
  String label,
);

enum CommunityImportRecoveryAction { retry, continueImport, cancel }

typedef CommunityImportFailureHandler =
    Future<CommunityImportRecoveryAction> Function(String item, Object error);

class CommunityImportCancelled implements Exception {
  const CommunityImportCancelled();
}

/// External identity the imported resource already has on another platform;
/// recorded into the draft manifest so later publications update it.
class CommunityImportBinding {
  const CommunityImportBinding({
    required this.provider,
    required this.externalId,
    required this.externalUrl,
    this.meta = const {},
  });

  final String provider;
  final String externalId;
  final String externalUrl;

  /// Provider extras (e.g. AstroBox repo_owner/repo_name) recorded into the
  /// binding so later publications update the external identity in place.
  final Map<String, String> meta;

  /// BandBBS section count encoded in [externalId]; 0 for other providers.
  int get bandbbsSectionCount {
    if (provider != 'bandbbs') return 0;
    final decoded = jsonDecode(externalId);
    return decoded is Map ? decoded.length : 0;
  }

  Map<String, Object?> toManifest() => {
    'provider': provider,
    'external_id': externalId,
    'external_url': externalUrl,
    if (meta.isNotEmpty) 'meta': meta,
  };
}

class CommunityImportPlan {
  const CommunityImportPlan({
    required this.details,
    required this.bindings,
    required this.warnings,
  });

  /// Ordered details: AstroBox first, richest first within a source.
  final List<CommunityResourceDetail> details;
  final List<CommunityImportBinding> bindings;
  final List<String> warnings;

  CommunityResourceDetail get primary => details.first;

  CreatorResourceKind? get kind => switch (primary.type) {
    CommunityResourceType.watchface => CreatorResourceKind.watchface,
    CommunityResourceType.canopus => CreatorResourceKind.watchface,
    CommunityResourceType.quickApp ||
    CommunityResourceType.miniprogram => CreatorResourceKind.quickApp,
    _ => null,
  };

  String get title => primary.name.trim();

  CommunityPaidType get paidType {
    if (details.any(
      (detail) => detail.paidType == CommunityPaidType.forcePaid,
    )) {
      return CommunityPaidType.forcePaid;
    }
    if (details.any((detail) => detail.paidType == CommunityPaidType.paid)) {
      return CommunityPaidType.paid;
    }
    return CommunityPaidType.free;
  }

  Uri? get purchaseLink =>
      details.map((detail) => detail.purchaseLink).whereType<Uri>().firstOrNull;

  double? get purchasePrice => details
      .map((detail) => detail.purchasePrice)
      .whereType<double>()
      .firstOrNull;

  bool get hasAstroBox => details.any(
    (detail) => detail.ref.source == CommunitySourceId.astroboxRepo,
  );

  List<({CommunityResourceDetail detail, CommunityResourceFile file})>
  get files => [
    for (final detail in details)
      for (final file in detail.files) (detail: detail, file: file),
  ];
}

enum CommunityImportStatus { created, skipped, failed }

class CommunityImportResult {
  const CommunityImportResult({
    required this.status,
    this.resourceId,
    this.bundle,
    this.bundlePath,
    this.message,
    this.warnings = const [],
  });

  final CommunityImportStatus status;
  final String? resourceId;

  /// The client-built draft bundle, retained so a failed upload can resume
  /// without downloading and packaging the external resources again.
  final Uint8List? bundle;
  final String? bundlePath;
  final String? message;
  final List<String> warnings;
}

class CommunityImportArtifact {
  CommunityImportArtifact({
    required this.name,
    required this.payload,
    required this.type,
    required this.packageId,
    required this.version,
    required this.deviceIds,
  });

  final String name;
  final Uint8List payload;
  final String type;
  final String packageId;
  final String version;
  final Set<String> deviceIds;

  String get digest => sha256.convert(payload).toString();
}

class CommunityImportMedia {
  CommunityImportMedia({
    required this.extension,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String extension;
  final Uint8List bytes;
  final int width;
  final int height;
}

class CommunityImportService {
  CommunityImportService(this._ref);

  final Ref _ref;
  static final _log = getLogger('CommunityImport');

  OronBoxCommandBus get _host => _ref.read(applicationHostProvider);

  Future<Object?> _execute(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await _host.execute(
      OronBoxCommand(method: method, params: params),
    );
    if (!result.ok) {
      throw result.error!;
    }
    return result.value;
  }

  /// Fetches full details for the selected list items; failures are reported
  /// through [onError] so the wizard can let the user retry or continue.
  Future<List<CommunityResourceDetail>> fetchDetails(
    List<CommunityResource> selected, {
    CommunityImportProgress? onProgress,
    void Function(ResourceRef ref, Object error)? onError,
  }) async {
    final details = <CommunityResourceDetail>[];
    for (var index = 0; index < selected.length; index++) {
      final item = selected[index];
      onProgress?.call(
        CommunityImportStage.fetchingDetail,
        index + 1,
        selected.length,
        'FETCH · source=${item.ref.source.storageKey} · '
        'resource=${item.ref.id} · ${item.name}',
      );
      try {
        final catalog = _ref.read(
          communityCatalogProviderForSource(item.ref.source),
        );
        final detail = await _retryImportOperation(
          () => catalog.getDetail(item.ref),
        );
        details.add(detail);
        onProgress?.call(
          CommunityImportStage.fetchingDetail,
          index + 1,
          selected.length,
          'READY · source=${item.ref.source.storageKey} · '
          'resource=${item.ref.id} · files=${detail.files.length} · '
          'previews=${detail.previewImages.length} · tags=${detail.tags.length}',
        );
      } catch (error) {
        logDiagnostic(
          _log,
          Level.WARNING,
          'Community import detail fetch failed',
          fields: {'source': item.ref.source.storageKey, 'id': item.ref.id},
          error: error.toString(),
        );
        onError?.call(item.ref, error);
      }
    }
    return details;
  }

  /// Builds the import plan for one resource: canonical ordering plus the
  /// external bindings to record. BandBBS section ids come from the resource
  /// payload itself, falling back to a title lookup in the category tree.
  Future<CommunityImportPlan> planImport(
    List<CommunityResourceDetail> details,
  ) async {
    final ordered = communityImportOrder(details);
    final warnings = <String>[];
    final bindings = <CommunityImportBinding>[];
    final astrobox = ordered
        .where((detail) => detail.ref.source == CommunitySourceId.astroboxRepo)
        .firstOrNull;
    if (astrobox != null) {
      bindings.add(
        CommunityImportBinding(
          provider: 'astrobox',
          externalId: astrobox.ref.id,
          externalUrl: astrobox.publicUrl?.toString() ?? '',
          meta: {
            'imported': 'true',
            if ((astrobox.sourceRepoOwner ?? '').isNotEmpty)
              'repo_owner': astrobox.sourceRepoOwner!,
            if ((astrobox.sourceRepoName ?? '').isNotEmpty)
              'repo_name': astrobox.sourceRepoName!,
            if ((astrobox.sourceRepoCommitHash ?? '').isNotEmpty)
              'repo_commit_hash': astrobox.sourceRepoCommitHash!,
            if (astrobox.tags.isNotEmpty) 'tags': astrobox.tags.join(';'),
            'paid_type': switch (astrobox.paidType) {
              CommunityPaidType.free => 'free',
              CommunityPaidType.paid => 'paid',
              CommunityPaidType.forcePaid => 'force_paid',
            },
            if (astrobox.authorName.isNotEmpty) 'author': astrobox.authorName,
          },
        ),
      );
    }
    final bandbbs = ordered
        .where((detail) => detail.ref.source == CommunitySourceId.bandbbs)
        .toList();
    if (bandbbs.isNotEmpty) {
      final sectionIds = await _bandbbsSectionIds();
      final targets = <String, String>{};
      for (final detail in bandbbs) {
        var sectionId = detail.sourceSectionId ?? '';
        if (sectionId.isEmpty) {
          sectionId =
              sectionIds[detail.supportedDevices.isEmpty
                  ? ''
                  : detail.supportedDevices.first] ??
              '';
        }
        if (sectionId.isEmpty) {
          warnings.add('${detail.name}: bandbbsSectionUnresolved');
          continue;
        }
        targets[sectionId] = detail.ref.id;
      }
      if (targets.isNotEmpty) {
        bindings.add(
          CommunityImportBinding(
            provider: 'bandbbs',
            externalId: jsonEncode(targets),
            externalUrl: bandbbs.first.publicUrl?.toString() ?? '',
            meta: const {'imported': 'true'},
          ),
        );
      }
    }
    return CommunityImportPlan(
      details: ordered,
      bindings: bindings,
      warnings: warnings,
    );
  }

  /// BandBBS category tree flattened to {normalized codename: section id}.
  Future<Map<String, String>> _bandbbsSectionIds() async {
    try {
      final value = await _retryImportOperation(
        () => _execute('resource.bandbbs.categories'),
      );
      final result = <String, String>{};
      void walk(Map<Object?, Object?> node) {
        final title = node['title']?.toString() ?? '';
        final id = (node['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && title.isNotEmpty) {
          final direct = normalizeXiaomiWearableCodename(title);
          if (direct.isNotEmpty) {
            result[direct] = id.toString();
          } else {
            // Merged sections ("红米手表5/6") cover several models.
            for (final expanded in _expandMergedSectionTitle(title)) {
              final codename = normalizeXiaomiWearableCodename(expanded);
              if (codename.isNotEmpty) result[codename] = id.toString();
            }
          }
        }
        for (final child
            in (node['children'] as List? ?? const []).whereType<Map>()) {
          walk(child);
        }
      }

      for (final node in (value as List? ?? const []).whereType<Map>()) {
        walk(node);
      }
      return result;
    } catch (error) {
      logDiagnostic(
        _log,
        Level.WARNING,
        'BandBBS category lookup failed',
        error: error.toString(),
      );
      return const {};
    }
  }

  /// Expands a merged section title into per-model titles, e.g.
  /// "红米手表5/6" → ["红米手表5", "红米手表6"].
  static List<String> _expandMergedSectionTitle(String title) {
    var value = title.trim();
    const suffixes = ['系列'];
    for (final suffix in suffixes) {
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length).trim();
      }
    }
    if (!value.contains('/')) return const [];
    final segments = value
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length < 2) return const [];
    final first = segments.first;
    final expanded = <String>[first];
    for (final segment in segments.skip(1)) {
      if (RegExp(r'^\d').hasMatch(segment)) {
        expanded.add('${first.replaceAll(RegExp(r'\d+$'), '')}$segment');
      } else {
        final cut = first.lastIndexOf(' ');
        if (cut > 0) expanded.add('${first.substring(0, cut + 1)}$segment');
      }
    }
    return expanded;
  }

  Future<CommunityImportResult> importPlan(
    CommunityImportPlan plan, {
    bool forceReimport = false,
    CommunityImportProgress? onProgress,
    CommunityImportFailureHandler? onFailure,
  }) async {
    final kind = plan.kind;
    if (kind == null) {
      return const CommunityImportResult(
        status: CommunityImportStatus.failed,
        message: 'unsupportedType',
      );
    }
    final name = _truncateRunes(plan.title, communityImportMaxNameRunes);
    final summary = communityImportSummaryText(plan.primary);
    if (name.trim().isEmpty || summary.trim().isEmpty) {
      return const CommunityImportResult(
        status: CommunityImportStatus.failed,
        message: 'missingMetadata',
        warnings: ['nameOrSummaryRequired'],
      );
    }
    late (Set<String>, Set<String>, Map<String, String>) existing;
    try {
      existing = await _existingCreatorResources();
    } catch (error) {
      logDiagnostic(
        _log,
        Level.WARNING,
        'Community import resource list failed',
        error: error.toString(),
      );
      return CommunityImportResult(
        status: CommunityImportStatus.failed,
        message: 'import_failed',
        warnings: plan.warnings,
      );
    }
    var slug = communityImportSlug(
      plan.title,
      fallback: 'import-${DateTime.now().millisecondsSinceEpoch}',
    );
    final existingResourceId = _matchingExternalResourceId(plan, existing.$3);
    if (existingResourceId != null && !forceReimport) {
      return CommunityImportResult(
        status: CommunityImportStatus.skipped,
        resourceId: existingResourceId,
        message: 'alreadyImported',
        warnings: plan.warnings,
      );
    }
    final duplicated =
        existing.$1.contains(slug) ||
        existing.$2.contains(normalizeCommunityImportTitle(plan.title));
    if (duplicated && !forceReimport) {
      return CommunityImportResult(
        status: CommunityImportStatus.skipped,
        message: 'duplicate',
        warnings: plan.warnings,
      );
    }
    if (duplicated) {
      var suffix = 2;
      while (existing.$1.contains('$slug-$suffix')) {
        suffix++;
      }
      slug = '$slug-$suffix';
    }
    final warnings = [...plan.warnings];
    final stopwatch = Stopwatch()..start();
    Uint8List? bundle;
    String? bundlePath;
    String? resourceId;
    try {
      final devices = await _creatorDevices();
      final artifacts = await _collectArtifacts(
        plan,
        kind: kind,
        devices: devices,
        warnings: warnings,
        onProgress: onProgress,
        onFailure: onFailure,
      );
      if (artifacts.isEmpty) {
        return CommunityImportResult(
          status: CommunityImportStatus.failed,
          message: 'noArtifacts',
          warnings: warnings,
        );
      }
      final media = await _collectMedia(
        plan,
        warnings: warnings,
        onProgress: onProgress,
        onFailure: onFailure,
      );
      bundle = buildCommunityImportBundle(
        kind: kind,
        name: name,
        summary: summary,
        paidType: plan.paidType,
        links: _importLinks(plan),
        icon: media.$1,
        cover: media.$2,
        previews: media.$3,
        artifacts: artifacts,
        bindings: plan.bindings,
        purchaseLink: plan.purchaseLink,
        purchasePrice: plan.purchasePrice,
      );
      onProgress?.call(
        CommunityImportStage.uploading,
        1,
        3,
        'BUNDLE · ${bundle.length} bytes · ${artifacts.length} artifacts · '
        '${media.$3.length + (media.$1 == null ? 0 : 1) + (media.$2 == null ? 0 : 1)} media',
      );
      onProgress?.call(
        CommunityImportStage.uploading,
        2,
        3,
        'CREATE · slug=$slug · kind=${kind.name}',
      );
      final created = CreatorWorkspace.fromJson(
        _map(
          await _retryImportOperation(
            () => _execute('creator.create', {
              'slug': slug,
              'name': _truncateRunes(plan.title, communityImportMaxNameRunes),
              'kind': kind == CreatorResourceKind.watchface
                  ? 'watchface'
                  : 'quickapp',
            }),
          ),
        ),
      );
      resourceId = created.resource.id;
      final saved = CreatorWorkspace.fromJson(
        _map(
          await _retryImportOperation(
            () => _execute('creator.draft', {
              'resource': resourceId,
              'bundle': base64Encode(bundle!),
            }),
          ),
        ),
      );
      validateCommunityImportBindings(plan.bindings, saved.bindings);
      onProgress?.call(
        CommunityImportStage.uploading,
        3,
        3,
        'SAVED · resource=$resourceId · bindings=${saved.bindings.length}',
      );
      logDiagnostic(
        _log,
        Level.INFO,
        'Community resource imported',
        fields: {
          'title': plan.title,
          'slug': slug,
          'sources': plan.details
              .map((detail) => detail.ref.source.storageKey)
              .toSet()
              .join(','),
          'artifacts': artifacts.length,
          'bindings': plan.bindings.length,
          'bundleBytes': bundle.length,
          'warnings': warnings.length,
          if (warnings.isNotEmpty) 'warningList': warnings.join('; '),
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return CommunityImportResult(
        status: CommunityImportStatus.created,
        resourceId: resourceId,
        warnings: warnings,
      );
    } catch (error) {
      resourceId ??= await _findCreatorResourceIdBySlug(slug);
      if (bundle != null) {
        bundlePath = await _persistImportBundle(bundle, slug);
      }
      logDiagnostic(
        _log,
        Level.WARNING,
        'Community import failed',
        fields: {'title': plan.title},
        error: error.toString(),
      );
      return CommunityImportResult(
        status: CommunityImportStatus.failed,
        resourceId: resourceId,
        bundle: bundle,
        bundlePath: bundlePath,
        // Keep implementation details in diagnostics; the wizard localizes
        // this stable result code for users.
        message: 'import_failed',
        warnings: warnings,
      );
    }
  }

  /// Resumes the client-built draft upload after `creator.create` succeeded
  /// but the first upload was interrupted. No external resource is fetched or
  /// repackaged on this path.
  Future<CommunityImportResult> resumeDraft({
    required String resourceId,
    Uint8List? bundle,
    String? bundlePath,
    required List<CommunityImportBinding> bindings,
  }) async {
    bundle ??= bundlePath == null ? null : await File(bundlePath).readAsBytes();
    if (bundle == null) {
      return CommunityImportResult(
        status: CommunityImportStatus.failed,
        resourceId: resourceId,
        message: 'import_failed',
      );
    }
    try {
      final saved = CreatorWorkspace.fromJson(
        _map(
          await _retryImportOperation(
            () => _execute('creator.draft', {
              'resource': resourceId,
              'bundle': base64Encode(bundle!),
            }),
          ),
        ),
      );
      validateCommunityImportBindings(bindings, saved.bindings);
      if (bundlePath != null) {
        try {
          await File(bundlePath).delete();
        } catch (_) {
          // Recovery data is best effort and should not turn a successful
          // resume into a failed import.
        }
      }
      return CommunityImportResult(
        status: CommunityImportStatus.created,
        resourceId: resourceId,
      );
    } catch (error) {
      logDiagnostic(
        _log,
        Level.WARNING,
        'Community draft resume failed',
        fields: {'resource': resourceId},
        error: error.toString(),
      );
      return CommunityImportResult(
        status: CommunityImportStatus.failed,
        resourceId: resourceId,
        bundle: bundle,
        bundlePath: bundlePath,
        message: 'import_failed',
      );
    }
  }

  Future<String?> _persistImportBundle(Uint8List bundle, String slug) async {
    try {
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/import-recovery',
      );
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/$slug-${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      await file.writeAsBytes(bundle, flush: true);
      return file.path;
    } catch (error) {
      logDiagnostic(
        _log,
        Level.WARNING,
        'Community import recovery bundle could not be persisted',
        error: error.toString(),
      );
      return null;
    }
  }

  /// Existing creator resources as (slugs, lowercase names) for dedupe.
  String? _matchingExternalResourceId(
    CommunityImportPlan plan,
    Map<String, String> externalResources,
  ) {
    final astro = plan.details
        .where((detail) => detail.ref.source == CommunitySourceId.astroboxRepo)
        .map((detail) => externalResources['astrobox:${detail.ref.id}'])
        .whereType<String>()
        .firstOrNull;
    if (astro != null) return astro;
    for (final detail in plan.details.where(
      (detail) => detail.ref.source == CommunitySourceId.bandbbs,
    )) {
      final found = externalResources['bandbbs:${detail.ref.id}'];
      if (found != null) return found;
    }
    return null;
  }

  Future<String?> _findCreatorResourceIdBySlug(String slug) async {
    try {
      final root = _map(
        await _retryImportOperation(() => _execute('creator.list')),
      );
      for (final item in (root['resources'] as List? ?? const [])) {
        if (item is! Map) continue;
        final resource = item['resource'];
        if (resource is Map && resource['slug']?.toString() == slug) {
          return resource['id']?.toString();
        }
      }
    } catch (_) {
      // Preserve the original import failure if recovery lookup also fails.
    }
    return null;
  }

  Future<(Set<String>, Set<String>, Map<String, String>)>
  _existingCreatorResources() async {
    final root = _map(
      await _retryImportOperation(() => _execute('creator.list')),
    );
    final slugs = <String>{};
    final names = <String>{};
    final externalResources = <String, String>{};
    for (final item
        in (root['resources'] as List? ?? const []).whereType<Map>()) {
      final resource = item['resource'];
      if (resource is! Map) continue;
      final slug = resource['slug']?.toString() ?? '';
      final name = resource['draft_name']?.toString() ?? '';
      if (slug.isNotEmpty) slugs.add(slug);
      if (name.isNotEmpty) names.add(name.toLowerCase());
      final resourceId = resource['id']?.toString() ?? '';
      for (final binding in (item['bindings'] as List? ?? const [])) {
        if (binding is! Map || resourceId.isEmpty) continue;
        final provider = binding['provider']?.toString() ?? '';
        final externalID = binding['external_id']?.toString() ?? '';
        if (provider == 'astrobox' && externalID.isNotEmpty) {
          externalResources['astrobox:$externalID'] = resourceId;
        } else if (provider == 'bandbbs') {
          Object? decoded;
          try {
            decoded = jsonDecode(externalID);
          } catch (_) {
            decoded = null;
          }
          if (decoded is Map) {
            for (final value in decoded.values) {
              externalResources['bandbbs:$value'] = resourceId;
            }
          }
        }
      }
    }
    return (slugs, names, externalResources);
  }

  Future<List<CreatorDevice>> _creatorDevices() async {
    final root = _map(
      await _retryImportOperation(() => _execute('creator.devices')),
    );
    return (root['devices'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CreatorDevice.fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<List<CommunityImportArtifact>> _collectArtifacts(
    CommunityImportPlan plan, {
    required CreatorResourceKind kind,
    required List<CreatorDevice> devices,
    required List<String> warnings,
    CommunityImportProgress? onProgress,
    CommunityImportFailureHandler? onFailure,
  }) async {
    final deviceIdsByCodename = <String, String>{
      for (final device in devices)
        normalizeXiaomiWearableCodename(device.codename): device.id,
      for (final device in devices)
        if (device.astroBoxId.isNotEmpty) device.astroBoxId: device.id,
    };
    final install = _ref.read(resourceInstallServiceProvider);
    final artifacts = <CommunityImportArtifact>[];
    final byDigest = <String, CommunityImportArtifact>{};
    // Server rule: one device binds at most one artifact per bundle. AstroBox
    // files come first, so a BandBBS file only claims devices AstroBox did
    // not cover (or failed to deliver).
    final claimedDevices = <String>{};
    // One URL is downloaded once; per-device entries in an AstroBox manifest
    // usually point at the same file.
    final groups =
        <
          String,
          ({
            CommunityResourceDetail detail,
            CommunityResourceFile file,
            Set<String> devices,
          })
        >{};
    final order = <String>[];
    for (final item in plan.files) {
      final url = item.file.downloadUrl?.toString() ?? '';
      final key = url.isEmpty ? 'unique:${order.length}' : url;
      final group = groups[key];
      if (group == null) {
        groups[key] = (
          detail: item.detail,
          file: item.file,
          devices: {...item.file.supportedDevices},
        );
        order.add(key);
      } else {
        group.devices.addAll(item.file.supportedDevices);
      }
    }
    for (var index = 0; index < order.length; index++) {
      final (:detail, :file, :devices) = groups[order[index]]!;
      onProgress?.call(
        CommunityImportStage.downloading,
        index + 1,
        order.length,
        '${detail.ref.source.storageKey} · resource=${detail.ref.id} · '
        '${file.fileName} · devices=${devices.join(',')}',
      );
      final catalog = _ref.read(
        communityCatalogProviderForSource(detail.ref.source),
      );
      // BandBBS paid downloads are license-encrypted; importing them would
      // produce an undecodable artifact.
      if (detail.ref.source == CommunitySourceId.bandbbs &&
          detail.paidType == CommunityPaidType.paid) {
        warnings.add('${file.label}: paidEncrypted');
        continue;
      }
      Uint8List? bytes;
      while (true) {
        try {
          final downloaded = await _retryImportOperation(() async {
            final result = await catalog.download(
              CommunityDownloadRequest(resource: detail, file: file),
            );
            return result.bytes ??
                (result.path.isNotEmpty
                    ? await File(result.path).readAsBytes()
                    : null);
          });
          final downloadedBytes = downloaded;
          if (downloadedBytes == null || downloadedBytes.isEmpty) {
            throw StateError('download returned no bytes');
          }
          bytes = downloadedBytes;
          break;
        } catch (error) {
          final action =
              await onFailure?.call(file.label, error) ??
              CommunityImportRecoveryAction.continueImport;
          if (action == CommunityImportRecoveryAction.retry) continue;
          if (action == CommunityImportRecoveryAction.cancel) {
            throw const CommunityImportCancelled();
          }
          warnings.add('${file.label}: downloadFailed');
          logDiagnostic(
            _log,
            Level.WARNING,
            'Community import download failed',
            fields: {'file': file.fileName},
            error: error.toString(),
          );
          break;
        }
      }
      if (bytes == null) continue;
      final analysis = install.analyzePayload(
        fileName: file.fileName,
        bytes: bytes,
        source: 'community-import',
      );
      final isApp = analysis?.type == LocalDeviceInstallType.app;
      final isWatchface = analysis?.type == LocalDeviceInstallType.watchface;
      if (analysis == null ||
          analysis.platform != ResourcePlatform.vela ||
          (!isApp && !isWatchface)) {
        warnings.add('${file.label}: invalidPackage');
        continue;
      }
      if ((kind == CreatorResourceKind.quickApp) != isApp) {
        warnings.add('${file.label}: kindMismatch');
        continue;
      }
      final deviceIds = devices
          .map(
            (codename) =>
                deviceIdsByCodename[normalizeXiaomiWearableCodename(
                  codename,
                )] ??
                deviceIdsByCodename[codename],
          )
          .nonNulls
          .where((id) => !claimedDevices.contains(id))
          .toSet();
      if (devices.isNotEmpty && deviceIds.isEmpty) {
        warnings.add('${file.label}: deviceUnavailable');
        continue;
      }
      final artifact = CommunityImportArtifact(
        name: file.fileName,
        payload: analysis.payload,
        type: isApp ? 'velaos_quickapp' : 'velaos_watchface',
        packageId: analysis.identifier ?? '',
        version: analysis.version ?? file.version,
        deviceIds: deviceIds,
      );
      logDiagnostic(
        _log,
        Level.INFO,
        'Community import file accepted',
        fields: {
          'file': file.fileName,
          'bytes': bytes.length,
          'devices': deviceIds.length,
        },
      );
      onProgress?.call(
        CommunityImportStage.downloading,
        index + 1,
        order.length,
        'ACCEPTED · ${file.fileName} · ${bytes.length} bytes · '
        'package=${artifact.packageId} · version=${artifact.version} · '
        'deviceIds=${deviceIds.join(',')}',
      );
      final existing = byDigest[artifact.digest];
      if (existing != null) {
        existing.deviceIds.addAll(deviceIds);
        claimedDevices.addAll(deviceIds);
        continue;
      }
      byDigest[artifact.digest] = artifact;
      artifacts.add(artifact);
      claimedDevices.addAll(deviceIds);
    }
    if (artifacts.isEmpty) {
      warnings.add('noArtifacts');
    }
    return artifacts;
  }

  Future<
    (CommunityImportMedia?, CommunityImportMedia?, List<CommunityImportMedia>)
  >
  _collectMedia(
    CommunityImportPlan plan, {
    required List<String> warnings,
    CommunityImportProgress? onProgress,
    CommunityImportFailureHandler? onFailure,
  }) async {
    final primary = plan.primary;
    // BandBBS has no real cover (its catalog fills it with the icon), so a
    // cover is only taken from AstroBox.
    final coverUrl = primary.ref.source == CommunitySourceId.astroboxRepo
        ? primary.coverUrl
        : null;
    final previews = plan.details
        .expand((detail) => detail.previewImages)
        .take(communityImportMaxPreviews)
        .toList(growable: false);
    final total =
        (primary.iconUrl == null ? 0 : 1) +
        (coverUrl == null ? 0 : 1) +
        previews.length;
    var done = 0;
    final icon = await _downloadImage(
      primary.iconUrl,
      maxDimension: creatorIconMaxDimension,
      onDone: (label) =>
          onProgress?.call(CommunityImportStage.media, ++done, total, label),
      onError: () => warnings.add('icon: downloadFailed'),
      onFailure: onFailure,
    );
    final cover = await _downloadImage(
      coverUrl,
      maxDimension: creatorMediaMaxDimension,
      onDone: (label) =>
          onProgress?.call(CommunityImportStage.media, ++done, total, label),
      onError: () => warnings.add('cover: downloadFailed'),
      onFailure: onFailure,
    );
    final importedPreviews = <CommunityImportMedia>[];
    for (final preview in previews) {
      final media = await _downloadImage(
        preview.url,
        onDone: (label) =>
            onProgress?.call(CommunityImportStage.media, ++done, total, label),
        onFailure: onFailure,
      );
      if (media != null) importedPreviews.add(media);
    }
    return (icon, cover, importedPreviews);
  }

  Future<CommunityImportMedia?> _downloadImage(
    Uri? url, {
    int maxDimension = creatorMediaMaxDimension,
    void Function(String label)? onDone,
    void Function()? onError,
    CommunityImportFailureHandler? onFailure,
  }) async {
    if (url == null) return null;
    while (true) {
      try {
        final response = await _retryImportOperation(
          () => _ref
              .read(appDioProvider)
              .get<List<int>>(
                url.toString(),
                options: Options(responseType: ResponseType.bytes),
              ),
        );
        final raw = Uint8List.fromList(response.data ?? const []);
        final processed = await processResourceImage(
          raw,
          maxDimension: maxDimension,
        );
        if (processed == null) throw StateError('undecodable image');
        final name = url.pathSegments.isEmpty
            ? url.host
            : url.pathSegments.last;
        onDone?.call(
          '$name · ${raw.length} bytes · ${processed.width}x${processed.height} · '
          'webp=${processed.bytes.length} bytes',
        );
        return CommunityImportMedia(
          extension: 'webp',
          bytes: processed.bytes,
          width: processed.width,
          height: processed.height,
        );
      } catch (error) {
        final action =
            await onFailure?.call(url.toString(), error) ??
            CommunityImportRecoveryAction.continueImport;
        if (action == CommunityImportRecoveryAction.retry) continue;
        if (action == CommunityImportRecoveryAction.cancel) {
          throw const CommunityImportCancelled();
        }
        logDiagnostic(
          _log,
          Level.WARNING,
          'Community import media failed',
          fields: {'url': url.toString()},
          error: error.toString(),
        );
        onError?.call();
        return null;
      }
    }
  }

  List<Map<String, String>> _importLinks(CommunityImportPlan plan) {
    final links = <Map<String, String>>[];
    for (final link in plan.primary.links) {
      final url = link.url.toString();
      if (link.title.trim().isEmpty ||
          link.title.trim().length > 80 ||
          (!url.startsWith('http://') && !url.startsWith('https://'))) {
        continue;
      }
      links.add({'title': link.title.trim(), 'url': url});
    }
    final seenSources = <CommunitySourceId>{};
    for (final detail in plan.details) {
      if (!seenSources.add(detail.ref.source)) continue;
      final publicUrl = detail.publicUrl?.toString() ?? '';
      if (publicUrl.startsWith('http')) {
        links.add({'title': detail.ref.source.displayName, 'url': publicUrl});
      }
    }
    return links.take(16).toList();
  }
}

final communityImportServiceProvider = Provider<CommunityImportService>(
  CommunityImportService.new,
);

/// Builds the creator draft zip (manifest.json + media + artifacts).
Uint8List buildCommunityImportBundle({
  required CreatorResourceKind kind,
  required String name,
  required String summary,
  CommunityPaidType paidType = CommunityPaidType.free,
  required List<Map<String, String>> links,
  required List<CommunityImportArtifact> artifacts,
  CommunityImportMedia? icon,
  CommunityImportMedia? cover,
  List<CommunityImportMedia> previews = const [],
  List<CommunityImportBinding> bindings = const [],
  Uri? purchaseLink,
  double? purchasePrice,
}) {
  final archive = Archive();
  void addFile(String path, Uint8List bytes) =>
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
  String digest(Uint8List bytes) => sha256.convert(bytes).toString();
  Map<String, Object?> mediaRef(CommunityImportMedia media, String path) => {
    'file': path,
    'sha256': digest(media.bytes),
    'width': media.width,
    'height': media.height,
  };
  final media = <String, Object?>{};
  if (icon != null) {
    final path = 'media/icon.webp';
    addFile(path, icon.bytes);
    media['icon'] = mediaRef(icon, path);
  }
  if (cover != null) {
    final path = 'media/cover.webp';
    addFile(path, cover.bytes);
    media['cover'] = mediaRef(cover, path);
  }
  media['previews'] = [
    for (var index = 0; index < previews.length; index++)
      () {
        final path = 'media/preview-$index.webp';
        addFile(path, previews[index].bytes);
        return mediaRef(previews[index], path);
      }(),
  ];
  final manifest = utf8.encode(
    jsonEncode({
      'version': 1,
      'kind': kind == CreatorResourceKind.watchface ? 'watchface' : 'quickapp',
      'name': name,
      'description': summary,
      'description_format': 'markdown',
      'summary': '',
      'paid_type': communityPaidTypeToWire(paidType),
      if (purchaseLink != null) 'purchase_link': purchaseLink.toString(),
      if (purchaseLink != null && purchasePrice != null)
        'purchase_price': purchasePrice,
      if (purchaseLink != null) 'purchase_currency': 'CNY',
      'attributes': const <String>[],
      'links': links,
      'media': media,
      'artifacts': [
        for (var index = 0; index < artifacts.length; index++)
          () {
            final artifact = artifacts[index];
            final path = 'artifacts/$index.bin';
            addFile(path, artifact.payload);
            return <String, Object?>{
              'file': path,
              'original_name': artifact.name,
              'type': artifact.type,
              'package_id': artifact.packageId,
              'package_version': artifact.version,
              'sha256': artifact.digest,
              'device_ids': artifact.deviceIds.toList(),
            };
          }(),
      ],
      // No publications key: the server stores a null plan, marking that the
      // creator has not chosen publish targets yet (editor derives from bindings).
      'bindings': [for (final binding in bindings) binding.toManifest()],
    }),
  );
  addFile('manifest.json', manifest);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, Object?> _map(Object? value) =>
    (value as Map?)?.cast<String, Object?>() ?? const {};

void validateCommunityImportBindings(
  List<CommunityImportBinding> expected,
  List<Map<String, Object?>> actual,
) {
  final byProvider = {
    for (final binding in actual)
      binding['provider']?.toString() ?? '': binding,
  };
  for (final wanted in expected) {
    final stored = byProvider[wanted.provider];
    if (stored == null ||
        stored['external_id']?.toString() != wanted.externalId) {
      throw StateError('${wanted.provider}: imported binding was not saved');
    }
    final storedMeta = stored['meta'];
    for (final entry in wanted.meta.entries) {
      if (storedMeta is! Map ||
          storedMeta[entry.key]?.toString() != entry.value) {
        throw StateError(
          '${wanted.provider}: imported binding ${entry.key} was not saved',
        );
      }
    }
  }
}
