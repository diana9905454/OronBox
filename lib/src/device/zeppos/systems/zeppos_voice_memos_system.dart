import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_screenshot_system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';
import 'package:oronbox/src/device/core/device_state.dart';

class ZeppOsVoiceMemo {
  const ZeppOsVoiceMemo({
    required this.filename,
    required this.size,
    required this.durationMs,
    required this.timestamp,
    this.bytes,
    this.requestNameBytes,
  });

  final String filename;
  final int size;
  final int durationMs;
  final DateTime timestamp;
  final Uint8List? bytes;
  final Uint8List? requestNameBytes;

  ZeppOsVoiceMemo withBytes(Uint8List value) => ZeppOsVoiceMemo(
    filename: filename,
    size: size,
    durationMs: durationMs,
    timestamp: timestamp,
    bytes: value,
    requestNameBytes: requestNameBytes,
  );
}

class ZeppOsVoiceMemosSystem extends System {
  static const endpoint = 0x0033;
  static const _listRequest = 0x05;
  static const _listResponse = 0x06;
  static const _downloadStartRequest = 0x07;
  static const _downloadFinishRequest = 0x0a;

  Completer<List<ZeppOsVoiceMemo>>? _pendingList;
  bool _encrypted = false;
  bool _busy = false;
  bool _cancelled = false;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  int? get _maxWriteLength {
    final transport = entity.transport;
    return transport is CharacteristicTransport
        ? transport.maxWriteLength
        : null;
  }

  Future<List<ZeppOsVoiceMemo>> downloadAll({
    void Function(int completed, int total)? onProgress,
  }) async {
    if (_busy) {
      throw StateError('Voice memo synchronization is already running');
    }
    _busy = true;
    _cancelled = false;
    try {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) {
        throw StateError(
          'Zepp OS service discovery has not been initialized; please reconnect the watch',
        );
      }
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(endpoint)) {
        throw UnsupportedError('The connected watch has no voice memo service');
      }
      _encrypted = services[endpoint] ?? false;
      final transfer = entity.system<ZeppOsScreenshotSystem>();
      if (transfer == null) {
        throw StateError(
          'Zepp OS file receive system has not been initialized; please reconnect the watch',
        );
      }
      await transfer.initialize();
      final memos = await _requestList();
      final result = <ZeppOsVoiceMemo>[];
      for (var index = 0; index < memos.length; index++) {
        _throwIfCancelled();
        final memo = memos[index];
        final fileFuture = transfer.waitForIncomingFile(
          matches: (url, filename) =>
              url.startsWith('voicememo://') && filename == memo.filename,
          timeout: const Duration(seconds: 30),
        );
        await _send(
          Uint8List.fromList([
            _downloadStartRequest,
            ...(memo.requestNameBytes ?? utf8.encode(memo.filename)),
          ]),
        );
        final file = await fileFuture;
        _throwIfCancelled();
        if (file.bytes.length != memo.size) {
          throw FormatException(
            '${memo.filename} length mismatch: '
            '${file.bytes.length}/${memo.size}',
          );
        }
        result.add(memo.withBytes(file.bytes));
        onProgress?.call(index + 1, memos.length);
      }
      await _send(Uint8List.fromList(const [_downloadFinishRequest]));
      return result;
    } finally {
      _busy = false;
      final pending = _pendingList;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError('Voice memo synchronization stopped'));
      }
      _pendingList = null;
    }
  }

  void cancelDownload() {
    if (!_busy) return;
    _cancelled = true;
    final pending = _pendingList;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const ProtocolException('Recording synchronization was cancelled'),
      );
    }
    entity.system<ZeppOsScreenshotSystem>()?.cancelIncomingFile();
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw const ProtocolException('Recording synchronization was cancelled');
    }
  }

  Future<List<ZeppOsVoiceMemo>> _requestList() async {
    final pending = _pendingList;
    if (pending != null) return pending.future;
    final completer = Completer<List<ZeppOsVoiceMemo>>();
    _pendingList = completer;
    try {
      await _send(Uint8List.fromList(const [_listRequest]));
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      if (identical(_pendingList, completer)) _pendingList = null;
    }
  }

  void handlePayload(Uint8List payload) {
    if (payload.isEmpty || payload[0] != _listResponse) return;
    final pending = _pendingList;
    if (pending == null || pending.isCompleted) return;
    try {
      if (payload.length < 3) throw const FormatException('Bad memo list');
      final data = ByteData.sublistView(payload);
      final count = data.getUint16(1, Endian.little);
      var offset = 3;
      final result = <ZeppOsVoiceMemo>[];
      for (var index = 0; index < count; index++) {
        final start = offset;
        while (offset < payload.length && payload[offset] != 0) {
          offset++;
        }
        if (offset >= payload.length) {
          throw const FormatException('Unterminated memo filename');
        }
        final rawFilename = Uint8List.fromList(payload.sublist(start, offset));
        final filename = utf8.decode(rawFilename, allowMalformed: true);
        offset++;
        if (offset + 16 > payload.length) {
          throw const FormatException('Truncated memo metadata');
        }
        final size = data.getUint32(offset, Endian.little);
        final duration = data.getUint32(offset + 4, Endian.little);
        final timestamp = data.getInt64(offset + 8, Endian.little);
        offset += 16;
        result.add(
          ZeppOsVoiceMemo(
            filename: filename,
            size: size,
            durationMs: duration,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            requestNameBytes: rawFilename,
          ),
        );
      }
      _log.info('received ${result.length} Zepp OS voice memos');
      pending.complete(result);
    } catch (error, stackTrace) {
      pending.completeError(error, stackTrace);
    }
  }

  Future<void> _send(Uint8List payload) => _component.sendToEndpoint(
    endpoint,
    payload,
    encrypted: _encrypted,
    maxWriteLength: _maxWriteLength,
  );

  @override
  void onData(Uint8List data) {}
}

final Logger _log = getLogger('ZeppOsVoiceMemosSystem');
