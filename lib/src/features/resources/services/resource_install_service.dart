import 'package:oronbox/src/core/storage/managed_temporary_files.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/watchface_install_policy.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';
import 'package:oronbox/src/features/resources/services/resource_task_status.dart';

export 'resource_task_status.dart';
export 'resource_payload_analyzer.dart'
    show LocalDeviceInstallType, ResourceInstallMode;

class DownloadedResource {
  const DownloadedResource({
    required this.path,
    required this.fileName,
    this.bytes,
  });

  final String path;
  final String fileName;
  final Uint8List? bytes;
}

class ResourceInstallService {
  ResourceInstallService({ResourcePayloadAnalyzer? analyzer})
    : _analyzer = analyzer ?? ResourcePayloadAnalyzer();

  final ResourcePayloadAnalyzer _analyzer;
  static final _log = getLogger('ResourceInstallService');

  ResourcePayloadAnalysis? analyzePayload({
    required String fileName,
    required Uint8List bytes,
    LocalDeviceInstallType? hint,
    String source = 'manual',
  }) => _analyzer.analyze(
    fileName: fileName,
    bytes: bytes,
    hint: hint,
    source: source,
  );

  Future<DownloadedResource?> downloadResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required CommunityResourceCatalog catalog,
    String? targetDevice,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    var lastProgress = 0.0;

    void report(ResourceTaskStatus status, double progress, String? error) {
      final normalized = progress.clamp(0.0, 1.0).toDouble();
      if (status != ResourceTaskStatus.failed && normalized < lastProgress) {
        return;
      }
      if (status != ResourceTaskStatus.failed && normalized > lastProgress) {
        lastProgress = normalized;
      }
      onUpdate(
        status,
        status == ResourceTaskStatus.failed ? normalized : lastProgress,
        error,
      );
    }

    report(ResourceTaskStatus.downloading, 0, null);
    if (!resource.canDownload) {
      report(
        ResourceTaskStatus.failed,
        0,
        'This resource is not available for download with the current account',
      );
      return null;
    }
    if (resource.downloadRestriction ==
        CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted) {
      report(
        ResourceTaskStatus.failed,
        0,
        'AstroBox Creator Console encrypted resources are not supported',
      );
      return null;
    }
    try {
      final result = await catalog.download(
        CommunityDownloadRequest(
          resource: resource,
          file: file,
          targetDevice: targetDevice,
          onProgress: (progress, {status = ''}) =>
              report(ResourceTaskStatus.downloading, progress, null),
        ),
      );
      report(ResourceTaskStatus.completed, 1, null);
      return DownloadedResource(
        path: result.path,
        fileName: result.fileName,
        bytes: result.bytes,
      );
    } catch (e) {
      report(ResourceTaskStatus.failed, 0, 'Download failed: $e');
      return null;
    }
  }

  Future<void> installDownloadedResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String filePath,
    Uint8List? bytes,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
    bool deleteAfterInstall = false,
  }) async {
    onUpdate(ResourceTaskStatus.installing, 0, null);
    try {
      final payload = bytes ?? await File(filePath).readAsBytes();
      await _analyzeAndInstall(
        typeHint: _catalogTypeHint(resource.type),
        source: 'catalog:${resource.ref.source.storageKey}',
        fileName: file.fileName,
        bytes: payload,
        deviceManager: deviceManager,
        onProgress: (progress) =>
            onUpdate(ResourceTaskStatus.installing, progress, null),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    } finally {
      if (deleteAfterInstall && !kIsWeb) {
        try {
          await ManagedTemporaryFiles.release(filePath);
          if (await File(filePath).exists()) await File(filePath).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> installLocalFile({
    required String filePath,
    Uint8List? bytes,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    onUpdate(ResourceTaskStatus.installing, 0, null);

    final fileName = Uri.tryParse(filePath)?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(Uri.parse(filePath).pathSegments.last)
        : filePath;

    Uint8List payload;
    try {
      payload = bytes ?? await File(filePath).readAsBytes();
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Read failed: $e');
      return;
    }

    final analysis = _analyzer.analyze(
      fileName: fileName,
      bytes: payload,
      source: 'local',
    );
    if (analysis == null) {
      onUpdate(
        ResourceTaskStatus.failed,
        0,
        'Unsupported or ambiguous file type: $fileName',
      );
      return;
    }

    try {
      await _installAnalysis(
        analysis: analysis,
        fileName: fileName,
        deviceManager: deviceManager,
        onProgress: (progress) =>
            onUpdate(ResourceTaskStatus.installing, progress, null),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    }
  }

  /// Installs an already loaded local payload and propagates failures to the
  /// caller. GUI queue code wraps this method to update task state, while CLI
  /// callers use the thrown error to produce a reliable process exit code.
  Future<void> installLocalPayload({
    required LocalDeviceInstallType type,
    required String fileName,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
    String? identifierOverride,
  }) async {
    await _analyzeAndInstall(
      typeHint: type,
      source: 'local-explicit',
      fileName: fileName,
      bytes: bytes,
      deviceManager: deviceManager,
      identifierOverride: identifierOverride,
      onProgress: onProgress,
    );
  }

  Future<void> installAnalyzedPayload({
    required ResourcePayloadAnalysis analysis,
    required String fileName,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
    String? identifierOverride,
    bool forcePlatform = false,
  }) async {
    if (forcePlatform) {
      _log.warning(
        'forcing cross-platform resource install file="$fileName" '
        'platform=${analysis.platform.name} type=${analysis.type.name}',
      );
    }
    await _installAnalysis(
      analysis: analysis,
      fileName: fileName,
      deviceManager: deviceManager,
      onProgress: onProgress,
      identifierOverride: identifierOverride,
      validatePlatform: !forcePlatform,
    );
  }

  Future<void> installForcedPayload({
    required LocalDeviceInstallType type,
    required String fileName,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
    String? identifierOverride,
  }) async {
    _log.warning(
      'forcing resource install file="$fileName" bytes=${bytes.length} '
      'type=${type.name}',
    );
    await _installAnalysis(
      analysis: ResourcePayloadAnalysis(
        type: type,
        platform: ResourcePlatform.vela,
        packageKind: ResourcePackageKind.rawPayload,
        payload: bytes,
        evidence: const ['user forced install type'],
      ),
      fileName: fileName,
      deviceManager: deviceManager,
      onProgress: onProgress,
      identifierOverride: identifierOverride,
      validatePlatform: false,
    );
  }

  Future<void> _analyzeAndInstall({
    required LocalDeviceInstallType? typeHint,
    required String source,
    required String fileName,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
    String? identifierOverride,
  }) async {
    final analysis = _analyzer.analyze(
      fileName: fileName,
      bytes: bytes,
      hint: typeHint,
      source: source,
    );
    if (analysis == null) {
      throw FormatException('Unsupported or unrecognized resource: $fileName');
    }
    await _installAnalysis(
      analysis: analysis,
      fileName: fileName,
      deviceManager: deviceManager,
      identifierOverride: identifierOverride,
      onProgress: onProgress,
    );
  }

  Future<void> _installAnalysis({
    required ResourcePayloadAnalysis analysis,
    required String fileName,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
    String? identifierOverride,
    bool validatePlatform = true,
  }) async {
    if (analysis.type == LocalDeviceInstallType.watchface) {
      final restrictedId = restrictedWatchfaceIdFor(
        payload: analysis.payload,
        identifier: identifierOverride,
        analyzedIdentifier: analysis.identifier,
        fallbackIdentifier: _guessWatchfaceId(fileName),
      );
      if (restrictedId != null) {
        _log.warning(
          'blocked restricted watchface install id=$restrictedId '
          'file="$fileName"',
        );
        throw WatchfaceInstallBlockedException(restrictedId);
      }
    }
    final resourceKind = analysis.platform == ResourcePlatform.zeppOs
        ? DeviceKind.zepp
        : DeviceKind.xiaomi;
    final deviceKind = deviceManager.currentDeviceKind;
    if (validatePlatform && deviceKind != null && deviceKind != resourceKind) {
      throw UnsupportedError(
        '${analysis.platform.name} resource cannot be installed on '
        '${deviceKind == DeviceKind.zepp ? 'ZeppOS' : 'VelaOS'}',
      );
    }
    final bytes = analysis.payload;
    switch (analysis.type) {
      case LocalDeviceInstallType.app:
        await deviceManager.installApp(
          bytes,
          packageName:
              identifierOverride ??
              analysis.identifier ??
              _guessPackageName(fileName),
          onProgress: onProgress,
        );
      case LocalDeviceInstallType.watchface:
        await deviceManager.installWatchface(
          bytes,
          watchfaceId:
              identifierOverride ??
              analysis.identifier ??
              _guessWatchfaceId(fileName),
          onProgress: onProgress,
        );
      case LocalDeviceInstallType.firmware:
        await deviceManager.installFirmware(bytes, onProgress: onProgress);
    }
  }

  LocalDeviceInstallType? detectLocalInstallType(
    String fileName,
    Uint8List bytes,
  ) {
    return _analyzer
        .analyze(fileName: fileName, bytes: bytes, source: 'type-probe')
        ?.type;
  }

  static LocalDeviceInstallType? _catalogTypeHint(CommunityResourceType type) =>
      switch (type) {
        CommunityResourceType.quickApp => LocalDeviceInstallType.app,
        CommunityResourceType.miniprogram => LocalDeviceInstallType.app,
        CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
        CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
        CommunityResourceType.canopus => LocalDeviceInstallType.watchface,
      };

  String _guessPackageName(String fileName) {
    final name = fileName.split('.').first;
    if (name.isEmpty) return 'com.oronbox.unknown';
    final sanitized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return 'com.oronbox.$sanitized';
  }

  String _guessWatchfaceId(String fileName) {
    return fileName.split('.').first;
  }
}

final resourceInstallServiceProvider = Provider<ResourceInstallService>((ref) {
  return ResourceInstallService();
});

extension ResourceTypeLabel on CommunityResourceType {
  String get fileExtensionHint {
    return switch (this) {
      CommunityResourceType.quickApp => 'bin/rpk/zpk/zab/zip',
      CommunityResourceType.miniprogram => 'zpk/zab/zip',
      CommunityResourceType.watchface => 'bin/face/mwz/zip',
      CommunityResourceType.firmware => 'zip/bin',
      CommunityResourceType.canopus => 'bin/face/mwz/zip',
    };
  }
}
