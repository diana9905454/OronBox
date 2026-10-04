import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/models/bt_models.dart' as models;
import 'package:oronbox/src/core/models/xiaomi_health_models.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/health/parsers/xiaomi_activity_parser.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_fitness.pb.dart'
    as pb_fitness;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/device/core/device_state.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';

export 'package:oronbox/src/device/xiaomi/health/parsers/xiaomi_activity_parser.dart';

class XiaomiHealthSystem extends XiaomiPbSystem {
  XiaomiHealthSystem() : _log = getLogger('XiaomiHealthSystem');

  static const _activityFileMaxAttempts = 2;
  static const _activityFileRetryDelay = Duration(milliseconds: 150);

  final Logger _log;
  final _fitnessPackets = StreamController<pb_fitness.Fitness>.broadcast();
  XiaomiHealthState _state = const XiaomiHealthState();
  Future<XiaomiActivityFileSyncResult>? _activitySyncFuture;
  Completer<Uint8List>? _activityFileCompleter;
  BytesBuilder? _activityFileBuffer;
  Timer? _activityWatchdog;
  int _activityTotalChunks = 0;
  int _activityNextChunk = 1;
  final _pendingActivityFiles = <String, Uint8List>{};
  BytesBuilder? _pendingActivityFileBuffer;
  int _pendingActivityTotalChunks = 0;
  int _pendingActivityNextChunk = 1;

  XiaomiHealthState get state => _state;

  Stream<pb_fitness.Fitness> get fitnessPackets => _fitnessPackets.stream;

  @override
  Future<void> dispose() async {
    _activityWatchdog?.cancel();
    _activityWatchdog = null;
    final completer = _activityFileCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        StateError('Xiaomi health system disposed during activity transfer'),
      );
    }
    _activityFileCompleter = null;
    _activityFileBuffer = null;
    _pendingActivityFiles.clear();
    _pendingActivityFileBuffer = null;
    await _fitnessPackets.close();
    await super.dispose();
  }

  Stream<pb_fitness.BasicData> get basicDataReports => fitnessPackets
      .where((packet) => packet.hasBasicData())
      .map((packet) => packet.basicData);

  Stream<pb_fitness.VitalityData_List> get vitalityReports => fitnessPackets
      .where((packet) => packet.hasVitalityDataList())
      .map((packet) => packet.vitalityDataList);

  Stream<pb_fitness.BestSportData_List> get bestSportReports => fitnessPackets
      .where((packet) => packet.hasSportDataList())
      .map((packet) => packet.sportDataList);

  Stream<pb_fitness.PhoneSportData> get phoneSportReports => fitnessPackets
      .where((packet) => packet.hasPhoneSportData())
      .map((packet) => packet.phoneSportData);

  Stream<pb_fitness.PhoneSportDataV2A> get phoneSportReportsV2a =>
      fitnessPackets
          .where((packet) => packet.hasPhoneSportDataV2a())
          .map((packet) => packet.phoneSportDataV2a);

  Stream<pb_fitness.PhoneSportDataV2D> get phoneSportLocationReports =>
      fitnessPackets
          .where((packet) => packet.hasPhoneSportDataV2d())
          .map((packet) => packet.phoneSportDataV2d);

  Stream<pb_fitness.SleepResult> get sleepResults => fitnessPackets
      .where((packet) => packet.hasSleepResult())
      .map((packet) => packet.sleepResult);

  Stream<pb_fitness.WearSportData> get sportReports => fitnessPackets
      .where((packet) => packet.hasWearSportData())
      .map((packet) => packet.wearSportData);

  Stream<pb_fitness.WearSportDataV2A> get sportReportsV2 => fitnessPackets
      .where((packet) => packet.hasWearSportDataV2a())
      .map((packet) => packet.wearSportDataV2a);

  Stream<pb_fitness.WearSensorData> get sensorReports => fitnessPackets
      .where((packet) => packet.hasWearSensorData())
      .map((packet) => packet.wearSensorData);

  Stream<pb_fitness.ECGData> get ecgReports => fitnessPackets
      .where((packet) => packet.hasEcgData())
      .map((packet) => packet.ecgData);

  Stream<pb_fitness.ECGStatus> get ecgStatusReports => fitnessPackets
      .where((packet) => packet.hasEcgStatus())
      .map((packet) => packet.ecgStatus);

  /// Heart-rate samples emitted by the aggregate, sport, and ECG payloads.
  ///
  /// The Xiaomi protocol does not define one standalone heart-rate packet
  /// type.  Keeping the extraction here means callers do not need to know
  /// which firmware-specific FITNESS payload carried the sample.
  Stream<int> get heartRateReports => fitnessPackets.expand((packet) {
    final values = <int>[];
    if (packet.hasBasicData() && packet.basicData.hasHeartRate()) {
      values.add(packet.basicData.heartRate);
    }
    if (packet.hasWearSportData() && packet.wearSportData.hasHeartRate()) {
      values.add(packet.wearSportData.heartRate);
    }
    if (packet.hasWearSportDataV2a() &&
        packet.wearSportDataV2a.hasHeartRate()) {
      values.add(packet.wearSportDataV2a.heartRate);
    }
    if (packet.hasEcgData() && packet.ecgData.hasHeartRate()) {
      values.add(packet.ecgData.heartRate);
    }
    if (packet.hasSleepResult()) {
      for (final section in packet.sleepResult.sectionList) {
        if (section.hasAverageHeartRate()) {
          values.add(section.averageHeartRate);
        }
      }
    }
    return values;
  });

  /// Blood-oxygen samples currently exposed by the device protocol.
  ///
  /// Xiaomi exposes blood oxygen measurements as part of sleep sections,
  /// rather than as a separate measurement packet.
  Stream<int> get bloodOxygenReports => sleepResults.expand(
    (result) => result.sectionList
        .where((section) => section.hasAverageBloodOxygen())
        .map((section) => section.averageBloodOxygen),
  );

  Stream<pb_fitness.WomenHealth> get womenHealthReports => fitnessPackets
      .where((packet) => packet.hasWomenHealth())
      .map((packet) => packet.womenHealth);

  Stream<pb_fitness.WomenHealth_Section_List> get womenHealthSectionReports =>
      fitnessPackets
          .where((packet) => packet.hasSectionList())
          .map((packet) => packet.sectionList);

  Stream<pb_fitness.SleepRegularity> get sleepRegularityReports =>
      fitnessPackets
          .where((packet) => packet.hasSleepRegularity())
          .map((packet) => packet.sleepRegularity);

  Stream<pb_fitness.SleepDisorder> get sleepDisorderReports => fitnessPackets
      .where((packet) => packet.hasSleepDisorder())
      .map((packet) => packet.sleepDisorder);

  Stream<pb_fitness.SportStatus> get sportStatusReports => fitnessPackets
      .where((packet) => packet.hasSportStatus())
      .map((packet) => packet.sportStatus);

  Stream<pb_fitness.SportResponse> get sportResponses => fitnessPackets
      .where((packet) => packet.hasSportResponse())
      .map((packet) => packet.sportResponse);

  /// Returns the latest basic daily aggregate reported by the device.
  Future<pb_fitness.BasicData> fetchBasicData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_BASIC_DATA,
    payload: pb_fitness.Fitness(),
    responseIds: {
      pb_fitness.Fitness_FitnessID.GET_BASIC_DATA.value,
      pb_fitness.Fitness_FitnessID.REPORT_BASIC_DATA.value,
    },
    hasResponse: (fitness) => fitness.hasBasicData(),
    response: (fitness) => fitness.basicData,
  );

  /// Returns the IDs of today's or historical fitness records.
  Future<Uint8List> fetchFitnessIds({bool history = false}) => _requestBytes(
    id: history
        ? pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS
        : pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS,
    payload: history
        ? pb_fitness.Fitness()
        : pb_fitness.Fitness(syncParam: pb_fitness.SyncParam(reason: 0)),
    timeout: const Duration(seconds: 30),
    hasResponse: (_) => true,
  );

  Future<Uint8List> requestFitnessIds(Uint8List ids) => _requestBytes(
    id: pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
    payload: pb_fitness.Fitness(ids: ids),
  );

  /// Requests one activity file through Xiaomi's repeated-id wire route.
  ///
  /// The command name is plural because the same endpoint can accept a list,
  /// but a single seven-byte ID is encoded in `Fitness.ids` (protobuf field 2).
  /// The singular `Fitness.id` field is used by confirmation, not retrieval.
  Future<void> requestFitnessId(Uint8List id) => _sendFitness(
    pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
    payload: pb_fitness.Fitness(ids: id),
  );

  Future<void> confirmFitnessId(Uint8List id) => _sendFitness(
    pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID,
    payload: pb_fitness.Fitness(id: id),
  );

  /// Synchronizes the activity files used by Xiaomi's stable health protocol.
  ///
  /// The newer aggregate requests (41/44) are not implemented by all Vela
  /// firmwares.  Activity files are the compatible path used by the wearable
  /// protocol:
  /// request ids, request each seven-byte file, receive a separate fitness
  /// channel stream, then acknowledge the file.
  ///
  /// Health synchronization can be started by the device page, the health
  /// page, or the command bus.  All three entry points share the same
  /// protocol system, so concurrent calls must join the active transfer
  /// instead of interleaving request IDs and file chunks.
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() {
    final active = _activitySyncFuture;
    if (active != null) {
      _log.fine('[${entity.id}] joining active Xiaomi health file sync');
      return active;
    }

    _log.info('[${entity.id}] Xiaomi health file sync started');
    final sync = _syncActivityFiles();
    _activitySyncFuture = sync;
    sync.then<void>(
      (result) {
        _log.info(
          '[${entity.id}] Xiaomi health file sync completed: '
          'files=${result.filesReceived}, skipped=${result.filesSkipped}, '
          'failed=${result.failedFiles.length}',
        );
        if (identical(_activitySyncFuture, sync)) _activitySyncFuture = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi health file sync failed',
          error,
          stackTrace,
        );
        if (identical(_activitySyncFuture, sync)) _activitySyncFuture = null;
      },
    );
    return sync;
  }

  Future<XiaomiActivityFileSyncResult> _syncActivityFiles() async {
    final daily = <XiaomiActivityDailyRecord>[];
    final samples = <XiaomiActivitySampleRecord>[];
    final sleep = <XiaomiActivitySleepRecord>[];
    final workouts = <XiaomiActivityWorkoutRecord>[];
    final abnormalHealthRecords = <XiaomiActivityAbnormalHealthRecord>[];
    final rawFiles = <XiaomiActivityRawFile>[];
    final failedFiles = <XiaomiActivityFileFailure>[];
    var received = 0;
    var skipped = 0;

    // Start draining today's IDs before asking for history, then add the
    // historical IDs into the same priority queue as soon as they arrive.
    // This mirrors Gadgetbridge's fetcher: it keeps one file in flight while
    // the past-ID query runs, and chooses the next file from a sorted queue.
    final listedIds = <String>{};
    final queuedIds = SplayTreeSet<Uint8List>(_compareActivityIds);
    final completedIds = <String>{};
    final attemptsById = <String, int>{};
    final retrievalFailures = <String, XiaomiActivityFileFailure>{};
    final historyIdsReceived = Completer<void>();

    Future<Uint8List?> fetchIds({required bool history}) async {
      try {
        final ids = await fetchFitnessIds(history: history);
        _log.fine(
          '[${entity.id}] Xiaomi ${history ? 'history' : 'today'} '
          'activity id list received: ${ids.length} bytes',
        );
        return ids;
      } catch (error, stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi ${history ? 'history' : 'today'} activity '
          'id list unavailable; continuing with the other source',
          error,
          stackTrace,
        );
        return null;
      }
    }

    void enqueueIds(Uint8List? raw, {required bool history}) {
      if (raw == null) return;
      if (raw.length % 7 != 0) {
        _log.warning(
          '[${entity.id}] invalid Xiaomi ${history ? 'history' : 'today'} '
          'activity id list length ${raw.length}; skipping this source',
        );
        return;
      }

      for (var offset = 0; offset < raw.length; offset += 7) {
        final id = Uint8List.fromList(raw.sublist(offset, offset + 7));
        final timestamp = ByteData.sublistView(id).getUint32(0, Endian.little);
        if (timestamp == 0 && id[5] == 0) {
          skipped++;
          _log.warning('[${entity.id}] ignoring empty Xiaomi activity file id');
          continue;
        }
        final key = _activityIdKey(id);
        if (listedIds.add(key)) queuedIds.add(id);
      }
    }

    Future<void> confirmFile(Uint8List id, String key, int attempts) async {
      try {
        await confirmFitnessId(id);
      } catch (error, stackTrace) {
        failedFiles.add(
          XiaomiActivityFileFailure(
            id: key,
            attempts: attempts,
            error: 'confirmation failed: $error',
          ),
        );
        _log.warning(
          '[${entity.id}] Xiaomi activity file $key was received but '
          'could not be confirmed; continuing',
          error,
          stackTrace,
        );
      }
    }

    Future<void> drainFileQueue() async {
      while (true) {
        if (queuedIds.isEmpty) {
          if (historyIdsReceived.isCompleted) return;
          await historyIdsReceived.future;
          continue;
        }

        final id = queuedIds.first;
        final key = _activityIdKey(id);
        queuedIds.remove(id);
        if (completedIds.contains(key)) continue;

        final attempts = (attemptsById[key] ?? 0) + 1;
        attemptsById[key] = attempts;
        try {
          final file = await _requestActivityFile(id);
          final actualId = Uint8List.fromList(file.sublist(0, 7));
          final actualKey = _activityIdKey(actualId);
          if (completedIds.add(actualKey)) {
            retrievalFailures.remove(actualKey);
            rawFiles.add(
              XiaomiActivityRawFile(
                id: actualKey,
                data: Uint8List.fromList(file),
              ),
            );
            // Gadgetbridge confirms the validated file before parsing it.
            await confirmFile(actualId, actualKey, attempts);
            if (file.length == 11) {
              skipped++;
            } else {
              try {
                final parsed = _parseActivityFile(file);
                if (parsed.daily != null) daily.add(parsed.daily!);
                samples.addAll(parsed.samples);
                sleep.addAll(parsed.sleep);
                workouts.addAll(parsed.workouts);
                abnormalHealthRecords.addAll(parsed.abnormalHealthRecords);
                received++;
              } catch (error, stackTrace) {
                failedFiles.add(
                  XiaomiActivityFileFailure(
                    id: actualKey,
                    attempts: attempts,
                    error: 'parse failed: $error',
                  ),
                );
                _log.warning(
                  '[${entity.id}] could not parse Xiaomi activity file '
                  '$actualKey; raw bytes were retained',
                  error,
                  stackTrace,
                );
              }
            }
          } else {
            // ACK duplicates so the watch can advance, but parse each ID once.
            await confirmFile(actualId, actualKey, attempts);
          }
          if (actualKey == key) {
            retrievalFailures.remove(key);
          } else {
            retrievalFailures[key] = XiaomiActivityFileFailure(
              id: key,
              attempts: attempts,
              error: 'requested $key but received $actualKey',
            );
            _log.warning(
              '[${entity.id}] requested Xiaomi activity file $key but '
              'received $actualKey; processed and confirmed the payload ID',
            );
          }
        } catch (error, stackTrace) {
          retrievalFailures[key] = XiaomiActivityFileFailure(
            id: key,
            attempts: attempts,
            error: error.toString(),
          );
          _log.warning(
            '[${entity.id}] Xiaomi activity file $key failed on attempt '
            '$attempts/$_activityFileMaxAttempts',
            error,
            stackTrace,
          );
        }

        // A mismatched but valid file is already retained/confirmed above.
        // Retry only the ID that is still missing, and let it re-enter the
        // shared priority queue alongside any history IDs that arrived meanwhile.
        if (!completedIds.contains(key)) {
          if (attempts < _activityFileMaxAttempts) {
            await Future<void>.delayed(_activityFileRetryDelay);
            queuedIds.add(id);
          } else {
            _log.warning(
              '[${entity.id}] giving up Xiaomi activity file $key after '
              '$attempts attempts; continuing with the next file',
              retrievalFailures[key]?.error,
            );
          }
        }
      }
    }

    // Install the first file receiver before sending the history query; some
    // firmware starts the file stream immediately after today's first request.
    final todayRaw = await fetchIds(history: false);
    enqueueIds(todayRaw, history: false);
    final drainFuture = drainFileQueue();
    final historyFuture = fetchIds(history: true)
        .then((historyRaw) {
          enqueueIds(historyRaw, history: true);
        })
        // Even a failed history query must release the drain loop, which
        // waits on this completer; the error itself still reaches the
        // Future.wait below.
        .whenComplete(historyIdsReceived.complete);
    await Future.wait([drainFuture, historyFuture]);
    failedFiles.addAll(retrievalFailures.values);

    return XiaomiActivityFileSyncResult(
      daily: daily,
      samples: samples,
      sleep: sleep,
      workouts: _mergeWorkoutRecords(workouts),
      abnormalHealthRecords: abnormalHealthRecords,
      rawFiles: List.unmodifiable(rawFiles),
      filesReceived: received,
      failedFiles: List.unmodifiable(failedFiles),
      filesSkipped: skipped,
    );
  }

  String _activityIdKey(Uint8List id) =>
      id.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  /// Matches Gadgetbridge's XiaomiActivityFileId priority order: signed
  /// timestamp, signed timezone, type, subtype, fetch order, signed version.
  int _compareActivityIds(Uint8List left, Uint8List right) {
    int fetchOrder(int detail) => switch (detail) {
      1 => 0, // Summary first, so workout summaries precede GPS tracks.
      0 => 1,
      2 => 2,
      _ => 3,
    };

    final leftFlags = left[6];
    final rightFlags = right[6];
    final leftTimestamp = ByteData.sublistView(left).getInt32(0, Endian.little);
    final rightTimestamp = ByteData.sublistView(right)
        .getInt32(0, Endian.little);
    var comparison = leftTimestamp.compareTo(rightTimestamp);
    if (comparison != 0) return comparison;
    comparison = left[4].toSigned(8).compareTo(right[4].toSigned(8));
    if (comparison != 0) return comparison;
    comparison = ((leftFlags >> 7) & 1).compareTo((rightFlags >> 7) & 1);
    if (comparison != 0) return comparison;
    comparison = ((leftFlags & 0x7f) >> 2).compareTo((rightFlags & 0x7f) >> 2);
    if (comparison != 0) return comparison;
    comparison = fetchOrder(leftFlags & 0x03)
        .compareTo(fetchOrder(rightFlags & 0x03));
    if (comparison != 0) return comparison;
    return left[5].toSigned(8).compareTo(right[5].toSigned(8));
  }

  Future<Uint8List> _requestActivityFile(Uint8List id) async {
    if (_activityFileCompleter != null) {
      throw StateError('Xiaomi activity file request already in progress');
    }
    final key = _activityIdKey(id);
    final pending = _pendingActivityFiles.remove(key);
    if (pending != null) {
      _log.fine(
        '[${entity.id}] consuming buffered Xiaomi activity file while '
        'requesting $key',
      );
      return pending;
    }
    final completer = Completer<Uint8List>();
    _log.fine('[${entity.id}] requesting Xiaomi activity file $key');
    _activityFileCompleter = completer;
    _activityFileBuffer = BytesBuilder(copy: false);
    _activityTotalChunks = 0;
    _activityNextChunk = 1;
    _armActivityWatchdog();
    try {
      await requestFitnessId(id);
      return await completer.future;
    } finally {
      _activityWatchdog?.cancel();
      _activityWatchdog = null;
      _activityFileCompleter = null;
      _activityFileBuffer = null;
    }
  }

  void _armActivityWatchdog() {
    _activityWatchdog?.cancel();
    final waitingForFirstChunk = _activityNextChunk == 1;
    _activityWatchdog = Timer(
      waitingForFirstChunk
          ? const Duration(seconds: 45)
          : const Duration(seconds: 10),
      () {
        final completer = _activityFileCompleter;
        if (completer == null || completer.isCompleted) return;
        _log.warning(
          '[${entity.id}] Xiaomi activity file transfer timed out: '
          'chunk=${_activityNextChunk - 1}/$_activityTotalChunks',
        );
        completer.completeError(
          ProtocolException(
            waitingForFirstChunk
                ? 'Xiaomi activity file preparation timed out before the first chunk'
                : 'Xiaomi activity file transfer stalled at chunk '
                      '${_activityNextChunk - 1}/$_activityTotalChunks',
          ),
        );
      },
    );
  }

  /// Receives one raw activity-file chunk from SPP activity or L2 fileFitness.
  void onActivityPayload(Uint8List payload) {
    final completer = _activityFileCompleter;
    if (completer == null || completer.isCompleted) {
      _bufferUnsolicitedActivityPayload(payload);
      return;
    }
    if (payload.length < 4) {
      _log.warning(
        '[${entity.id}] dropping Xiaomi activity chunk shorter than header '
        '(${payload.length} bytes)',
      );
      completer.completeError(
        ProtocolException('Xiaomi activity chunk too short'),
      );
      return;
    }
    final view = ByteData.sublistView(payload);
    final total = view.getUint16(0, Endian.little);
    final number = view.getUint16(2, Endian.little);
    if (total == 0 || number == 0 || number > total) {
      _log.warning(
        '[${entity.id}] dropping invalid Xiaomi activity chunk '
        '$number/$total',
      );
      completer.completeError(
        ProtocolException('Invalid Xiaomi activity chunk $number/$total'),
      );
      return;
    }
    if (number == 1) {
      _activityFileBuffer = BytesBuilder(copy: false);
      _activityTotalChunks = total;
      _activityNextChunk = 1;
    }
    if (total != _activityTotalChunks || number != _activityNextChunk) {
      _log.warning(
        '[${entity.id}] unexpected Xiaomi activity chunk '
        '$number/$total, expected $_activityNextChunk/$_activityTotalChunks',
      );
      completer.completeError(
        ProtocolException(
          'Unexpected Xiaomi activity chunk $number/$total '
          '(expected $_activityNextChunk/$_activityTotalChunks)',
        ),
      );
      return;
    }
    _activityFileBuffer!.add(payload.sublist(4));
    _activityNextChunk++;
    _armActivityWatchdog();
    _log.fine(
      '[${entity.id}] Xiaomi activity chunk $number/$total '
      '(${payload.length - 4} bytes)',
    );
    if (number == total) {
      final data = _activityFileBuffer!.toBytes();
      _log.fine(
        '[${entity.id}] Xiaomi activity file transfer completed: '
        '$number/$total chunks, ${data.length} bytes',
      );
      try {
        completer.complete(_normalizeActivityFile(data));
      } catch (error, stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi activity file validation failed',
          error,
          stackTrace,
        );
        completer.completeError(error, stackTrace);
      }
    }
  }

  /// Xiaomi can emit the first file chunk in the interval between the file
  /// request and the next request. Mi Fitness keeps an assembler
  /// alive for that stream; dropping it here made the first health sync depend
  /// on a retry. A completed file is retained only after header and CRC
  /// validation, then bounded by the number of pending files.
  void _bufferUnsolicitedActivityPayload(Uint8List payload) {
    if (payload.length < 4) {
      _log.fine(
        '[${entity.id}] dropping unsolicited Xiaomi activity payload '
        'shorter than header (${payload.length} bytes)',
      );
      return;
    }
    final view = ByteData.sublistView(payload);
    final total = view.getUint16(0, Endian.little);
    final number = view.getUint16(2, Endian.little);
    if (total == 0 || number == 0 || number > total) {
      _pendingActivityFileBuffer = null;
      _pendingActivityTotalChunks = 0;
      _pendingActivityNextChunk = 1;
      _log.fine(
        '[${entity.id}] dropping invalid unsolicited Xiaomi activity '
        'chunk $number/$total',
      );
      return;
    }
    if (number == 1) {
      _pendingActivityFileBuffer = BytesBuilder(copy: false);
      _pendingActivityTotalChunks = total;
      _pendingActivityNextChunk = 1;
    }
    if (_pendingActivityFileBuffer == null ||
        total != _pendingActivityTotalChunks ||
        number != _pendingActivityNextChunk) {
      _pendingActivityFileBuffer = null;
      _pendingActivityTotalChunks = 0;
      _pendingActivityNextChunk = 1;
      _log.fine(
        '[${entity.id}] dropping out-of-order unsolicited Xiaomi activity '
        'chunk $number/$total',
      );
      return;
    }
    _pendingActivityFileBuffer!.add(payload.sublist(4));
    _pendingActivityNextChunk++;
    if (number != total) return;

    final data = _pendingActivityFileBuffer!.toBytes();
    _pendingActivityFileBuffer = null;
    _pendingActivityTotalChunks = 0;
    _pendingActivityNextChunk = 1;
    try {
      final normalized = _normalizeActivityFile(data);
      final key = _activityIdKey(Uint8List.sublistView(normalized, 0, 7));
      _cachePendingActivityFile(key, normalized);
      _log.fine(
        '[${entity.id}] buffered unsolicited Xiaomi activity file '
        '$key (${normalized.length} bytes)',
      );
    } catch (error, stackTrace) {
      _log.fine(
        '[${entity.id}] dropping invalid unsolicited Xiaomi activity file',
        error,
        stackTrace,
      );
    }
  }

  void _cachePendingActivityFile(String key, Uint8List normalized) {
    _pendingActivityFiles[key] = normalized;
    while (_pendingActivityFiles.length > 8) {
      _pendingActivityFiles.remove(_pendingActivityFiles.keys.first);
    }
  }

  /// Validates the raw file emitted on the Xiaomi activity-file channel.
  ///
  /// Mi Fitness removes the trailing CRC and the seven-byte
  /// FitnessDataId before handing the buffer to its generated server-data
  /// parser. OronBox parses the device file directly, so this method keeps
  /// both the raw file ID and its CRC-validated contents intact.

  Uint8List _normalizeActivityFile(Uint8List data) =>
      normalizeXiaomiActivityFile(data);


  /// Parses a sleep activity file for protocol tests and diagnostics.
  @visibleForTesting
  XiaomiActivitySleepRecord? parseActivitySleepFileForTesting(Uint8List data) {
    return _primarySleepRecord(parseActivitySleepFilesForTesting(data));
  }

  /// Parses every sleep summary in a device activity file. This is kept
  /// public for protocol tests and diagnostics; normal sync uses the same list
  /// through [XiaomiActivityFileSyncResult.sleep].
  @visibleForTesting
  List<XiaomiActivitySleepRecord> parseActivitySleepFilesForTesting(
    Uint8List data,
  ) {
    final parsed = _parseActivityFile(_normalizeActivityFile(data));
    return parsed.sleep;
  }

  /// Parses workout reports for protocol tests and debug tooling. The public
  /// sync path uses the same decoder; exposing the result makes it possible to
  /// lock the legacy/new-schema compatibility behavior to a real file sample.
  @visibleForTesting
  List<XiaomiActivityWorkoutRecord> parseActivityWorkoutFilesForTesting(
    Uint8List data,
  ) {
    final parsed = _parseActivityFile(_normalizeActivityFile(data));
    return parsed.workouts;
  }

  /// Parses Vela's historical daily-type-9 abnormal heart-rate file.
  @visibleForTesting
  List<XiaomiActivityAbnormalHealthRecord>
  parseActivityAbnormalHealthFileForTesting(Uint8List data) {
    return _parseActivityFile(_normalizeActivityFile(data))
        .abnormalHealthRecords;
  }

  List<XiaomiActivityAbnormalHeartRateRecord>
  parseActivityAbnormalHeartRateFileForTesting(Uint8List data) {
    return parseActivityAbnormalHealthFileForTesting(data)
        .where(
          (record) =>
              record.kind == XiaomiActivityAbnormalHealthKind.highHeartRate ||
              record.kind == XiaomiActivityAbnormalHealthKind.lowHeartRate,
        )
        .where((record) => record.value != null && record.threshold != null)
        .map(
          (record) => XiaomiActivityAbnormalHeartRateRecord(
            timestamp: record.timestamp,
            value: record.value!,
            kind: record.kind == XiaomiActivityAbnormalHealthKind.highHeartRate
                ? XiaomiActivityAbnormalHeartRateKind.high
                : XiaomiActivityAbnormalHeartRateKind.low,
            threshold: record.threshold!,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
          ),
        )
        .toList(growable: false);
  }

  /// Replays CRC-validated activity files without touching the wearable.
  ///
  /// The health debug page uses this to test parser changes against files
  /// captured during a real synchronization.  A parse failure is isolated to
  /// its file so one unsupported format does not hide the other records.
  XiaomiActivityFileSyncResult parseActivityFilesForDebug(
    Iterable<XiaomiActivityRawFile> files,
  ) {
    final daily = <XiaomiActivityDailyRecord>[];
    final samples = <XiaomiActivitySampleRecord>[];
    final sleep = <XiaomiActivitySleepRecord>[];
    final workouts = <XiaomiActivityWorkoutRecord>[];
    final abnormalHealthRecords = <XiaomiActivityAbnormalHealthRecord>[];
    final rawFiles = <XiaomiActivityRawFile>[];
    final failedFiles = <XiaomiActivityFileFailure>[];
    var received = 0;
    for (final raw in files) {
      try {
        // Imported archives are user supplied. Re-run the same length/CRC
        // validation as the live transfer before handing bytes to a parser;
        // captures written by the synchronizer already satisfy this check.
        final normalized = _normalizeActivityFile(raw.data);
        rawFiles.add(
          XiaomiActivityRawFile(
            id: raw.id,
            data: Uint8List.fromList(normalized),
          ),
        );
        final parsed = _parseActivityFile(normalized);
        if (parsed.daily != null) daily.add(parsed.daily!);
        samples.addAll(parsed.samples);
        sleep.addAll(parsed.sleep);
        workouts.addAll(parsed.workouts);
        abnormalHealthRecords.addAll(parsed.abnormalHealthRecords);
        received++;
      } catch (error, stackTrace) {
        failedFiles.add(
          XiaomiActivityFileFailure(
            id: raw.id,
            attempts: 0,
            error: 'parse failed: $error',
          ),
        );
        _log.warning(
          'could not replay Xiaomi activity file ${raw.id}',
          error,
          stackTrace,
        );
      }
    }
    return XiaomiActivityFileSyncResult(
      daily: daily,
      samples: samples,
      sleep: sleep,
      workouts: _mergeWorkoutRecords(workouts),
      abnormalHealthRecords: abnormalHealthRecords,
      rawFiles: List.unmodifiable(rawFiles),
      filesReceived: received,
      failedFiles: List.unmodifiable(failedFiles),
    );
  }

  List<XiaomiActivityWorkoutRecord> _mergeWorkoutRecords(
    List<XiaomiActivityWorkoutRecord> values,
  ) => XiaomiWorkoutParser.mergeWorkoutRecords(values);

  XiaomiActivitySleepRecord? _primarySleepRecord(
    List<XiaomiActivitySleepRecord> records,
  ) => XiaomiSleepParser.primarySleepRecord(records);

  XiaomiParsedActivityFile _parseActivityFile(Uint8List data) =>
      parseXiaomiActivityFile(data);


  Future<pb_fitness.RemainingSportData_List> fetchRemainingSportData() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_REMAINING_SPORT_DATA,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasRemainingSportDataList(),
        response: (fitness) => fitness.remainingSportDataList,
      );

  Future<void> registerBasicDataReports() =>
      _sendFitness(pb_fitness.Fitness_FitnessID.REGISTER_BASIC_DATA_REPORT);

  Future<void> unregisterBasicDataReports() =>
      _sendFitness(pb_fitness.Fitness_FitnessID.UNREGISTER_BASIC_DATA_REPORT);

  Future<pb_fitness.UserProfile> fetchUserProfile() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.REQUEST_USER_PROFILE,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasUserProfile(),
    response: (fitness) => fitness.userProfile,
  );

  Future<void> setUserProfile(pb_fitness.UserProfile profile) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_USER_PROFILE,
    payload: pb_fitness.Fitness(userProfile: profile),
  );

  Future<pb_fitness.SedentaryReminder> fetchSedentaryReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_SEDENTARY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasSedentaryReminder(),
        response: (fitness) => fitness.sedentaryReminder,
      );

  Future<void> setSedentaryReminder(pb_fitness.SedentaryReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SEDENTARY_REMINDER,
        payload: pb_fitness.Fitness(sedentaryReminder: reminder),
      );

  Future<pb_fitness.PressureMonitor> fetchPressureMonitor() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_PRESSURE_MONITOR,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasPressureMonitor(),
    response: (fitness) => fitness.pressureMonitor,
  );

  Future<void> setPressureMonitor(pb_fitness.PressureMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_PRESSURE_MONITOR,
        payload: pb_fitness.Fitness(pressureMonitor: monitor),
      );

  Future<pb_fitness.MeasureReminder> fetchBloodPressureReminder() =>
      _requestMeasureReminder(
        pb_fitness.Fitness_FitnessID.GET_BLOOD_PRESSURE_REMINDER,
      );

  Future<void> setBloodPressureReminder(pb_fitness.MeasureReminder reminder) =>
      _sendMeasureReminder(
        pb_fitness.Fitness_FitnessID.SET_BLOOD_PRESSURE_REMINDER,
        reminder,
      );

  Future<pb_fitness.MeasureReminder> fetchEcgReminder() =>
      _requestMeasureReminder(pb_fitness.Fitness_FitnessID.GET_ECG_REMINDER);

  Future<void> setEcgReminder(pb_fitness.MeasureReminder reminder) =>
      _sendMeasureReminder(
        pb_fitness.Fitness_FitnessID.SET_ECG_REMINDER,
        reminder,
      );

  Future<pb_fitness.VitalityReminder> fetchVitalityReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_VITALITY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasVitalityReminder(),
        response: (fitness) => fitness.vitalityReminder,
      );

  Future<void> setVitalityReminder(pb_fitness.VitalityReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_VITALITY_REMINDER,
        payload: pb_fitness.Fitness(vitalityReminder: reminder),
      );

  Future<pb_fitness.ActivityReminder> fetchActivityReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_ACTIVITY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasActivityReminder(),
        response: (fitness) => fitness.activityReminder,
      );

  Future<void> setActivityReminder(pb_fitness.ActivityReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_ACTIVITY_REMINDER,
        payload: pb_fitness.Fitness(activityReminder: reminder),
      );

  /// Returns the latest sleep summary, including sleep sections and averages.
  Future<pb_fitness.SleepResult> fetchSleepResult({Duration? timeout}) =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.SYNC_SLEEP_RESULT,
        payload: pb_fitness.Fitness(),
        timeout: timeout,
        hasResponse: (fitness) => fitness.hasSleepResult(),
        response: (fitness) => fitness.sleepResult,
      );

  Future<pb_fitness.HeartRateMonitor> fetchHeartRateMonitor() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_HEART_RATE_MONITOR,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasHeartRateMonitor(),
        response: (fitness) => fitness.heartRateMonitor,
      );

  Future<void> setHeartRateMonitor(pb_fitness.HeartRateMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_HEART_RATE_MONITOR,
        payload: pb_fitness.Fitness(heartRateMonitor: monitor),
      );

  Future<pb_fitness.BloodOxygenMonitor> fetchBloodOxygenMonitor() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_BLOOD_OXYGEN_MONITOR,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasBloodOxygenMonitor(),
        response: (fitness) => fitness.bloodOxygenMonitor,
      );

  Future<void> setBloodOxygenMonitor(pb_fitness.BloodOxygenMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_BLOOD_OXYGEN_MONITOR,
        payload: pb_fitness.Fitness(bloodOxygenMonitor: monitor),
      );

  Future<pb_fitness.ECGResponse> requestEcg(pb_fitness.ECGRequest request) =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.ECG_REQUEST,
        payload: pb_fitness.Fitness(ecgRequest: request),
        hasResponse: (fitness) => fitness.hasEcgResponse(),
        response: (fitness) => fitness.ecgResponse,
      );

  Future<pb_fitness.ECGActivation> fetchEcgActivation() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.CHECK_ECG_ACTIVATION,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasEcgActivation(),
    response: (fitness) => fitness.ecgActivation,
  );

  Future<void> setEcgActivation(bool enabled) => _sendFitness(
    enabled
        ? pb_fitness.Fitness_FitnessID.ACTIVATE_ECG
        : pb_fitness.Fitness_FitnessID.DEACTIVATE_ECG,
    payload: pb_fitness.Fitness(
      ecgActivation: pb_fitness.ECGActivation(status: enabled),
    ),
  );

  Future<void> setWomenHealthReminder(
    pb_fitness.WomenHealth_Reminder_List reminders,
  ) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_WOMEN_HEALTH_REMINDER,
    payload: pb_fitness.Fitness(reminderList: reminders),
  );

  Future<pb_fitness.Goal_Status> fetchGoalStatus() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_GOAL_STATUS,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasGoalStatus(),
    response: (fitness) => fitness.goalStatus,
  );

  Future<void> setGoalStatus(pb_fitness.Goal_Status status) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_GOAL_STATUS,
    payload: pb_fitness.Fitness(goalStatus: status),
  );

  Future<pb_fitness.VitalityData_List> fetchVitalityData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SYNC_VITALITY_DATA,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasVitalityDataList(),
    response: (fitness) => fitness.vitalityDataList,
  );

  Future<void> syncVitalityData(pb_fitness.VitalityData_List data) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SYNC_VITALITY_DATA,
        payload: pb_fitness.Fitness(vitalityDataList: data),
      );

  Future<pb_fitness.BestSportData_List> fetchBestSportData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SYNC_BEST_SPORT_DATA,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSportDataList(),
    response: (fitness) => fitness.sportDataList,
  );

  Future<void> syncBestSportData(pb_fitness.BestSportData_List data) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SYNC_BEST_SPORT_DATA,
        payload: pb_fitness.Fitness(sportDataList: data),
      );

  Future<pb_fitness.SportStatus> fetchSportStatus() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SPORT_STATUS,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSportStatus(),
    response: (fitness) => fitness.sportStatus,
  );

  Future<pb_fitness.SportPreResponse> prepareSport(
    pb_fitness.SportPreRequest request,
  ) => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SPORT_PRE_REQUEST,
    payload: pb_fitness.Fitness(sportPreRequest: request),
    hasResponse: (fitness) => fitness.hasSportPreResponse(),
    response: (fitness) => fitness.sportPreResponse,
  );

  Future<pb_fitness.SportResponse> requestSport(
    pb_fitness.SportRequest request,
  ) => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SPORT_REQUEST,
    payload: pb_fitness.Fitness(sportRequest: request),
    hasResponse: (fitness) => fitness.hasSportResponse(),
    response: (fitness) => fitness.sportResponse,
  );

  Future<pb_fitness.SleepRegularity> fetchSleepRegularity() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SLEEP_REGULARITY,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSleepRegularity(),
    response: (fitness) => fitness.sleepRegularity,
  );

  Future<void> setSleepRegularity(pb_fitness.SleepRegularity setting) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SLEEP_REGULARITY,
        payload: pb_fitness.Fitness(sleepRegularity: setting),
      );

  Future<pb_fitness.SleepDisorder> fetchSleepDisorder() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SLEEP_DISORDER,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSleepDisorder(),
    response: (fitness) => fitness.sleepDisorder,
  );

  Future<void> setSleepDisorder(pb_fitness.SleepDisorder setting) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SLEEP_DISORDER,
        payload: pb_fitness.Fitness(sleepDisorder: setting),
      );

  Future<pb_fitness.WomenHealth> fetchWomenHealth() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_WOMEN_HEALTH,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasWomenHealth(),
    response: (fitness) => fitness.womenHealth,
  );

  Future<pb_fitness.WomenHealth_Section_List> fetchWomenHealthSections() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.REQUEST_WOMEN_HEALTH,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasSectionList(),
        response: (fitness) => fitness.sectionList,
      );

  Future<void> syncWomenHealth(pb_fitness.WomenHealth health) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SYNC_WOMEN_HEALTH,
    payload: pb_fitness.Fitness(womenHealth: health),
  );

  Future<void> setWomenHealthForecast(bool enabled) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_WOMEN_HEALTH_FORCAST,
    payload: pb_fitness.Fitness(forcastOn: enabled),
  );

  /// Sends a raw FITNESS command for protocol capabilities not yet wrapped by
  /// a convenience method. The packet remains observable through
  /// [fitnessPackets] when the device reports a result.
  Future<void> sendFitnessCommand(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
  }) => _sendFitness(id, payload: payload);

  /// Requests a raw FITNESS response matched by packet id.
  Future<pb_fitness.Fitness> requestFitnessCommand(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
    Set<int>? responseIds,
    Duration? timeout,
  }) {
    final acceptedIds = responseIds ?? {id.value};
    _log.fine(
      '[${entity.id}] requesting Xiaomi FITNESS id=${id.value}, '
      'responses=${acceptedIds.join(',')}',
    );
    return component.requestPool.request<pb_fitness.Fitness>(
      packet: _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
      timeout: timeout,
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.fitness &&
          acceptedIds.contains(packet.id),
      responseMapper: (packet) => packet.fitness,
    );
  }

  Future<T> _requestFitness<T>({
    required pb_fitness.Fitness_FitnessID id,
    required pb_fitness.Fitness payload,
    required bool Function(pb_fitness.Fitness fitness) hasResponse,
    required T Function(pb_fitness.Fitness fitness) response,
    Set<int>? responseIds,
    Duration? timeout,
  }) {
    final acceptedIds = responseIds ?? {id.value};
    _log.fine(
      '[${entity.id}] requesting Xiaomi FITNESS id=${id.value}, '
      'responses=${acceptedIds.join(',')}',
    );
    return component.requestPool.request<T>(
      packet: _fitnessPacket(id, payload),
      timeout: timeout,
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.fitness &&
          acceptedIds.contains(packet.id) &&
          hasResponse(packet.fitness),
      responseMapper: (packet) => response(packet.fitness),
    );
  }

  Future<Uint8List> _requestBytes({
    required pb_fitness.Fitness_FitnessID id,
    pb_fitness.Fitness? payload,
    Set<int>? responseIds,
    Duration? timeout,
    bool Function(pb_fitness.Fitness fitness)? hasResponse,
  }) => _requestFitness<Uint8List>(
    id: id,
    payload: payload ?? pb_fitness.Fitness(),
    responseIds: responseIds,
    hasResponse: hasResponse ?? (fitness) => fitness.hasIds(),
    response: (fitness) => Uint8List.fromList(fitness.ids),
    timeout: timeout,
  );

  Future<pb_fitness.MeasureReminder> _requestMeasureReminder(
    pb_fitness.Fitness_FitnessID id,
  ) => _requestFitness(
    id: id,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasMeasureReminder(),
    response: (fitness) => fitness.measureReminder,
  );

  Future<void> _sendMeasureReminder(
    pb_fitness.Fitness_FitnessID id,
    pb_fitness.MeasureReminder reminder,
  ) => _sendFitness(id, payload: pb_fitness.Fitness(measureReminder: reminder));

  Future<void> _sendFitness(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
  }) {
    _log.fine('[${entity.id}] sending Xiaomi FITNESS id=${id.value}');
    return component.sendPbPacket(
      _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
    );
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel == L2Channel.fileFitness) {
      onActivityPayload(payload);
      return;
    }
    super.onLayer2Packet(channel, opcode, payload);
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() == pb.WearPacket_Payload.system) {
      final system = packet.system;
      if (system.hasPresentBasicStatus()) {
        _applyPresentStatus(system.presentBasicStatus);
      }
      if (system.hasReportBasicStatus()) {
        _applyReportStatus(system.reportBasicStatus);
      }
      if (system.hasWearStatus()) {
        _applyWearingStatus(system.wearStatus.value);
      }
      return;
    }

    if (packet.whichPayload() != pb.WearPacket_Payload.fitness) return;
    final knownId = pb_fitness.Fitness_FitnessID.values.any(
      (value) => value.value == packet.id,
    );
    if (!knownId) {
      _log.warning(
        '[${entity.id}] unsupported Xiaomi FITNESS packet id=${packet.id} '
        'payload=${packet.fitness.whichPayload()}',
      );
    } else {
      _log.fine(
        '[${entity.id}] received Xiaomi FITNESS packet id=${packet.id} '
        'payload=${packet.fitness.whichPayload()}',
      );
    }
    _fitnessPackets.add(packet.fitness);
  }

  void _applyPresentStatus(pb_system.BasicStatus_Present present) {
    final next = XiaomiHealthState(
      isCharging: present.isCharging,
      isWearing: present.isWearing,
      isSleeping: present.isSleeping,
      battery: present.hasBattery() ? present.battery : null,
      chargingStatus: present.isCharging ? 1 : 2,
      wearingStatus: present.isWearing ? 1 : 2,
      sleepingStatus: present.isSleeping ? 1 : 2,
      sportType: present.hasSport() ? present.sport.sportType.value : null,
      sportState: present.hasSport() && present.sport.hasSportState()
          ? present.sport.sportState.value
          : null,
    );
    _commitState(next, battery: present.hasBattery() ? present.battery : null);
  }

  void _applyReportStatus(pb_system.BasicStatus_Report report) {
    var next = _state;
    if (report.hasCharging()) {
      final value = report.charging.value;
      final charging = switch (value) {
        1 => true,
        2 || 3 => false,
        _ => null,
      };
      if (charging == null) {
        _log.warning('[${entity.id}] unknown charging status $value');
      } else {
        next = next.copyWith(isCharging: charging, chargingStatus: value);
      }
    }
    if (report.hasWearing()) {
      final value = report.wearing.value;
      if (value == 1 || value == 2) {
        next = next.copyWith(isWearing: value == 1, wearingStatus: value);
      } else {
        _log.warning('[${entity.id}] unknown wearing status $value');
      }
    }
    if (report.hasSleeping()) {
      final value = report.sleeping.value;
      if (value == 1 || value == 2) {
        next = next.copyWith(isSleeping: value == 1, sleepingStatus: value);
      } else {
        _log.warning('[${entity.id}] unknown sleeping status $value');
      }
    }
    if (report.hasWaring()) {
      next = next.copyWith(warningStatus: report.waring.value);
    }
    if (report.hasSport()) {
      next = next.copyWith(
        sportType: report.sport.sportType.value,
        sportState: report.sport.hasSportState()
            ? report.sport.sportState.value
            : null,
      );
    }
    _commitState(next);
  }

  void _applyWearingStatus(int value) {
    if (value != 1 && value != 2) {
      _log.warning('[${entity.id}] unknown wearing status $value');
      return;
    }
    _commitState(_state.copyWith(isWearing: value == 1, wearingStatus: value));
  }

  void _commitState(XiaomiHealthState next, {int? battery}) {
    if (_sameState(_state, next) && battery == null) return;
    _state = next;
    entity.emit(XiaomiHealthStateUpdated(deviceId: entity.id, health: next));
    if (battery != null) {
      entity.emit(
        BatteryUpdated(
          deviceId: entity.id,
          battery: models.BatteryStatus(
            capacity: battery,
            chargeStatus: next.isCharging == true
                ? models.ChargeStatus.charging
                : models.ChargeStatus.notCharging,
          ),
        ),
      );
    }
  }

  bool _sameState(XiaomiHealthState left, XiaomiHealthState right) =>
      left.isCharging == right.isCharging &&
      left.isWearing == right.isWearing &&
      left.isSleeping == right.isSleeping &&
      left.battery == right.battery &&
      left.chargingStatus == right.chargingStatus &&
      left.wearingStatus == right.wearingStatus &&
      left.sleepingStatus == right.sleepingStatus &&
      left.warningStatus == right.warningStatus &&
      left.sportType == right.sportType &&
      left.sportState == right.sportState;
}

pb.WearPacket _fitnessPacket(
  pb_fitness.Fitness_FitnessID id,
  pb_fitness.Fitness payload,
) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.FITNESS,
    id: id.value,
    fitness: payload,
  );
}
