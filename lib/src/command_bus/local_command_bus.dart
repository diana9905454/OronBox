import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/command_bus/command_observability.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/logging/file_log_sink.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/watchface_install_policy.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/data/huami/huami_app_store_resource_provider.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/device_log_archive.dart';
import 'package:oronbox/src/features/devices/services/phone_finder.dart';
import 'package:oronbox/src/features/devices/controllers/interconnect_event_codec.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/huami_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_service.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/debug/application/debug_environment.dart';
import 'package:oronbox/src/features/plugins/application/plugin_community_catalog.dart';
import 'package:oronbox/src/features/plugins/application/plugin_manager.dart';
import 'package:oronbox/src/features/plugins/application/plugin_repositories.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/application/creator/oronbox_creator_api.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/host/application_host.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

class LocalCommandBus implements OronBoxCommandBus, ActiveOperationController {
  static final _log = getLogger('LocalCommandBus');

  LocalCommandBus(this.container) {
    _deviceManagerSubscription = container.listen<DeviceManagerState>(
      deviceManagerProvider,
      (_, state) => _events.add(
        CommandEvent(
          'device.state',
          data: {'state': _wireValue(_deviceStateJson(state))},
        ),
      ),
      fireImmediately: true,
    );
    _bandBbsAuthSubscription = container.listen<BandBbsAuthState>(
      bandBbsAuthProvider,
      (previous, next) {
        if (previous?.isSignedIn == next.isSignedIn &&
            previous?.userId == next.userId &&
            previous?.lastError == next.lastError) {
          return;
        }
        _events.add(
          CommandEvent(
            'account.state',
            data: {
              'state': _wireValue([
                _accountStatus('xiaomi'),
                _accountStatus('amazfit'),
                _accountStatus('bandbbs'),
              ]),
              if (next.lastError case final reason?) 'reason': reason,
            },
          ),
        );
      },
    );
    _logSubscription = oronBoxDiagnosticStream.listen(
      (event) => _events.add(
        CommandEvent('debug.log', data: {'record': event.toJson()}),
      ),
    );
    _xiaoAiSubscription = _manager.xiaoAiOpusFrames.listen(
      (frame) => _events.add(
        CommandEvent(
          'device.zeppos.xiaoai.opus',
          data: {'frame': frame.toList(growable: false)},
        ),
      ),
    );
    _rawBluetoothSubscription = _manager.rawProtocolFrames.listen((frame) {
      _recordRawBluetoothPacket(frame, direction: 'in');
    });
    _rawBluetoothOutgoingSubscription = _manager.rawProtocolOutgoingFrames
        .listen((frame) {
          _recordRawBluetoothPacket(frame, direction: 'out');
        });
    _interconnectSubscription = _manager.interconnectMessages.listen(
      (message) => _events.add(
        CommandEvent(
          deviceInterconnectEvent,
          data: encodeInterconnectEvent(message),
        ),
      ),
    );
    _deviceEventSubscription = _manager.deviceEvents.listen((event) {
      if (event case XiaomiFindPhoneRequested(:final finding)) {
        // Handle the native reaction at the backend boundary. The GUI adapter
        // can be paused or absent while Android is in the background, but the
        // local command bus remains alive with the connected device manager.
        unawaited(
          PhoneFinder.setFinding(finding).catchError((error, stackTrace) {
            _log.warning('phone finder playback failed', error, stackTrace);
          }),
        );
        _events.add(
          CommandEvent(
            'device.xiaomi.find_phone',
            data: {'deviceId': event.deviceId, 'finding': finding},
          ),
        );
      }
      if (event case XiaomiScreenshotReceived(:final bytes)) {
        _events.add(
          CommandEvent(
            'device.xiaomi.screenshot.received',
            data: {
              'deviceId': event.deviceId,
              'bytes': bytes.toList(growable: false),
            },
          ),
        );
      }
      if (event is XiaomiGnssAccountRequired) {
        _markXiaomiAccountSignedOut();
        _events.add(
          CommandEvent(
            XiaomiGnssAccountRequired.commandEvent,
            data: {'deviceId': event.deviceId},
          ),
        );
      }
      if (event case PassiveReconnectStatus(:final phase, :final attempt)) {
        _events.add(
          CommandEvent(
            PassiveReconnectStatus.commandEvent,
            data: {
              'deviceId': event.deviceId,
              'phase': phase.name,
              'attempt': attempt,
            },
          ),
        );
      }
      if (event case XiaomiProtocolTrace(:final trace)) {
        if (!_protocolTraceEnabled) return;
        _events.add(
          CommandEvent(
            'debug.protocol_trace',
            data: {
              'deviceId': event.deviceId,
              'time': DateTime.now().toUtc().toIso8601String(),
              ...trace,
            },
          ),
        );
      }
    });
    _pluginManager = PluginManager(
      deviceManager: _manager,
      readDeviceState: () => _state,
      emitEvent: _events.add,
    );
    _pluginRepositories = PluginRepositories(
      manager: _pluginManager,
      container: container,
    );
    unawaited(_pluginManager.initialize());
    unawaited(_restoreXiaomiAccountSession());
  }

  final ProviderContainer container;
  final _events = StreamController<CommandEvent>.broadcast();
  final _externalDiagnostics = <Map<String, Object?>>[];
  final _rawBluetoothPackets = <Map<String, Object?>>[];
  String? _debugSessionId;
  DateTime? _debugSessionStartedAt;
  late final ProviderSubscription<DeviceManagerState>
  _deviceManagerSubscription;
  late final ProviderSubscription<BandBbsAuthState> _bandBbsAuthSubscription;
  late final StreamSubscription<DiagnosticEvent> _logSubscription;
  late final StreamSubscription<Uint8List> _xiaoAiSubscription;
  late final StreamSubscription<Uint8List> _rawBluetoothSubscription;
  late final StreamSubscription<Uint8List> _rawBluetoothOutgoingSubscription;
  late final StreamSubscription<InterconnectMessage> _interconnectSubscription;
  late final StreamSubscription<DeviceEvent> _deviceEventSubscription;
  bool _activeCommandCancelled = false;
  bool _rawBluetoothEnabled = false;
  bool _protocolTraceEnabled = false;
  bool? _batterySyncPausedBeforeTrace;
  MiAccountToken? _xiaomiAccountToken;
  var _xiaomiAccountSessionLoaded = false;
  Future<void> _commandTail = Future<void>.value();
  late final PluginManager _pluginManager;
  late final PluginRepositories _pluginRepositories;
  final _zmlAttachments = <int>{};
  final _zmlHookResponses = <String, Completer<Object?>>{};
  var _zmlHookCounter = 0;

  DeviceManager get _manager => container.read(deviceManagerProvider.notifier);
  DeviceManagerState get _state => container.read(deviceManagerProvider);
  OronBoxCreatorApi get _creatorApi =>
      OronBoxCreatorApi(sessions: container.read(bandBbsAuthProvider.notifier));

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'debug.session.start') {
      final sessionId = command.params['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) {
        return const CommandResult.failure(
          CommandError('usage', 'Diagnostic session ID is required'),
        );
      }
      _debugSessionId = sessionId;
      _debugSessionStartedAt =
          DateTime.tryParse(command.params['startedAt']?.toString() ?? '') ??
          DateTime.now();
      _externalDiagnostics.clear();
      return CommandResult.success({
        'sessionId': sessionId,
        'startedAt': _debugSessionStartedAt!.toIso8601String(),
      });
    }
    if (command.method == 'debug.publish') {
      final record = (command.params['record'] as Map?)
          ?.cast<String, Object?>();
      if (record == null) {
        return const CommandResult.failure(
          CommandError('usage', 'Diagnostic record is required'),
        );
      }
      final sessionId = command.params['sessionId']?.toString();
      final process = record['process']?.toString();
      if (process == DiagnosticProcess.frontend.name &&
          _debugSessionId != null &&
          sessionId != _debugSessionId) {
        return const CommandResult.success({'accepted': false, 'stale': true});
      }
      _externalDiagnostics.add(record);
      if (_externalDiagnostics.length > 1000) {
        _externalDiagnostics.removeAt(0);
      }
      _events.add(CommandEvent('debug.log', data: {'record': record}));
      return const CommandResult.success({'accepted': true});
    }
    if (command.method == 'plugin.host.respond') {
      try {
        await _pluginManager.respondToHostRequest(
          command.params['requestId']?.toString() ?? '',
          (command.params['response'] as Map?)?.cast<String, Object?>() ??
              const {},
        );
        return const CommandResult.success({'accepted': true});
      } catch (error, stackTrace) {
        return CommandResult.failure(
          CommandError('internal', error.toString(), details: '$stackTrace'),
        );
      }
    }
    if (!_runsExclusive(command.method)) {
      return _runObserved(command);
    }
    final previous = _commandTail;
    final turn = Completer<void>();
    _commandTail = turn.future;
    await previous;
    _activeCommandCancelled = false;
    try {
      return await _runObserved(command);
    } finally {
      turn.complete();
    }
  }

  // Only commands that drive the Bluetooth link or the device connection need
  // to run one at a time; network/account/settings work must not queue behind
  // them (and vice versa).
  static bool _runsExclusive(String method) =>
      method == 'install.local' ||
      method == 'resource.install' ||
      method == 'plugin.open' ||
      method == 'plugin.invoke' ||
      method == 'plugin.close' ||
      method.startsWith('app.') ||
      method.startsWith('watchface.') ||
      (method.startsWith('device.') &&
          method != 'device.logs.cancel' &&
          method != 'device.recordings.cancel' &&
          method != 'device.snapshot' &&
          method != 'device.paired' &&
          method != 'device.status');

  Future<CommandResult> _runObserved(OronBoxCommand command) async {
    final observable = isObservableCommand(command.method);
    final stopwatch = Stopwatch()..start();
    final result = await _execute(command);
    stopwatch.stop();
    if (observable && !result.ok) {
      logDiagnostic(
        _log,
        Level.WARNING,
        'Command rejected',
        fields: {
          'method': command.method,
          'durationMs': stopwatch.elapsedMilliseconds,
          'code': result.error!.code,
        },
        error: result.error!.message,
      );
    }
    return result;
  }

  Future<CommandResult> _execute(OronBoxCommand command) async {
    try {
      final result = await _dispatch(command);
      return CommandResult.success(_wireValue(result));
    } on CommandFailure catch (error) {
      return CommandResult.failure(
        CommandError(error.code, error.message, details: error.details),
      );
    } on WatchfaceInstallBlockedException catch (error) {
      return CommandResult.failure(
        CommandError(error.code, error.message, details: error.details),
      );
    } on PluginExecutionException catch (error) {
      return CommandResult.failure(
        CommandError(
          'plugin_error',
          error.message,
          details: {'pluginId': error.pluginId, 'pluginName': error.pluginName},
        ),
      );
    } on CreatorApiException catch (error) {
      return CommandResult.failure(
        CommandError(error.code, error.message, details: error.details),
      );
    } catch (error, stackTrace) {
      _log.severe('Command ${command.method} failed', error, stackTrace);
      return CommandResult.failure(
        CommandError('internal', error.toString(), details: '$stackTrace'),
      );
    }
  }

  Object? _wireValue(Object? value) {
    if (value == null) return null;
    return jsonDecode(jsonEncode(value));
  }

  @override
  Future<void> cancelActiveOperation() async {
    _activeCommandCancelled = true;
    if (_state.connecting || _state.protocolState == ProtocolState.ready) {
      await _manager.disconnect();
    }
  }

  void _throwIfCancelled() {
    if (_activeCommandCancelled) {
      throw const CommandFailure('cancelled', 'Operation was cancelled');
    }
  }

  Future<Object?> _dispatch(OronBoxCommand command) => switch (command.method) {
    'status' => Future.value(_status()),
    'device.snapshot' => Future.value(_deviceStateJson(_state)),
    'device.paired' => Future.value(
      _state.pairedDevices.map(_deviceJson).toList(growable: false),
    ),
    'device.status' => Future.value(_status()),
    'device.connect' => _connect(command.params['device']?.toString()),
    'device.connect.cancel' => _cancelConnect(),
    'device.disconnect' => _disconnect(command.params['device']?.toString()),
    'device.scan' => _scan(command.params),
    'device.scan.start' => _scanStart(command.params),
    'device.scan.stop' => _scanStop(),
    'device.info' => _deviceInfo(),
    'device.refresh.all' => _refreshDeviceData(),
    'device.refresh.battery' => _refreshBattery(),
    'device.refresh.system' => _refreshSystem(),
    'device.refresh.storage' => _refreshStorage(),
    'device.sync' => _syncDevice(),
    'device.sync.time' => _syncTime(),
    'device.xiaomi.music.upload' => _uploadXiaomiMusic(command.params),
    'device.xiaomi.music.library' => _manager.loadXiaomiMusicLibrary().then(
      (value) => value.toJson(),
    ),
    'device.xiaomi.music.playlist.create' => _manager.createXiaomiMusicPlaylist(
      command.params['name']?.toString() ?? '',
    ),
    'device.xiaomi.music.playlist.rename' => _manager.renameXiaomiMusicPlaylist(
      (command.params['id'] as num).toInt(),
      command.params['name']?.toString() ?? '',
    ),
    'device.xiaomi.music.playlist.remove' => _manager.removeXiaomiMusicPlaylist(
      (command.params['id'] as num).toInt(),
    ),
    'device.xiaomi.music.song.remove' => _manager.removeXiaomiMusicSong(
      (command.params['id'] as List)
          .map((value) => (value as num).toInt())
          .toList(),
    ),
    'device.xiaomi.music.song.playlist.set' =>
      _manager.setXiaomiMusicSongInPlaylist(
        playlistId: (command.params['playlistId'] as num).toInt(),
        songId: (command.params['songId'] as List)
            .map((value) => (value as num).toInt())
            .toList(),
        included: command.params['included'] == true,
      ),
    'device.xiaomi.health.data' => _manager.loadXiaomiHealthData().then(
      (value) => value.toJson(),
    ),
    'device.xiaomi.health.sync' => _manager.syncXiaomiHealth().then(
      (value) => value.toJson(),
    ),
    'device.xiaomi.appLayout.get' => _getXiaomiAppLayout(),
    'device.xiaomi.appLayout.set' => _setXiaomiAppLayout(command.params),
    'device.xiaomi.recordings.download' => _downloadXiaomiRecordings(),
    'device.recordings.cancel' => _cancelRecordingSync(),
    'device.zeppos.find' => _setFindingZeppOsDevice(
      command.params['finding'] == true,
    ),
    'device.xiaomi.findPhone' => _setFindingXiaomiPhone(
      command.params['finding'] == true,
    ),
    'device.xiaomi.findWearable' => _setFindingXiaomiWearable(
      command.params['finding'] == true,
    ),
    'device.zeppos.screenshot' => _manager.requestZeppOsScreenshot(),
    'device.zeppos.voice_memos.download' => _downloadVoiceMemos(),
    'device.logs.pull' => _pullDeviceLogs(command.params),
    'device.logs.cancel' => _cancelDeviceLogPull(),
    'device.zeppos.appside.list' => _manager.listZeppOsAppSides(),
    'device.zeppos.appside.observed' => _manager.observedZeppOsAppSideIds(),
    'device.zeppos.appside.sessions' => _appSideSessions(),
    'device.zeppos.appside.events' => _appSideEvents(command.params),
    'device.zeppos.appside.events.clear' => _appSideEventsClear(command.params),
    'device.zeppos.appside.start' => _appSideStart(command.params),
    'device.zeppos.appside.stop' => _appSideStop(command.params),
    'device.zeppos.appside.inject' => _appSideMessage(
      command.params,
      inject: true,
    ),
    'device.zeppos.appside.send' => _appSideMessage(
      command.params,
      inject: false,
    ),
    'device.zeppos.xiaoai.reply' => _sendXiaoAiReply(
      command.params['text']?.toString(),
    ),
    'device.zeppos.xiaoai.continuous' => _setXiaoAiContinuousCapture(
      command.params['enabled'] == true,
    ),
    'device.zeppos.xiaoai.endpoint' => _setXiaoAiEndpoint(
      (command.params['endpoint'] as num?)?.toInt(),
    ),
    'device.interconnect.send' => _sendInterconnectMessage(command.params),
    'device.raw.send' => _sendRaw(command.params),
    'device.raw.request' => _requestRaw(command.params),
    'device.zeppos.zml.attach' => _zmlAttach(command.params),
    'device.zeppos.zml.invoke' => _zmlInvoke(command.params),
    'device.zeppos.zml.respond' => _zmlRespond(command.params),
    'device.remove' => _removeDevice(command.params['device']?.toString()),
    'device.import' => _importDevice(command.params),
    'app.list' => _listApps(),
    'device.xiaomi.appOrder.list' => _listXiaomiAppOrder(),
    'device.xiaomi.appOrder.set' => _setXiaomiAppOrder(command.params),
    'device.xiaomi.alarm.list' => _listXiaomiAlarms(),
    'device.xiaomi.alarm.add' => _addXiaomiAlarm(command.params),
    'device.xiaomi.alarm.update' => _updateXiaomiAlarm(command.params),
    'device.xiaomi.alarm.remove' => _removeXiaomiAlarm(command.params),
    'device.xiaomi.alarm.enable' => _setXiaomiAlarmEnabled(command.params),
    'device.xiaomi.weather.sync' => _syncXiaomiWeather(command.params),
    'app.uninstall' => _uninstallApp(command.params['package']?.toString()),
    'app.launch' => _launchApp(command.params['package']?.toString()),
    'watchface.list' => _listWatchfaces(),
    'watchface.remove' => _removeWatchface(command.params['id']?.toString()),
    'watchface.set' => _setWatchface(command.params['id']?.toString()),
    'settings.list' => Future.value(_settingsList()),
    'settings.get' => Future.value(
      _settingsGet(command.params['key']?.toString()),
    ),
    'settings.set' => _withStateEvent(
      'settings.state',
      () => _settingsSet(command.params),
      () => _settingsList(),
    ),
    'resource.sources' => _resourceSources(),
    'resource.list' || 'resource.search' => _resourceList(command.params),
    'resource.info' => _resourceInfo(command.params),
    'resource.devices' => _resourceDevices(command.params),
    'resource.probe' => _resourceProbe(command.params),
    'resource.bandbbs.categories' => _bandBbsCategories(),
    'creator.bandbbs.categories' => _bandBbsPublicationCategories(),
    'resource.huami.publisher' => _huamiPublisher(command.params),
    'resource.download' => _resourceDownload(command.params, install: false),
    'resource.install' => _resourceDownload(command.params, install: true),
    'support.feedback.list' => _creatorRequest('GET', '/api/feedback'),
    'support.feedback.get' => _creatorRequest(
      'GET',
      '/api/feedback/${_requiredCreatorId(command.params, 'ticket')}',
    ),
    'support.feedback.create' => _creatorRequest(
      'POST',
      '/api/feedback',
      data: {
        'kind': command.params['kind'],
        'subject': command.params['subject'],
        'message': command.params['message'],
        'target_source': command.params['targetSource'] ?? '',
        'target_id': command.params['targetId'] ?? '',
        'target_url': command.params['targetUrl'] ?? '',
      },
    ),
    'support.feedback.reply' => _creatorRequest(
      'POST',
      '/api/feedback/${_requiredCreatorId(command.params, 'ticket')}/replies',
      data: {'message': command.params['message']},
    ),
    'account.grants' => _creatorRequest('GET', '/api/me/grants'),
    'account.session.expire' =>
      container.read(bandBbsAuthProvider.notifier).expireSession(),
    'coins.account' => _creatorRequest('GET', '/api/coins'),
    'coins.checkin' => _creatorRequest('POST', '/api/coins/checkin'),
    'coins.resource' => _creatorRequest(
      'POST',
      '/api/resources/${_requiredCreatorId(command.params, 'resource')}/coins',
      data: {'coins': command.params['coins']},
    ),
    'coins.resource.status' => _creatorRequest(
      'GET',
      '/api/resources/${_requiredCreatorId(command.params, 'resource')}/coins',
    ),
    'comment.list' => _creatorApi.publicRequest(
      'GET',
      '/api/resources/${_requiredCreatorId(command.params, 'resource')}/comments',
      query: {
        if (command.params['before'] != null)
          'before': command.params['before'],
      },
    ),
    'comment.create' => _creatorRequest(
      'POST',
      '/api/resources/${_requiredCreatorId(command.params, 'resource')}/comments',
      data: {
        'body': command.params['body'],
        'parent_id': command.params['parentId'] ?? '',
      },
    ),
    'comment.delete' => _creatorRequest(
      'DELETE',
      '/api/comments/${_requiredCreatorId(command.params, 'comment')}',
    ),
    'message.list' => _creatorRequest('GET', '/api/messages'),
    'message.clear' => _creatorRequest('DELETE', '/api/messages'),
    'message.read' => _creatorRequest(
      'POST',
      '/api/messages/${_requiredCreatorId(command.params, 'message')}/read',
    ),
    'announcement.unread' => _creatorRequest(
      'GET',
      '/api/announcements/unread',
    ),
    'announcement.read' => _creatorRequest('POST', '/api/announcements/read'),
    'creator.list' => _creatorRequest('GET', '/api/creator/resources'),
    'creator.devices' => _creatorRequest('GET', '/api/devices'),
    'creator.grants' => _creatorRequest('GET', '/api/me/grants'),
    'creator.github.start' => _creatorRequest(
      'POST',
      '/api/oauth/github/web/start',
    ),
    'creator.github.status' => _creatorRequest(
      'POST',
      '/api/oauth/github/web/status',
      data: {'flow_id': command.params['flowId']},
    ),
    'creator.github.disconnect' => _creatorRequest(
      'DELETE',
      '/api/oauth/github/grant',
    ),
    'creator.get' => _creatorRequest(
      'GET',
      '/api/creator/resources/${_requiredCreatorId(command.params, 'resource')}',
    ),
    'creator.create' => _creatorRequest(
      'POST',
      '/api/creator/resources',
      data: {
        'slug': command.params['slug'],
        'name': command.params['name'],
        'kind': command.params['kind'],
      },
    ),
    'creator.publish' => _creatorPublish(command.params),
    'creator.draft' => _creatorDraft(command.params),
    'creator.source' => () async {
      await _creatorApi.setResourceSource(
        resourceId: _requiredCreatorId(command.params, 'resource'),
        authorName: command.params['authorName']?.toString() ?? '',
        sourceUrl: command.params['sourceUrl']?.toString() ?? '',
        licenseName: command.params['licenseName']?.toString() ?? '',
        authorizationNote:
            command.params['authorizationNote']?.toString() ?? '',
      );
      return null;
    }(),
    'creator.blob' => _creatorBlob(command.params),
    'creator.relationships' => _creatorRequest(
      'GET',
      '/api/creator/resources/${_requiredCreatorId(command.params, 'resource')}/relationships',
    ),
    'creator.takedown' => _creatorRequest(
      'POST',
      '/api/creator/resources/${_requiredCreatorId(command.params, 'resource')}/takedown',
    ),
    'creator.restore' => _creatorRequest(
      'POST',
      '/api/creator/resources/${_requiredCreatorId(command.params, 'resource')}/restore',
    ),
    'creator.delete' => _creatorRequest(
      'DELETE',
      '/api/creator/resources/${_requiredCreatorId(command.params, 'resource')}',
      query: {
        if ((command.params['deleteExternal'] as List? ?? const []).isNotEmpty)
          'delete_external': (command.params['deleteExternal'] as List).join(
            ',',
          ),
      },
    ),
    'creator.collections.list' => _creatorRequest(
      'GET',
      '/api/creator/collections',
    ),
    'creator.collections.create' => _creatorRequest(
      'POST',
      '/api/creator/collections',
      data: {
        'slug': command.params['slug'],
        'name': command.params['name'],
        'summary': command.params['summary'],
        'kind': command.params['kind'],
      },
    ),
    'creator.collections.resources' => _creatorRequest(
      'PUT',
      '/api/creator/collections/${_requiredCreatorId(command.params, 'collection')}/resources',
      data: {
        'resource_ids': command.params['resourceIds'],
        'representative_resource_id':
            command.params['representativeResourceId'],
      },
    ),
    'creator.collections.update' => _creatorRequest(
      'PATCH',
      '/api/creator/collections/${_requiredCreatorId(command.params, 'collection')}',
      data: {
        'name': command.params['name'],
        'summary': command.params['summary'],
      },
    ),
    'creator.collections.delete' => _creatorRequest(
      'DELETE',
      '/api/creator/collections/${_requiredCreatorId(command.params, 'collection')}',
    ),
    'account.list' => _accountList(),
    'account.status' => _freshAccountStatus(
      command.params['provider']?.toString(),
    ),
    'account.credentials.get' => Future.value(
      _accountCredentials(command.params['provider']?.toString()),
    ),
    'account.credentials.set' => _setAccountCredentials(command.params),
    'account.login' => _withStateEvent(
      'account.state',
      () => _accountLogin(command.params),
      () => _accountList(),
    ),
    'account.xiaomi.complete' => _withStateEvent(
      'account.state',
      () => _completeXiaomiLogin(command.params),
      () => _accountList(),
    ),
    'account.bandbbs.callback' => _withStateEvent(
      'account.state',
      () => _bandBbsCallback(command.params),
      () => _accountList(),
    ),
    'account.bandbbs.publish' => _startBandBbsPublishingAuthorization(),
    'account.logout' => _withStateEvent(
      'account.state',
      () => _accountLogout(command.params['provider']?.toString()),
      () => _accountList(),
    ),
    'logs.recent' => Future.value(recentOronBoxLogs),
    'debug.snapshot' => _debugSnapshot(),
    'debug.rawBluetooth.get' => Future.value({
      'enabled': _rawBluetoothEnabled,
      'packets': List<Map<String, Object?>>.unmodifiable(_rawBluetoothPackets),
    }),
    'debug.rawBluetooth.set' => _setRawBluetoothListener(
      command.params['enabled'] == true,
    ),
    'debug.protocolTrace.set' => _setProtocolTrace(
      command.params['enabled'] == true,
    ),
    'debug.batterySync.get' => Future.value({
      'paused': _manager.batteryRefreshPaused,
    }),
    'debug.batterySync.set' => _setBatterySyncPaused(
      command.params['paused'] == true,
    ),
    'debug.sources' => _debugSources(),
    'debug.plugin.snapshot' => _debugPluginSnapshot(command.params),
    'debug.runtime' => collectDebugRuntimeEnvironment(),
    'debug.storage.roots' => debugHostStorageRoots(),
    'debug.storage.list' => _debugStorageList(command.params),
    'debug.storage.read' => _debugStorageRead(command.params),
    'plugin.list' => _pluginManager.list(
      includeIcons: command.params['includeIcons'] != false,
    ),
    'plugin.failures' => Future.value(_pluginManager.failures()),
    'plugin.safeMode.get' => Future.value({'enabled': _pluginManager.safeMode}),
    'plugin.safeMode.set' => _pluginManager.setSafeMode(
      command.params['enabled'] == true,
    ),
    'plugin.install' => _installPlugin(command.params),
    'plugin.get' => _pluginManager.get(command.params['id']?.toString() ?? ''),
    'plugin.open' => _pluginManager.open(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.invoke' => _pluginManager.invoke(
      command.params['id']?.toString() ?? '',
      command.params['callback']?.toString() ?? '',
      command.params['value'],
    ),
    'plugin.close' => _pluginManager.closePlugin(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.remove' => _removePlugin(command.params),
    'plugin.data.clear' => _pluginManager.clearData(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.provider.list' => _pluginManager.providers(),
    'plugin.provider.call' => _pluginManager.callProvider(
      command.params['provider']?.toString() ?? '',
      command.params['operation']?.toString() ?? '',
      (command.params['arguments'] as List?)?.cast<Object?>() ?? const [],
    ),
    'plugin.repositories' => Future.value(_pluginRepositories.sources()),
    'plugin.repository.catalog' => _pluginRepositories.catalog(
      command.params['source']?.toString() ?? '',
      force: command.params['force'] == true,
    ),
    'plugin.repository.install' => _pluginRepositories.install(
      command.params['source']?.toString() ?? '',
      command.params['id']?.toString() ?? '',
    ),
    'plugin.repository.upload' => _pluginRepositories.upload(
      command.params['source']?.toString() ?? '',
      _pluginRepositoryUploadBytes(command.params),
    ),
    'plugin.repository.remove' => _pluginRepositories.remove(
      command.params['source']?.toString() ?? '',
      command.params['id']?.toString() ?? '',
    ),
    'install.local' => _installLocal(command.params),
    _ => throw CommandFailure(
      'unknown_command',
      'Unknown command: ${command.method}',
    ),
  };

  Future<List<Map<String, Object?>>> _downloadVoiceMemos() async {
    final memos = await _manager.downloadZeppOsVoiceMemos();
    return memos
        .map(
          (memo) => <String, Object?>{
            'filename': memo.filename,
            'size': memo.size,
            'durationMs': memo.durationMs,
            'timestamp': memo.timestamp.millisecondsSinceEpoch,
            'bytes': memo.bytes?.toList(growable: false) ?? const <int>[],
          },
        )
        .toList(growable: false);
  }

  String _requiredCreatorId(Map<String, Object?> params, String key) {
    final value = params[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw CommandFailure('usage', 'Missing $key');
    return Uri.encodeComponent(value);
  }

  Future<Object?> _creatorRequest(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
  }) => _creatorApi.request(method, path, data: data, query: query);

  Future<Object?> _creatorPublish(Map<String, Object?> params) async {
    final encoded = params['bundle']?.toString() ?? '';
    if (encoded.isEmpty) {
      throw const CommandFailure('usage', 'Missing publish bundle');
    }
    final bundle = base64Decode(encoded);
    final operationId = params['operationId']?.toString() ?? '';
    return _creatorApi.publish(
      resourceId: params['resource']?.toString() ?? '',
      bundle: bundle,
      onProgress: (progress) => _events.add(
        CommandEvent(
          'creator.publish.progress',
          data: {'operationId': operationId, 'progress': progress},
        ),
      ),
    );
  }

  Future<Object?> _creatorDraft(Map<String, Object?> params) async {
    final encoded = params['bundle']?.toString() ?? '';
    if (encoded.isEmpty) {
      throw const CommandFailure('usage', 'Missing draft bundle');
    }
    return _creatorApi.saveDraft(
      resourceId: params['resource']?.toString() ?? '',
      bundle: base64Decode(encoded),
    );
  }

  Future<Object?> _creatorBlob(Map<String, Object?> params) async {
    final bytes = await _creatorApi.downloadBlob(
      params['resource']?.toString() ?? '',
      params['sha256']?.toString() ?? '',
    );
    return {'bytes': base64Encode(bytes)};
  }

  Future<Object?> _withStateEvent(
    String event,
    Future<Object?> Function() operation,
    FutureOr<Object?> Function() snapshot,
  ) async {
    final result = await operation();
    _events.add(CommandEvent(event, data: {'state': await snapshot()}));
    return result;
  }

  Future<Map<String, Object?>> _debugSnapshot() async {
    await _pluginManager.initialize();
    final records =
        [
            ...recentOronBoxDiagnostics.map((event) => event.toJson()),
            ..._externalDiagnostics,
          ].where((record) {
            final startedAt = _debugSessionStartedAt;
            if (startedAt == null) return true;
            final time = DateTime.tryParse(record['time']?.toString() ?? '');
            return time != null && !time.isBefore(startedAt);
          }).toList()
          ..sort(
            (a, b) => a['time'].toString().compareTo(b['time'].toString()),
          );
    return {
      'records': records,
      'plugins': _pluginManager.diagnostics(),
      'rawBluetoothEnabled': _rawBluetoothEnabled,
      'protocolTraceEnabled': _protocolTraceEnabled,
      'batterySyncPaused': _manager.batteryRefreshPaused,
    };
  }

  Future<Map<String, Object?>> _setBatterySyncPaused(bool paused) async {
    await _manager.setBatteryRefreshPaused(paused);
    return {'paused': _manager.batteryRefreshPaused};
  }

  Future<Map<String, Object?>> _setRawBluetoothListener(bool enabled) async {
    _rawBluetoothEnabled = enabled;
    if (!enabled) _rawBluetoothPackets.clear();
    return {'enabled': enabled};
  }

  Future<Map<String, Object?>> _setProtocolTrace(bool enabled) async {
    if (enabled == _protocolTraceEnabled) {
      return {
        'enabled': enabled,
        'batterySyncPaused': _manager.batteryRefreshPaused,
      };
    }
    if (enabled) {
      _batterySyncPausedBeforeTrace = _manager.batteryRefreshPaused;
      await _manager.setBatteryRefreshPaused(true);
    } else {
      final previous = _batterySyncPausedBeforeTrace;
      _batterySyncPausedBeforeTrace = null;
      if (previous != null) {
        await _manager.setBatteryRefreshPaused(previous);
      }
    }
    _protocolTraceEnabled = enabled;
    return {
      'enabled': enabled,
      'batterySyncPaused': _manager.batteryRefreshPaused,
    };
  }

  void _recordRawBluetoothPacket(Uint8List frame, {required String direction}) {
    if (!_rawBluetoothEnabled) return;
    final record = <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'direction': direction,
      if (_state.currentDevice case final device?) ...{
        'deviceId': device.addr,
        'deviceName': device.name,
        'connectType': device.connectType,
        if (device.codename case final codename?) 'codename': codename,
      },
      'size': frame.length,
      'hex': _hexPreview(frame),
    };
    _rawBluetoothPackets.add(record);
    if (_rawBluetoothPackets.length > 2000) _rawBluetoothPackets.removeAt(0);
    _events.add(CommandEvent('debug.raw_packet', data: record));
  }

  Future<Map<String, Object?>> _debugSources() async {
    await _pluginManager.initialize();
    return {
      'processes': const ['frontend', 'backend'],
      'plugins': _pluginManager.diagnosticSources(),
    };
  }

  Future<Map<String, Object?>> _debugPluginSnapshot(
    Map<String, Object?> params,
  ) async {
    await _pluginManager.initialize();
    return _pluginManager.diagnosticSnapshot(params['id']?.toString() ?? '');
  }

  Future<List<Map<String, Object?>>> _debugStorageList(
    Map<String, Object?> params,
  ) async {
    final pluginId = params['pluginId']?.toString();
    final path = params['path']?.toString() ?? '';
    if (pluginId != null && pluginId.isNotEmpty) {
      return _pluginManager.diagnosticStorageDirectory(pluginId, path);
    }
    return listDebugHostDirectory(params['root']?.toString() ?? '', path);
  }

  Future<Map<String, Object?>> _debugStorageRead(
    Map<String, Object?> params,
  ) async {
    final pluginId = params['pluginId']?.toString();
    final path = params['path']?.toString() ?? '';
    if (pluginId != null && pluginId.isNotEmpty) {
      return _pluginManager.diagnosticStorageFile(pluginId, path);
    }
    return readDebugHostFile(params['root']?.toString() ?? '', path);
  }

  Future<Object?> _installPlugin(Map<String, Object?> params) async {
    final raw = params['bytes'];
    final bytes = switch (raw) {
      Uint8List value => value,
      List value => Uint8List.fromList(
        value.whereType<num>().map((item) => item.toInt() & 0xff).toList(),
      ),
      String value => base64Decode(value),
      _ => throw const CommandFailure('usage', 'Plugin bytes are required'),
    };
    return _pluginManager.install(
      bytes,
      includeIcon: params['includeIcon'] != false,
    );
  }

  Uint8List _pluginRepositoryUploadBytes(Map<String, Object?> params) {
    final raw = params['bytes'];
    return switch (raw) {
      Uint8List value => value,
      List value => Uint8List.fromList(
        value.whereType<num>().map((item) => item.toInt() & 0xff).toList(),
      ),
      String value => base64Decode(value),
      _ => throw const CommandFailure('usage', 'Plugin bytes are required'),
    };
  }

  Future<Object?> _removePlugin(Map<String, Object?> params) async {
    final id = params['id']?.toString() ?? '';
    final removedSources = (await _pluginManager.providers())
        .where((provider) => provider['pluginId']?.toString() == id)
        .map(
          (provider) =>
              CommunitySourceId.plugin(provider['name']?.toString() ?? '')
                  .storageKey,
        )
        .toSet();
    await _pluginManager.remove(id);
    final prefs = SharedPrefsService.instance;
    if (removedSources.contains(prefs.getString('community_source'))) {
      await prefs.setString(
        'community_source',
        CommunitySourceId.oronBox.storageKey,
      );
      container.invalidate(appSettingsProvider);
      _events.add(
        CommandEvent('settings.state', data: {'state': _settingsList()}),
      );
    }
    return {'removed': id};
  }

  Future<Object?> _sendInterconnectMessage(Map<String, Object?> params) async {
    final packageName = params['package']?.toString() ?? '';
    final payload = (params['payload'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt() & 0xff)
        .toList(growable: false);
    if (packageName.isEmpty || payload == null) {
      throw const CommandFailure('usage', 'package and payload are required');
    }
    await _manager.sendInterconnectMessage(
      packageName,
      Uint8List.fromList(payload),
    );
    return {'sent': true};
  }

  Future<Object?> _sendRaw(Map<String, Object?> params) async {
    final payload = (params['payload'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt() & 0xff)
        .toList(growable: false);
    if (payload == null) {
      throw const CommandFailure('usage', 'payload is required');
    }
    await _manager.sendRaw(Uint8List.fromList(payload));
    return {'sent': true};
  }

  Future<Object?> _requestRaw(Map<String, Object?> params) async {
    final payload = (params['payload'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt() & 0xff)
        .toList(growable: false);
    if (payload == null) {
      throw const CommandFailure('usage', 'payload is required');
    }
    final timeoutMs = (params['timeoutMs'] as num?)?.toInt() ?? 5000;
    final response = await _manager.requestRaw(
      Uint8List.fromList(payload),
      timeout: Duration(milliseconds: timeoutMs),
    );
    return response.toList(growable: false);
  }

  Future<Object?> _zmlAttach(Map<String, Object?> params) async {
    final appId = (params['appId'] as num?)?.toInt();
    if (appId == null || appId == 0) {
      throw const CommandFailure('usage', 'appId is required');
    }
    if (!_zmlAttachments.add(appId)) return {'attached': true};
    try {
      await _manager.attachZeppOsZml(
        appId,
        (hook, payload) => _forwardZmlHook(appId, hook, payload),
      );
    } catch (_) {
      _zmlAttachments.remove(appId);
      rethrow;
    }
    return {'attached': true};
  }

  Future<Object?> _forwardZmlHook(int appId, String hook, Object? payload) {
    final requestId = 'zml-${++_zmlHookCounter}';
    final completer = Completer<Object?>();
    _zmlHookResponses[requestId] = completer;
    _events.add(
      CommandEvent(
        'device.zeppos.zml.hook',
        data: {
          'appId': appId,
          'requestId': requestId,
          'hook': hook,
          'payload': payload,
        },
      ),
    );
    return completer.future
        .timeout(const Duration(seconds: 10), onTimeout: () => null)
        .whenComplete(() => _zmlHookResponses.remove(requestId));
  }

  Future<Object?> _zmlRespond(Map<String, Object?> params) async {
    final requestId = params['requestId']?.toString() ?? '';
    final completer = _zmlHookResponses.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(params['result']);
    }
    return {'ok': true};
  }

  Future<Object?> _zmlInvoke(Map<String, Object?> params) async {
    final appId = (params['appId'] as num?)?.toInt();
    if (appId == null || appId == 0) {
      throw const CommandFailure('usage', 'appId is required');
    }
    final method = params['method']?.toString() ?? '';
    if (method.isEmpty) {
      throw const CommandFailure('usage', 'method is required');
    }
    final arguments = (params['arguments'] as List?) ?? const [];
    return _manager.invokeZeppOsZml(appId, method, arguments);
  }

  Map<String, Object?> _status() {
    final current = _state.currentDevice;
    return {
      'connected': _state.protocolState == ProtocolState.ready,
      'protocolState': _state.protocolState.name,
      if (current != null) 'device': _deviceJson(current),
      if (_state.battery != null) 'battery': _state.battery!.capacity,
      if (_state.error != null) 'error': _state.error,
    };
  }

  Map<String, Object?> _deviceStateJson(DeviceManagerState state) => {
    if (state.currentDevice != null)
      'currentDevice': state.currentDevice!.toJson(),
    'pairedDevices': state.pairedDevices.map((item) => item.toJson()).toList(),
    'scannedDevices': state.scannedDevices
        .map((item) => item.toJson())
        .toList(),
    'scanning': state.scanning,
    'connecting': state.connecting,
    if (state.connectionTargetAddr != null)
      'connectionTargetAddr': state.connectionTargetAddr,
    if (state.connectionTargetName != null)
      'connectionTargetName': state.connectionTargetName,
    if (state.connectionPhase != null)
      'connectionPhase': state.connectionPhase!.name,
    'connectStatus': state.connectStatus,
    'protocolState': state.protocolState.name,
    if (state.battery != null) 'battery': state.battery!.toJson(),
    if (state.health != null) 'health': state.health!.toJson(),
    if (state.systemInfo != null) 'systemInfo': state.systemInfo!.toJson(),
    'apps': state.apps.map((item) => item.toJson()).toList(),
    'watchfaces': state.watchfaces.map((item) => item.toJson()).toList(),
    'xiaoAiActive': state.xiaoAiActive,
    'xiaoAiFrameCount': state.xiaoAiFrameCount,
    'xiaoAiCapabilities': state.xiaoAiCapabilities,
    'findingXiaomiWearable': state.findingXiaomiWearable,
    'uploadBytesPerSecond': state.uploadBytesPerSecond,
    'downloadBytesPerSecond': state.downloadBytesPerSecond,
    if (state.error != null) 'error': state.error,
  };

  Future<Object?> _connect(String? requestedAddress) async {
    final paired = _state.pairedDevices;
    if (paired.isEmpty) {
      throw const CommandFailure('no_device', 'No paired devices found');
    }
    final target = requestedAddress == null || requestedAddress.isEmpty
        ? paired.first
        : paired.where((device) => device.addr == requestedAddress).firstOrNull;
    if (target == null) {
      throw CommandFailure(
        'no_device',
        'Paired device not found: $requestedAddress',
      );
    }
    if (_state.protocolState == ProtocolState.ready &&
        _state.currentDevice?.addr == target.addr) {
      return _deviceJson(target);
    }
    final authKey = target.authkey ?? '';
    if (authKey.isEmpty) {
      throw CommandFailure(
        'connection',
        'Device has no authentication key: ${target.addr}',
      );
    }
    _events.add(CommandEvent('connecting', data: _deviceJson(target)));
    await _manager.connect(
      target.addr,
      target.name,
      authKey,
      connectType: target.connectType,
    );
    if (_state.protocolState != ProtocolState.ready) {
      final reason = _state.error;
      throw CommandFailure(
        'connection',
        reason == null || reason.isEmpty
            ? 'Device did not become ready: ${target.addr}'
            : 'Failed to connect ${target.addr}: $reason',
      );
    }
    _events.add(CommandEvent('connected', data: _deviceJson(target)));
    return _deviceJson(_state.currentDevice ?? target);
  }

  Future<Object?> _disconnect(String? address) async {
    final disconnectedActiveDevice =
        address == null || address == _state.currentDevice?.addr;
    await _manager.disconnect(address);
    if (disconnectedActiveDevice) {
      _events.add(const CommandEvent('disconnected'));
    }
    return const {'disconnected': true};
  }

  Future<Object?> _cancelConnect() async {
    await _manager.cancelConnect();
    return const {'cancelled': true};
  }

  Future<Object?> _scan(Map<String, Object?> params) async {
    final seconds = int.tryParse(params['timeout']?.toString() ?? '') ?? 10;
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    await Future<void>.delayed(Duration(seconds: seconds.clamp(1, 15)));
    await _manager.stopBluetoothScan();
    return _state.scannedDevices
        .map(
          (device) => {
            'name': device.name,
            'address': device.addr,
            'connectType': device.connectType,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _scanStart(Map<String, Object?> params) async {
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    return {'scanning': _state.scanning};
  }

  Future<Object?> _scanStop() async {
    await _manager.stopBluetoothScan();
    return _deviceStateJson(_state);
  }

  Future<Object?> _removeDevice(String? address) async {
    if (address == null || address.isEmpty) {
      throw const CommandFailure('usage', 'Missing device address');
    }
    await _manager.removeDevice(address);
    return _deviceStateJson(_state);
  }

  Future<Object?> _importDevice(Map<String, Object?> params) async {
    final raw = params['device'];
    if (raw is! Map) {
      throw const CommandFailure('usage', 'Missing device payload');
    }
    await _manager.importSharedDevice(
      MiWearState.fromJson(raw.cast<String, dynamic>()),
    );
    return _deviceStateJson(_state);
  }

  Future<Object?> _deviceInfo() async {
    await _ensureConnected(null);
    await _manager.refreshDeviceData();
    final device = _state.currentDevice;
    final info = _state.systemInfo;
    final battery = _state.battery;
    return {
      if (device != null)
        'device': {
          'name': device.name,
          'address': device.addr,
          if (device.authkey != null) 'authKey': device.authkey,
          'connectionType': device.connectType,
          if (device.codename != null) 'codename': device.codename,
        },
      if (info != null)
        'system': {
          'model': info.model,
          'imei': info.imei,
          'firmwareVersion': info.firmwareVersion,
          'serialNumber': info.serialNumber,
          if (info.storageInfo != null)
            'storage': {
              'used': info.storageInfo!.used,
              'total': info.storageInfo!.total,
              'free': info.storageInfo!.total - info.storageInfo!.used,
            },
        },
      if (battery != null)
        'status': {
          'battery': battery.capacity,
          'chargeStatus': battery.chargeStatus.name,
          if (battery.chargeInfo != null)
            'chargeInfo': {
              'state': battery.chargeInfo!.state,
              if (battery.chargeInfo!.timestamp != null)
                'timestamp': battery.chargeInfo!.timestamp,
            },
        },
    };
  }

  Future<Object?> _pullDeviceLogs([
    Map<String, Object?> params = const {},
  ]) async {
    final operationId = params['operationId'];
    final deviceId = params['deviceId'];
    _events.add(
      CommandEvent(
        'device.log.progress',
        data: {
          'stage': 'preparing',
          if (operationId != null) 'operationId': operationId,
          if (deviceId != null) 'deviceId': deviceId,
        },
      ),
    );
    DateTime? lastLogProgressAt;
    DeviceLogPullResult pulled;
    try {
      pulled = await _manager.pullDeviceLogs(
        onStage: (stage) => _events.add(
          CommandEvent(
            'device.log.progress',
            data: {
              'stage': stage,
              if (operationId != null) 'operationId': operationId,
              if (deviceId != null) 'deviceId': deviceId,
            },
          ),
        ),
        onDetailedProgress: (value) {
          final now = DateTime.now();
          if (lastLogProgressAt != null &&
              now.difference(lastLogProgressAt!) <
                  const Duration(milliseconds: 100) &&
              value.progress < 1) {
            return;
          }
          lastLogProgressAt = now;
          _events.add(
            CommandEvent(
              'device.log.progress',
              data: {
                'stage': 'transferring',
                'progress': value.progress,
                'fileName': value.fileName,
                'channel': value.channel,
                'currentPart': value.currentPart,
                'totalParts': value.totalParts,
                if (operationId != null) 'operationId': operationId,
                if (deviceId != null) 'deviceId': deviceId,
              },
            ),
          );
        },
      );
    } catch (error) {
      _events.add(
        CommandEvent(
          'device.log.progress',
          data: {
            'stage': 'failed',
            'message': error.toString(),
            if (operationId != null) 'operationId': operationId,
            if (deviceId != null) 'deviceId': deviceId,
          },
        ),
      );
      rethrow;
    }
    String directory;
    try {
      final path = await getLogDirectoryPath();
      if (path == null) {
        throw const CommandFailure(
          'storage_unavailable',
          'The runtime log directory is unavailable',
        );
      }
      directory = path;
    } catch (error) {
      _events.add(
        CommandEvent(
          'device.log.progress',
          data: {
            'stage': 'failed',
            'message': error.toString(),
            if (operationId != null) 'operationId': operationId,
            if (deviceId != null) 'deviceId': deviceId,
          },
        ),
      );
      rethrow;
    }
    final sourceName = pulled.fileName.trim();
    final safeName = sourceName
        .split(RegExp(r'[/\\]'))
        .last
        // Keep valid Unicode names readable while removing path separators,
        // control characters, and platform-reserved filename characters.
        .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
        .trim()
        .replaceFirst(RegExp(r'[. ]+$'), '');
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final rawCodename =
        params['codename']?.toString() ??
        _state.currentDevice?.codename ??
        _state.currentDevice?.name ??
        '';
    final codename = rawCodename
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceFirst(RegExp(r'[. ]+$'), '');
    final name =
        'device-${codename.isEmpty ? 'unknown' : codename}-$stamp-'
        '${safeName.isEmpty ? 'logs.zip' : safeName}';
    late final File file;
    try {
      file = await _uniqueOutputFile(
        File('$directory${Platform.pathSeparator}$name'),
      );
    } catch (error) {
      _events.add(
        CommandEvent(
          'device.log.progress',
          data: {
            'stage': 'failed',
            'message': error.toString(),
            if (operationId != null) 'operationId': operationId,
            if (deviceId != null) 'deviceId': deviceId,
          },
        ),
      );
      rethrow;
    }
    final temporary = File('${file.path}.part');
    _events.add(
      CommandEvent(
        'device.log.progress',
        data: {
          'stage': 'storing',
          'progress': 0.98,
          'fileName': name,
          if (operationId != null) 'operationId': operationId,
          if (deviceId != null) 'deviceId': deviceId,
        },
      ),
    );
    try {
      await temporary.writeAsBytes(pulled.data, flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      if (await temporary.exists()) await temporary.delete();
      _events.add(
        CommandEvent(
          'device.log.progress',
          data: {
            'stage': 'failed',
            'message': error.toString(),
            if (operationId != null) 'operationId': operationId,
            if (deviceId != null) 'deviceId': deviceId,
          },
        ),
      );
      rethrow;
    }
    final currentLog = extractCurrentDeviceLog(pulled.data);
    if (currentLog == null) {
      _log.warning(
        'device log archive did not contain offlinelog/tmp.log '
        '(archive=${pulled.data.length} bytes)',
      );
    }
    String? currentLogName;
    if (currentLog != null && currentLog.isNotEmpty) {
      try {
        currentLogName =
            await _uniqueOutputFile(
              File(
                '$directory${Platform.pathSeparator}${name.replaceFirst(RegExp(r'(?:\.tar\.gz|\.tgz|\.zip)$'), '')}-tmp.log',
              ),
            ).then((target) async {
              final temporary = File('${target.path}.part');
              try {
                await temporary.writeAsBytes(currentLog, flush: true);
                await temporary.rename(target.path);
              } catch (_) {
                if (await temporary.exists()) await temporary.delete();
                rethrow;
              }
              return target.path.split(Platform.pathSeparator).last;
            });
      } catch (error, stackTrace) {
        _log.warning(
          'failed to save extracted current device log',
          error,
          stackTrace,
        );
      }
    }
    _events.add(
      CommandEvent(
        'device.log.progress',
        data: {
          'stage': 'completed',
          'progress': 1.0,
          'fileName': name,
          'bytesDone': pulled.data.length,
          'bytesTotal': pulled.data.length,
          if (operationId != null) 'operationId': operationId,
          if (deviceId != null) 'deviceId': deviceId,
        },
      ),
    );
    return {
      'name': name,
      'path': file.path,
      'size': pulled.data.length,
      'stored': true,
      if (currentLogName != null) 'currentLogName': currentLogName,
      if (currentLog != null)
        'currentLogBytes': currentLog.toList(growable: false),
      // The GUI may be a separate desktop process from the device daemon.
      // Return the archive so the GUI can mirror it into its own OronBox logs
      // directory instead of leaving it inaccessible in the daemon sandbox.
      'bytes': pulled.data.toList(growable: false),
    };
  }

  Future<Object?> _cancelDeviceLogPull() async {
    await _manager.cancelDeviceLogPull();
    return const {'cancelled': true};
  }

  Future<Object?> _refreshBattery() async {
    await _ensureConnected(null);
    await _manager.refreshBattery();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshDeviceData() async {
    await _ensureConnected(null);
    await _manager.refreshDeviceData();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshSystem() async {
    await _ensureConnected(null);
    await _manager.fetchSystemInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshStorage() async {
    await _ensureConnected(null);
    await _manager.fetchStorageInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _syncTime() async {
    await _ensureConnected(null);
    await _manager.syncTime();
    return const {'synced': true};
  }

  Future<Object?> _syncDevice() async {
    await _ensureConnected(null);
    await _manager.syncDevice();
    return _deviceStateJson(_state);
  }

  Future<Object?> _uploadXiaomiMusic(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final bytes = Uint8List.fromList(
      (params['bytes'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
    );
    await _manager.uploadXiaomiMusic(
      bytes,
      title: params['title']?.toString() ?? 'Unknown',
      artist: params['artist']?.toString() ?? 'Unknown',
      onProgress: (progress) =>
          _events.add(CommandEvent('progress', data: {'progress': progress})),
    );
    return const {'uploaded': true};
  }

  Future<Object?> _downloadXiaomiRecordings() async {
    await _ensureConnected(null);
    final recordings = await _manager.downloadXiaomiRecordings(
      onProgress: (completed, total, fileName) => _events.add(
        CommandEvent(
          'progress',
          data: {'completed': completed, 'total': total, 'fileName': fileName},
        ),
      ),
      onDetailedProgress: (value) => _events.add(
        CommandEvent(
          'progress',
          data: {
            'currentIndex': value.currentIndex,
            'totalFiles': value.totalFiles,
            'progress': value.progress,
            'fileName': value.fileName,
            'currentPart': value.currentPart,
            'totalParts': value.totalParts,
            if (value.bytesDone != null) 'bytesDone': value.bytesDone,
            if (value.bytesTotal != null) 'bytesTotal': value.bytesTotal,
          },
        ),
      ),
    );
    return recordings.map((recording) => recording.toJson()).toList();
  }

  Future<Object?> _cancelRecordingSync() async {
    await _manager.cancelRecordingSync();
    return const {'cancelled': true};
  }

  Future<Object?> _setFindingZeppOsDevice(bool finding) async {
    await _ensureConnected(null);
    await _manager.setFindingZeppOsDevice(finding);
    return {'finding': finding};
  }

  Future<Object?> _setFindingXiaomiPhone(bool finding) async {
    await _ensureConnected(null);
    await _manager.setFindingXiaomiPhone(finding);
    if (!finding) await PhoneFinder.setFinding(false);
    return {'finding': finding};
  }

  Future<Object?> _getXiaomiAppLayout() async {
    await _ensureConnected(null);
    final layout = await _manager.loadXiaomiAppLayout();
    return {
      if (layout.hasLayout()) 'layout': layout.layout.value,
      if (layout.hasSupportLayouts()) 'supportLayouts': layout.supportLayouts,
    };
  }

  Future<Object?> _setXiaomiAppLayout(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final value = (params['layout'] as num?)?.toInt();
    final layout = value == null
        ? null
        : pb_system.AppLayout_Layout.valueOf(value);
    if (layout == null) {
      throw const CommandFailure('invalid_argument', 'layout is required');
    }
    await _manager.setXiaomiAppLayout(layout);
    return {'layout': layout.value};
  }

  Future<Object?> _setFindingXiaomiWearable(bool finding) async {
    await _ensureConnected(null);
    await _manager.setFindingXiaomiWearable(finding);
    return {'finding': finding};
  }

  int _appSideId(Map<String, Object?> params) {
    final id = (params['appId'] as num?)?.toInt();
    if (id == null) {
      throw const CommandFailure('invalid_argument', 'appId is required');
    }
    return id;
  }

  Uint8List _appSidePayload(Map<String, Object?> params) {
    final raw = params['payload'];
    if (raw is! List) {
      throw const CommandFailure('invalid_argument', 'payload is required');
    }
    return Uint8List.fromList(
      raw.map((value) => (value as num).toInt()).toList(),
    );
  }

  Future<Object?> _appSideSessions() async {
    final sessions = await _manager.zeppOsAppSideSessions();
    return sessions
        .map(
          (session) => {
            'appId': session.appId,
            'version': session.version,
            'port1': session.port1,
            'port2': session.port2,
            'extra': session.extra,
            'watchSessionOpen': session.watchSessionOpen,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _appSideEvents(Map<String, Object?> params) async {
    final events = await _manager.zeppOsAppSideEvents(_appSideId(params));
    return events
        .map(
          (event) => {
            'timestamp': event.timestamp.toIso8601String(),
            'type': event.type,
            'message': event.message,
            if (event.direction != null) 'direction': event.direction,
            if (event.source != null) 'source': event.source,
            if (event.payload != null)
              'payload': event.payload!.toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _appSideEventsClear(Map<String, Object?> params) async {
    final id = _appSideId(params);
    await _manager.clearZeppOsAppSideEvents(id);
    return {'appId': id, 'cleared': true};
  }

  Future<Object?> _appSideStart(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    await _manager.startZeppOsAppSide(id);
    return {'appId': id, 'running': true};
  }

  Future<Object?> _appSideStop(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    await _manager.stopZeppOsAppSide(id);
    return {'appId': id, 'running': false};
  }

  Future<Object?> _appSideMessage(
    Map<String, Object?> params, {
    required bool inject,
  }) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    final payload = _appSidePayload(params);
    if (inject) {
      await _manager.injectZeppOsAppSideMessage(id, payload);
    } else {
      await _manager.sendZeppOsAppSideMessage(id, payload);
    }
    return {'appId': id, 'bytes': payload.length};
  }

  Future<Object?> _sendXiaoAiReply(String? text) async {
    await _ensureConnected(null);
    if (text == null || text.trim().isEmpty) {
      throw const CommandFailure('invalid_argument', 'Reply cannot be empty');
    }
    await _manager.sendXiaoAiReply(text);
    return const {'sent': true};
  }

  Future<Object?> _setXiaoAiContinuousCapture(bool enabled) async {
    await _ensureConnected(null);
    await _manager.setXiaoAiContinuousCapture(enabled);
    return {'enabled': enabled};
  }

  Future<Object?> _setXiaoAiEndpoint(int? endpoint) async {
    await _ensureConnected(null);
    if (endpoint == null) {
      throw const CommandFailure('invalid_argument', 'Endpoint is required');
    }
    await _manager.setXiaoAiEndpoint(endpoint);
    return {'endpoint': endpoint};
  }

  Future<Object?> _listApps() async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    return _state.apps
        .map(
          (app) => {
            'packageName': app.packageName,
            'name': app.appName,
            'versionCode': app.versionCode,
            'canRemove': app.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _listXiaomiAppOrder() async {
    await _ensureConnected(null);
    final apps = await _manager.loadXiaomiAppOrder();
    return apps
        .map(
          (app) => {
            'packageName': app.packageName,
            'name': app.appName,
            'versionCode': app.versionCode,
            'canRemove': app.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _setXiaomiAppOrder(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final rows = params['apps'];
    if (rows is! List) {
      throw const CommandFailure('invalid_argument', 'apps is required');
    }
    final apps = rows
        .whereType<Map>()
        .map(
          (row) => AppInfo(
            packageName: row['packageName']?.toString() ?? '',
            appName: (row['appName'] ?? row['name'])?.toString() ?? '',
            versionCode: (row['versionCode'] as num?)?.toInt() ?? 0,
            canRemove: row['canRemove'] as bool? ?? false,
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList(growable: false);
    await _manager.setXiaomiAppOrder(apps);
    return {'count': apps.length};
  }

  Future<Object?> _listXiaomiAlarms() async {
    await _ensureConnected(null);
    final alarms = await _manager.loadXiaomiAlarms();
    return alarms.map((alarm) => alarm.toJson()).toList(growable: false);
  }

  Future<Object?> _addXiaomiAlarm(Map<String, Object?> params) async {
    await _ensureConnected(null);
    await _manager.addXiaomiAlarm(XiaomiAlarm.fromJson(params));
    return const {'saved': true};
  }

  Future<Object?> _updateXiaomiAlarm(Map<String, Object?> params) async {
    await _ensureConnected(null);
    await _manager.updateXiaomiAlarm(XiaomiAlarm.fromJson(params));
    return const {'saved': true};
  }

  Future<Object?> _removeXiaomiAlarm(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = (params['id'] as num?)?.toInt();
    if (id == null) {
      throw const CommandFailure('invalid_argument', 'id is required');
    }
    await _manager.removeXiaomiAlarm(id);
    return {'removed': id};
  }

  Future<Object?> _setXiaomiAlarmEnabled(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = (params['id'] as num?)?.toInt();
    if (id == null) {
      throw const CommandFailure('invalid_argument', 'id is required');
    }
    final enabled = params['enabled'] == true;
    await _manager.setXiaomiAlarmEnabled(id, enabled);
    return {'id': id, 'enabled': enabled};
  }

  Future<Object?> _syncXiaomiWeather(Map<String, Object?> params) async {
    await _ensureConnected(null);
    await _manager.syncXiaomiWeather(XiaomiWeatherData.fromJson(params));
    return const {'synced': true};
  }

  Future<Object?> _listWatchfaces() async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    return _state.watchfaces
        .map(
          (face) => {
            'id': face.id,
            'name': face.name,
            'current': face.isCurrent,
            'canRemove': face.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _uninstallApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.uninstallApp(app);
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _manager.fetchApps();
      if (_state.apps.every(
        (candidate) => candidate.packageName != packageName,
      )) {
        return {'removed': packageName};
      }
    }
    throw CommandFailure(
      'operation_failed',
      'App is still installed after removal request: $packageName',
    );
  }

  Future<Object?> _launchApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.openApp(app);
    return {'launched': packageName};
  }

  Future<Object?> _removeWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.uninstallWatchface(face);
    return {'removed': id};
  }

  Future<Object?> _setWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.setWatchface(face);
    return {'current': id};
  }

  Future<WatchfaceInfo> _watchface(String? id) async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    final face = _state.watchfaces
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (face == null) {
      throw CommandFailure('not_found', 'Watchface not found: $id');
    }
    return face;
  }

  static const _settingKeys = <String>{
    'auto_reconnect',
    'auto_reconnect_on_disconnect',
    'auto_install',
    'disable_auto_clean',
    'community_source',
    'github_cdn',
    'bandbbs_load_previews',
    'bandbbs_show_all_categories',
    'check_update_on_launch',
    removeBondBeforeSppSettingKey,
    realtimeActivityNotificationSettingKey,
  };

  Map<String, Object?> _settingsList() => {
    for (final key in _settingKeys) key: _readSetting(key),
  };

  Object? _settingsGet(String? key) {
    _validateSettingKey(key);
    return {'key': key, 'value': _readSetting(key!)};
  }

  Future<Object?> _settingsSet(Map<String, Object?> params) async {
    final key = params['key']?.toString();
    _validateSettingKey(key);
    final raw = params['value'];
    final prefs = SharedPrefsService.instance;
    if (raw == null) {
      await prefs.remove(key!);
    } else if (raw is bool) {
      await prefs.setBool(key!, raw);
    } else if (raw is int) {
      await prefs.setInt(key!, raw);
    } else {
      await prefs.setString(key!, raw.toString());
    }
    container.invalidate(appSettingsProvider);
    return {'key': key, 'value': _readSetting(key)};
  }

  void _validateSettingKey(String? key) {
    if (key == null || !_settingKeys.contains(key)) {
      throw CommandFailure('usage', 'Unsupported setting key: $key');
    }
  }

  Object? _readSetting(String key) {
    final prefs = SharedPrefsService.instance;
    return switch (key) {
      'auto_reconnect' ||
      'auto_reconnect_on_disconnect' ||
      'auto_install' ||
      'disable_auto_clean' ||
      'bandbbs_load_previews' ||
      'bandbbs_show_all_categories' ||
      'check_update_on_launch' => prefs.getBool(key),
      removeBondBeforeSppSettingKey => prefs.getBool(key) ?? true,
      realtimeActivityNotificationSettingKey => prefs.getBool(key) ?? true,
      'community_source' || 'github_cdn' => prefs.getString(key),
      _ => null,
    };
  }

  Future<Object?> _installLocal(Map<String, Object?> params) async {
    final operationId = params['operationId']?.toString();
    final path = params['path']?.toString() ?? '';
    final rawBytes = params['bytes'];
    final memoryPayload = params['payloadMode'] == 'memory';
    final typeName = params['type']?.toString() ?? '';
    if (path.isEmpty && !memoryPayload) {
      throw const CommandFailure('usage', 'Missing resource payload');
    }
    if (kIsWeb && !memoryPayload) {
      throw const CommandFailure(
        'unsupported',
        'Web installs require an in-memory resource payload',
      );
    }
    final file = memoryPayload ? null : File(path);
    if (file != null && !await file.exists()) {
      throw CommandFailure('file', 'File not found: $path');
    }
    final Uint8List bytes;
    if (memoryPayload) {
      bytes = switch (rawBytes) {
        Uint8List value => value,
        List value => Uint8List.fromList(
          value.map((item) => (item as num).toInt()).toList(),
        ),
        _ => throw const CommandFailure(
          'usage',
          'Missing in-memory resource bytes',
        ),
      };
    } else {
      bytes = await file!.readAsBytes();
    }
    final fileName = params['fileName']?.toString().isNotEmpty == true
        ? params['fileName'].toString()
        : file!.uri.pathSegments.last;
    final installMode = ResourceInstallMode.values.firstWhere(
      (mode) => mode.name == params['installMode']?.toString(),
      orElse: () => ResourceInstallMode.automatic,
    );
    var installed = false;
    try {
      if (typeName == 'map') {
        _throwIfCancelled();
        await _ensureConnected(params['device']?.toString());
        _throwIfCancelled();
        await _manager.uploadZeppOsMap(
          bytes,
          fileName: fileName,
          onProgress: (progress) => _events.add(
            CommandEvent(
              'progress',
              data: {
                'progress': progress,
                'path': path,
                if (operationId != null) 'operationId': operationId,
              },
            ),
          ),
        );
        installed = true;
        _events.add(CommandEvent('completed', data: {'path': path}));
        return {'installed': true, 'path': path, 'type': 'map'};
      }
      if (typeName == 'music') {
        _throwIfCancelled();
        await _ensureConnected(params['device']?.toString());
        _throwIfCancelled();
        await _manager.uploadZeppOsMusic(
          bytes,
          fileName: fileName,
          title: params['title']?.toString() ?? '',
          artist: params['artist']?.toString() ?? '',
          onProgress: (progress) => _events.add(
            CommandEvent(
              'progress',
              data: {
                'progress': progress,
                'path': path,
                if (operationId != null) 'operationId': operationId,
              },
            ),
          ),
        );
        installed = true;
        _events.add(CommandEvent('completed', data: {'path': path}));
        return {'installed': true, 'path': path, 'type': 'music'};
      }
      final service = container.read(resourceInstallServiceProvider);
      final identifier = params['identifier']?.toString();
      // The payload analyzer is the source of truth; the command's declared
      // type (e.g. quickapp) is only a fallback hint for undetectable files.
      final type =
          service.detectLocalInstallType(fileName, bytes) ??
          switch (typeName) {
            'auto' => null,
            'quickapp' || 'app' || 'miniprogram' => LocalDeviceInstallType.app,
            'watchface' => LocalDeviceInstallType.watchface,
            'firmware' => LocalDeviceInstallType.firmware,
            _ => null,
          };
      if (type == null) {
        throw CommandFailure(
          'usage',
          'Unsupported or unrecognized install type: $typeName',
        );
      }
      _throwIfCancelled();
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      void onProgress(double progress) => _events.add(
        CommandEvent(
          'progress',
          data: {
            'progress': progress,
            'path': path,
            if (operationId != null) 'operationId': operationId,
          },
        ),
      );
      switch (installMode) {
        case ResourceInstallMode.automatic:
          await service.installLocalPayload(
            type: type,
            fileName: fileName,
            bytes: bytes,
            deviceManager: _manager,
            onProgress: onProgress,
            identifierOverride: identifier,
          );
        case ResourceInstallMode.forceType:
          await service.installForcedPayload(
            type: type,
            fileName: fileName,
            bytes: bytes,
            deviceManager: _manager,
            identifierOverride: identifier,
            onProgress: onProgress,
          );
        case ResourceInstallMode.forcePlatform:
          final analysis = service.analyzePayload(
            fileName: fileName,
            bytes: bytes,
            hint: type,
            source: 'daemon-queue-force-platform',
          );
          if (analysis == null) {
            throw CommandFailure(
              'validation',
              'Unrecognized resource: $fileName',
            );
          }
          await service.installAnalyzedPayload(
            analysis: analysis,
            fileName: fileName,
            deviceManager: _manager,
            forcePlatform: true,
            identifierOverride: identifier,
            onProgress: onProgress,
          );
      }
      installed = true;
      _events.add(CommandEvent('completed', data: {'path': path}));
      return {'installed': true, 'path': path, 'type': type.name};
    } finally {
      if (installed &&
          params['deleteAfter'] == true &&
          file != null &&
          await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Object?> _resourceList(Map<String, Object?> params) async {
    await _ensureAccountsRestored();
    final source = _source(params['source']?.toString());
    final catalog = _resourceCatalog(source);
    final type = _resourceType(params['type']?.toString(), required: false);
    final devices = params['devices'];
    final selectedDevices = devices is List
        ? devices.map((item) => item.toString()).toSet()
        : {
            if (params['device']?.toString().isNotEmpty == true)
              params['device'].toString(),
          };
    final attributes = params['attributes'];
    final selectedAttributes = attributes is List
        ? attributes.map((item) => item.toString()).toSet()
        : const <String>{};
    final page = await catalog.getPage(
      CommunityResourceQuery(
        page: int.tryParse(params['page']?.toString() ?? '') ?? 0,
        pageSize: int.tryParse(params['pageSize']?.toString() ?? '') ?? 30,
        query: params['query']?.toString() ?? '',
        sort: CommunitySortRule.values.firstWhere(
          (value) => value.name == params['sort']?.toString(),
          orElse: () => CommunitySortRule.time,
        ),
        type: type,
        hidePaid: params['hidePaid'] == true,
        hideForcePaid: params['hideForcePaid'] == true,
        featured: params['featured'] == true,
        selectedDevices: selectedDevices,
        selectedAttributes: selectedAttributes,
      ),
    );
    return {
      'page': page.page,
      'hasMore': page.hasMore,
      if (page.total != null) 'total': page.total,
      'items': page.items.map(_resourceJson).toList(growable: false),
    };
  }

  Future<Object?> _resourceDevices(Map<String, Object?> params) async {
    await _ensureAccountsRestored();
    final source = _source(params['source']?.toString());
    final catalog = _resourceCatalog(source);
    final devices = await catalog.getDevices();
    return devices
        .map(
          (device) => {
            'codename': device.codename,
            'name': device.name,
            'description': device.description,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _resourceProbe(Map<String, Object?> params) async {
    await _ensureAccountsRestored();
    final source = _source(params['source']?.toString());
    final catalog = _resourceCatalog(source);
    final raw = (params['file'] as Map).cast<String, Object?>();
    return catalog.probeDownloadSize(communityResourceFileFromJson(raw));
  }

  Future<Object?> _bandBbsCategories() async {
    await _ensureAccountsRestored();
    final catalog = container.read(
      localCommunityCatalogProviderForSource(CommunitySourceId.bandbbs),
    ) as BandBbsCatalog;
    final tree = await catalog.getCategoryTree();
    Map<String, Object?> encode(BandBbsCategoryNode node) => {
      'id': node.id,
      'title': node.title,
      'resourceCount': node.resourceCount,
      'children': node.children.map(encode).toList(growable: false),
    };
    return tree.map(encode).toList(growable: false);
  }

  Future<Object?> _bandBbsPublicationCategories() async {
    await _ensureAccountsRestored();
    final catalog = container.read(
      localCommunityCatalogProviderForSource(CommunitySourceId.bandbbs),
    ) as BandBbsCatalog;
    final tree = await catalog.getPublicationCategories();
    Map<String, Object?> encode(BandBbsCategoryNode node) => {
      'id': node.id,
      'title': node.title,
      'resourceCount': node.resourceCount,
      'children': node.children.map(encode).toList(growable: false),
    };
    return tree.map(encode).toList(growable: false);
  }

  Future<Object?> _huamiPublisher(Map<String, Object?> params) async {
    await _ensureAccountsRestored();
    final catalog = container.read(
      localCommunityCatalogProviderForSource(CommunitySourceId.huamiAppStore),
    ) as HuamiAppStoreCatalog;
    final resources = await catalog.getPublisherResources(
      publisherName: params['publisher']?.toString() ?? '',
    );
    return resources.map(communityResourceToJson).toList(growable: false);
  }

  Future<Object?> _resourceInfo(Map<String, Object?> params) async {
    await _ensureAccountsRestored();
    final ref = _resourceRef(params);
    final catalog = _resourceCatalog(ref.source);
    final detail = await catalog.getDetail(ref);
    _throwIfCancelled();
    return _resourceDetailJson(detail);
  }

  Future<Object?> _resourceDownload(
    Map<String, Object?> params, {
    required bool install,
  }) async {
    await _ensureAccountsRestored();
    final rawResource = params['resource'];
    final CommunityResourceDetail detail;
    final CommunityResourceFile file;
    final CommunityResourceCatalog catalog;

    if (rawResource is Map) {
      detail = communityResourceDetailFromJson(
        rawResource.cast<String, Object?>(),
      );
      final requestedFile = params['file']?.toString();
      final files = detail.files;
      if (files.isEmpty) {
        throw const CommandFailure('not_found', 'Resource has no files');
      }
      file = requestedFile == null
          ? files.first
          : files.firstWhere(
              (f) => f.id == requestedFile,
              orElse: () => files.first,
            );
      final ref = _resourceRef(params);
      catalog = _resourceCatalog(ref.source);
    } else {
      final ref = _resourceRef(params);
      catalog = _resourceCatalog(ref.source);
      detail = await catalog.getDetail(ref);
      if (detail.files.isEmpty) {
        throw CommandFailure(
          'not_found',
          'Resource has no downloadable files: ${ref.key}',
        );
      }
      final requestedFile = params['file']?.toString();
      file = requestedFile == null
          ? detail.files.first
          : detail.files.firstWhere(
              (candidate) => candidate.id == requestedFile,
              orElse: () => detail.files.first,
            );
    }

    final service = container.read(resourceInstallServiceProvider);
    String? downloadError;
    final downloaded = await service.downloadResource(
      resource: detail,
      file: file,
      catalog: catalog,
      targetDevice: params['targetDevice']?.toString(),
      onUpdate: (status, progress, error) {
        if (error != null) downloadError = error;
        _events.add(
          CommandEvent(
            status.name,
            data: {
              'progress': progress,
              if (params['operationId'] != null)
                'operationId': params['operationId'],
              if (error != null) 'error': error,
            },
          ),
        );
      },
    );
    _throwIfCancelled();
    if (downloaded == null) {
      throw CommandFailure(
        'download',
        downloadError ?? 'Resource download failed',
      );
    }
    final payloadBytes =
        downloaded.bytes ?? await File(downloaded.path).readAsBytes();
    _throwIfCancelled();
    // The payload analyzer is the source of truth for the real install type;
    // the community listing labels (BandBBS prefixes) can be wrong.
    final detected =
        service
            .detectLocalInstallType(downloaded.fileName, payloadBytes)
            ?.name ??
        switch (detail.type) {
          CommunityResourceType.quickApp => 'app',
          CommunityResourceType.miniprogram => 'miniprogram',
          CommunityResourceType.watchface => 'watchface',
          CommunityResourceType.firmware => 'firmware',
          CommunityResourceType.canopus => 'watchface',
        };
    if (install) {
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      await service.installLocalPayload(
        type: switch (detail.type) {
          CommunityResourceType.quickApp => LocalDeviceInstallType.app,
          CommunityResourceType.miniprogram => LocalDeviceInstallType.app,
          CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
          CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
          CommunityResourceType.canopus => LocalDeviceInstallType.watchface,
        },
        fileName: downloaded.fileName,
        bytes: payloadBytes,
        deviceManager: _manager,
        onProgress: (progress) =>
            _events.add(CommandEvent('progress', data: {'progress': progress})),
      );
    }
    return {
      'path': downloaded.path,
      'fileName': downloaded.fileName,
      'type': detected,
      'installed': install,
    };
  }

  CommunitySourceId _source(String? value) {
    final normalized = value ?? 'oronbox';
    if (normalized == 'amazfit' || normalized == 'huami') {
      return CommunitySourceId.huamiAppStore;
    }
    final source = communitySourceIdByName(normalized);
    if (source == null) {
      throw CommandFailure('usage', 'Unknown resource source: $normalized');
    }
    return source;
  }

  Future<List<Map<String, Object?>>> _resourceSources() async {
    final pluginProviders = await _pluginManager.providers();
    return [
      ...CommunitySourceId.values.map(
        (source) => {'id': source.storageKey, 'name': source.displayName},
      ),
      ...pluginProviders.map((provider) {
        final id = provider['id']?.toString() ?? '';
        final source = CommunitySourceId.plugin(id);
        return {
          'id': source.storageKey,
          'name': provider['name']?.toString() ?? id,
          'pluginId': provider['pluginId'],
        };
      }),
    ];
  }

  CommunityResourceCatalog _resourceCatalog(CommunitySourceId source) {
    if (source.isPlugin) {
      return PluginCommunityCatalog(manager: _pluginManager, sourceId: source);
    }
    return container.read(localCommunityCatalogProviderForSource(source));
  }

  CommunityResourceType? _resourceType(
    String? value, {
    required bool required,
  }) {
    if (value == null || value.isEmpty) {
      if (required) {
        throw const CommandFailure('usage', 'Missing resource type');
      }
      return null;
    }
    return switch (value) {
      'quickapp' => CommunityResourceType.quickApp,
      'miniprogram' => CommunityResourceType.miniprogram,
      'watchface' => CommunityResourceType.watchface,
      'firmware' => CommunityResourceType.firmware,
      'canopus' => CommunityResourceType.canopus,
      _ => throw CommandFailure('usage', 'Unknown resource type: $value'),
    };
  }

  ResourceRef _resourceRef(Map<String, Object?> params) {
    final raw = params['ref']?.toString() ?? '';
    final separator = raw.indexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      throw CommandFailure('usage', 'Resource ref must be <source>:<id>: $raw');
    }
    return ResourceRef(
      source: _source(raw.substring(0, separator)),
      id: raw.substring(separator + 1),
    );
  }

  Map<String, Object?> _resourceJson(CommunityResource resource) =>
      communityResourceToJson(resource);

  Map<String, Object?> _resourceDetailJson(CommunityResourceDetail detail) =>
      communityResourceDetailToJson(detail);

  Future<List<Map<String, Object?>>> _accountList() async {
    await Future.wait([
      _ensureAccountsRestored(),
      _restoreXiaomiAccountSession(),
    ]);
    return [
      _accountStatus('xiaomi'),
      _accountStatus('amazfit'),
      _accountStatus('bandbbs'),
    ];
  }

  Future<Map<String, Object?>> _freshAccountStatus(String? provider) async {
    if (provider == 'bandbbs') await _ensureAccountsRestored();
    if (provider == 'xiaomi') await _restoreXiaomiAccountSession();
    return _accountStatus(provider);
  }

  Future<void> _ensureAccountsRestored() =>
      container.read(bandBbsAuthProvider.notifier).restoreCredentials();

  Future<void> _restoreXiaomiAccountSession() async {
    if (_xiaomiAccountSessionLoaded) return;
    _xiaomiAccountToken = await container
        .read(miAccountServiceProvider)
        .loadStoredToken();
    _xiaomiAccountSessionLoaded = true;
  }

  void _markXiaomiAccountSignedOut() {
    final hadSession = _xiaomiAccountToken?.isValid == true;
    _xiaomiAccountToken = null;
    _xiaomiAccountSessionLoaded = true;
    if (!hadSession) return;
    _events.add(
      CommandEvent(
        'account.state',
        data: {
          'state': _wireValue([
            _accountStatus('xiaomi'),
            _accountStatus('amazfit'),
            _accountStatus('bandbbs'),
          ]),
        },
      ),
    );
  }

  Future<List<MiCloudDevice>> _fetchXiaomiBoundDevices(
    MiAccountService service,
    MiAccountToken token,
  ) async {
    try {
      return await service.fetchBoundDevices(token: token);
    } on MiAccountSessionExpired catch (error) {
      _log.warning('Xiaomi account session expired while fetching devices');
      _markXiaomiAccountSignedOut();
      throw CommandFailure(
        'xiaomi_account_session_expired',
        'Xiaomi account session expired; sign in again',
        details: {
          if (error.statusCode case final status?) 'statusCode': status,
        },
      );
    }
  }

  Map<String, Object?> _accountStatus(String? provider) {
    return switch (provider) {
      'xiaomi' => {
        'provider': 'xiaomi',
        'signedIn': _xiaomiAccountToken?.isValid == true,
        if (_xiaomiAccountToken?.userId case final userId?
            when userId.isNotEmpty)
          'userId': userId,
        'syncedDevices': _state.pairedDevices.length,
      },
      'amazfit' || 'huami' => () {
        final account = container.read(huamiAuthProvider);
        return {
          'provider': 'amazfit',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
        };
      }(),
      'bandbbs' => () {
        final account = container.read(bandBbsAuthProvider);
        return {
          'provider': 'bandbbs',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
          if (account.userId != null) 'userId': account.userId,
          if (account.avatarUrl != null) 'avatarUrl': account.avatarUrl,
        };
      }(),
      _ => throw CommandFailure('usage', 'Unknown account provider: $provider'),
    };
  }

  Map<String, Object?> _accountCredentials(String? provider) {
    final normalized = provider == 'huami' ? 'amazfit' : provider;
    if (normalized != 'xiaomi' && normalized != 'amazfit') {
      throw CommandFailure(
        'usage',
        'Credentials are not supported for provider: $provider',
      );
    }
    final prefs = SharedPrefsService.instance;
    final prefix = normalized == 'xiaomi' ? 'mi_account' : 'huami_account';
    final remember = prefs.getBool('$prefix.remember_credentials') ?? false;
    return {
      'provider': normalized,
      'remember': remember,
      if (remember) 'username': prefs.getString('$prefix.username') ?? '',
      if (remember) 'password': prefs.getString('$prefix.password') ?? '',
      if (normalized == 'xiaomi')
        'userId': prefs.getString('mi_account.user_id') ?? '',
    };
  }

  Future<Object?> _setAccountCredentials(Map<String, Object?> params) async {
    final provider = params['provider']?.toString();
    final normalized = provider == 'huami' ? 'amazfit' : provider;
    if (normalized != 'xiaomi' && normalized != 'amazfit') {
      throw CommandFailure(
        'usage',
        'Credentials are not supported for provider: $provider',
      );
    }
    final prefs = SharedPrefsService.instance;
    final prefix = normalized == 'xiaomi' ? 'mi_account' : 'huami_account';
    final remember = params['remember'] == true;
    await prefs.setBool('$prefix.remember_credentials', remember);
    if (normalized == 'xiaomi' &&
        params['userId']?.toString().isNotEmpty == true) {
      await prefs.setString('mi_account.user_id', params['userId'].toString());
    }
    if (!remember) {
      await prefs.remove('$prefix.username');
      await prefs.remove('$prefix.password');
    } else {
      await prefs.setString(
        '$prefix.username',
        params['username']?.toString() ?? '',
      );
      await prefs.setString(
        '$prefix.password',
        params['password']?.toString() ?? '',
      );
    }
    return _accountCredentials(normalized);
  }

  Future<Object?> _accountLogin(Map<String, Object?> params) async {
    final provider = params['provider']?.toString();
    final username = params['username']?.toString() ?? '';
    final password = params['password']?.toString() ?? '';
    switch (provider) {
      case 'amazfit':
      case 'huami':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Amazfit username and password are required',
          );
        }
        await container
            .read(huamiAuthProvider.notifier)
            .login(username: username, password: password);
        return _accountStatus('amazfit');
      case 'xiaomi':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Xiaomi username and password are required',
          );
        }
        final service = container.read(miAccountServiceProvider);
        late final MiAccountToken token;
        try {
          token = await service.login(username: username, password: password);
        } on MiAccountTwoFactorRequired catch (error) {
          throw CommandFailure(
            'two_factor_required',
            'Xiaomi account requires two-factor verification',
            details: {'url': error.url, 'deviceId': error.deviceId},
          );
        }
        await service.persistToken(token);
        _xiaomiAccountToken = token;
        _xiaomiAccountSessionLoaded = true;
        final devices = await _fetchXiaomiBoundDevices(service, token);
        final imported = await _manager.importMiCloudDevices(devices);
        return {
          'provider': 'xiaomi',
          'signedIn': true,
          'importedDevices': imported,
          'userId': token.userId,
        };
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).startLogin();
        return const {'provider': 'bandbbs', 'authorizationStarted': true};
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<Object?> _completeXiaomiLogin(Map<String, Object?> params) async {
    final service = container.read(miAccountServiceProvider);
    final token = await service.completeTwoFactorLogin(
      challenge: MiAccountTwoFactorRequired(
        url: params['url']?.toString() ?? '',
        deviceId: params['deviceId']?.toString() ?? '',
      ),
      cookieHeader: params['cookieHeader']?.toString() ?? '',
    );
    await service.persistToken(token);
    _xiaomiAccountToken = token;
    _xiaomiAccountSessionLoaded = true;
    final devices = await _fetchXiaomiBoundDevices(service, token);
    final imported = await _manager.importMiCloudDevices(devices);
    return {
      'provider': 'xiaomi',
      'signedIn': true,
      'importedDevices': imported,
      'userId': token.userId,
    };
  }

  Future<Object?> _bandBbsCallback(Map<String, Object?> params) async {
    final uri = Uri.tryParse(params['uri']?.toString() ?? '');
    if (uri == null) {
      throw const CommandFailure('usage', 'Invalid BandBBS callback URI');
    }
    final handled = await container
        .read(bandBbsAuthProvider.notifier)
        .handleCallback(uri);
    if (!handled) {
      throw const CommandFailure('usage', 'Unsupported BandBBS callback URI');
    }
    return _accountStatus('bandbbs');
  }

  Future<Object?> _startBandBbsPublishingAuthorization() async {
    await container.read(bandBbsAuthProvider.notifier).authorizePublishing();
    return const {
      'provider': 'bandbbs',
      'authorizationStarted': true,
      'purpose': 'publish',
    };
  }

  Future<Object?> _accountLogout(String? provider) async {
    switch (provider) {
      case 'amazfit':
      case 'huami':
        await container.read(huamiAuthProvider.notifier).signOut();
        return {'provider': 'amazfit', 'signedIn': false};
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).signOut();
        return {'provider': 'bandbbs', 'signedIn': false};
      case 'xiaomi':
        await container.read(miAccountServiceProvider).clearStoredToken();
        _xiaomiAccountToken = null;
        _xiaomiAccountSessionLoaded = true;
        return {'provider': 'xiaomi', 'signedIn': false};
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<void> _ensureConnected(String? address) async {
    if (_state.protocolState == ProtocolState.ready &&
        (address == null || _state.currentDevice?.addr == address)) {
      return;
    }
    await _connect(address);
  }

  Map<String, Object?> _deviceJson(MiWearState device) => {
    'name': device.name,
    'address': device.addr,
    'connectType': device.connectType,
    if (device.codename != null) 'codename': device.codename,
    'disconnected': device.disconnected,
  };

  @override
  Future<void> close() async {
    if (_protocolTraceEnabled) {
      try {
        await _setProtocolTrace(false);
      } catch (error, stackTrace) {
        _log.warning(
          'Failed to restore battery synchronization after protocol trace',
          error,
          stackTrace,
        );
      }
    }
    try {
      await _manager.disconnect().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      getLogger(
        'LocalCommandBus',
      ).warning('Device disconnect during shutdown failed', error, stackTrace);
    }
    await _pluginManager.close();
    _deviceManagerSubscription.close();
    _bandBbsAuthSubscription.close();
    await _logSubscription.cancel();
    await _xiaoAiSubscription.cancel();
    await _rawBluetoothSubscription.cancel();
    await _rawBluetoothOutgoingSubscription.cancel();
    await _interconnectSubscription.cancel();
    await _deviceEventSubscription.cancel();
    await _events.close();
  }
}

Future<File> _uniqueOutputFile(File requested) async {
  if (!await requested.exists()) return requested;
  final directory = requested.parent;
  final name = requested.uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final extension = dot > 0 ? name.substring(dot) : '';
  for (var index = 2; index < 100000; index++) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}$stem ($index)$extension',
    );
    if (!await candidate.exists()) return candidate;
  }
  throw StateError('Unable to allocate a unique output file name');
}

String _hexPreview(List<int> bytes) {
  final limit = bytes.length > 256 ? 256 : bytes.length;
  final value = bytes
      .take(limit)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  return bytes.length > limit ? '$value …' : value;
}

class CommandFailure implements Exception {
  const CommandFailure(this.code, this.message, {this.details});
  final String code;
  final String message;
  final Object? details;
}
