import 'dart:async';

import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';

class CommandResourceCatalog implements CommunityResourceCatalog {
  CommandResourceCatalog({required this.host, required this.sourceId});

  final OronBoxCommandBus host;

  @override
  final CommunitySourceId sourceId;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities => switch (sourceId) {
    CommunitySourceId.oronBox => const CommunityCatalogCapabilities(
      serverSort: true,
    ),
    CommunitySourceId.astroboxRepo => const CommunityCatalogCapabilities(
      serverSort: false,
    ),
    CommunitySourceId.bandbbs || CommunitySourceId.huamiAppStore =>
      const CommunityCatalogCapabilities(serverSort: true),
    _ => const CommunityCatalogCapabilities(
      serverSort: true,
      typeFilter: false,
    ),
  };

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final value = await _execute(
      OronBoxCommand(
        method: 'resource.list',
        params: {
          'source': sourceId.storageKey,
          'page': query.page,
          'pageSize': query.pageSize,
          'query': query.query,
          'sort': query.sort.name,
          if (query.type != null)
            'type': switch (query.type!) {
              CommunityResourceType.quickApp => 'quickapp',
              CommunityResourceType.miniprogram => 'miniprogram',
              CommunityResourceType.canopus => 'canopus',
              _ => query.type!.name,
            },
          'hidePaid': query.hidePaid,
          'hideForcePaid': query.hideForcePaid,
          'featured': query.featured,
          'devices': query.selectedDevices.toList(growable: false),
          'attributes': query.selectedAttributes.toList(growable: false),
        },
      ),
    );
    final json = (value as Map).cast<String, Object?>();
    return CommunityResourcePage(
      items: (json['items'] as List)
          .whereType<Map>()
          .map((row) => communityResourceFromJson(row.cast<String, Object?>()))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? query.page,
      hasMore: json['hasMore'] == true,
      total: (json['total'] as num?)?.toInt(),
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    final value = await _execute(
      OronBoxCommand(method: 'resource.info', params: {'ref': ref.key}),
    );
    return communityResourceDetailFromJson(
      (value as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final value = await _execute(
      OronBoxCommand(
        method: 'resource.devices',
        params: {'source': sourceId.storageKey},
      ),
    );
    return (value as List).whereType<Map>().map((row) {
      final json = row.cast<String, Object?>();
      return CommunityResourceDevice(
        codename: json['codename']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
    }).toList();
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    final queued = await _execute(
      OronBoxCommand(
        method: 'task.enqueue',
        params: {
          'command': OronBoxCommand(
            method: 'resource.download',
            params: {
              'ref': request.resource.ref.key,
              'file': request.file.id,
              if (request.targetDevice != null)
                'targetDevice': request.targetDevice,
            },
          ).toJson(),
        },
      ),
    );
    final taskId = (queued as Map)['taskId']!.toString();
    final subscription = host.events.listen((event) {
      if (event.event != 'task' || event.data['id']?.toString() != taskId) {
        return;
      }
      final progress = (event.data['progress'] as num?)?.toDouble();
      if (progress != null) {
        request.onProgress?.call(
          progress,
          status: event.data['status']?.toString() ?? '',
        );
      }
    });
    try {
      final task = (await _execute(
        OronBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      ) as Map).cast<String, Object?>();
      final nested = CommandResult.fromJson(
        (task['result'] as Map).cast<String, Object?>(),
      );
      if (!nested.ok) {
        throw nested.error!;
      }
      final result = (nested.value as Map).cast<String, Object?>();
      return CommunityResourceDownloadResult(
        path: result['path']!.toString(),
        fileName: result['fileName']!.toString(),
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    final value = await _execute(
      OronBoxCommand(
        method: 'resource.probe',
        params: {
          'source': sourceId.storageKey,
          'file': communityResourceFileToJson(file),
        },
      ),
    );
    return (value as num?)?.toInt();
  }

  Future<Object?> _execute(OronBoxCommand command) async {
    final result = await host.execute(command);
    if (!result.ok) {
      throw result.error!;
    }
    return result.value;
  }
}
