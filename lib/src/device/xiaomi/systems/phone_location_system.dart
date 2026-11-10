import 'dart:async';

import 'package:flutter/services.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/phone_location_sessions.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_common.pbenum.dart'
    as common;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_fitness.pb.dart'
    as fitness;
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';

/// Mi Fitness zqr (prepare/request) and brr/pdb (V2D location sender).
class XiaomiPhoneLocationSystem extends XiaomiPbSystem {
  XiaomiPhoneLocationSystem({
    PhoneLocationSessions? sessions,
    Future<void> Function(pb.WearPacket)? send,
    this.prepareTimeout = const Duration(seconds: 15),
  }) : _sessions = sessions ?? PhoneLocationSessions.instance,
       _sendOverride = send;
  final PhoneLocationSessions _sessions;
  final Future<void> Function(pb.WearPacket)? _sendOverride;
  final Duration prepareTimeout;
  final _log = getLogger('XiaomiPhoneLocationSystem');
  StreamSubscription<Position>? _subscription;
  Timer? _prepareTimer;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool _preparing = false;
  bool _active = false;
  bool _paused = false;
  bool _leased = false;
  int _lastTimestamp = -1;
  int _generation = 0;
  Position? _latest;
  common.SportType? _sport;

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (_disposed ||
        packet.type != pb.WearPacket_Type.FITNESS ||
        !packet.hasFitness()) {
      return;
    }
    final payload = packet.fitness;
    if (packet.id == fitness.Fitness_FitnessID.SPORT_PRE_REQUEST.value &&
        payload.hasSportPreRequest()) {
      final request = payload.sportPreRequest.deepCopy();
      _enqueue(() => _prepare(request));
    } else if (packet.id == fitness.Fitness_FitnessID.SPORT_REQUEST.value &&
        payload.hasSportRequest()) {
      final request = payload.sportRequest.deepCopy();
      _enqueue(() => _request(request));
    }
  }

  void _enqueue(Future<void> Function() action) {
    _queue = _queue
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object error) {
          _log.warning(
            'Phone workout location failed: ${error is PlatformException ? error.code : error.runtimeType}',
          );
        });
  }

  static bool _usesGps(common.SportType type) => const {
    1,
    2,
    4,
    5,
    6,
    10,
    15,
    17,
    21,
    22,
    23,
    24,
    25,
  }.contains(type.value);

  Future<void> _prepare(fitness.SportPreRequest request) async {
    if (!_usesGps(request.sportType)) return;
    if (_active && _sport != request.sportType) {
      await _replyPrepare(fitness.SportResponse_Code.BUSY);
      return;
    }
    if (!_sessions.enabled) {
      await _replyPrepare(fitness.SportResponse_Code.NO_PERMISSION);
      return;
    }
    _sport = request.sportType;
    if (!_active) _preparing = true;
    try {
      await _acquire();
      if (_disposed) return;
      if (_latest case final position? when valid(position)) {
        await _replyPrepare(fitness.SportResponse_Code.OK, quality(position));
      }
      if (!_active) {
        _prepareTimer?.cancel();
        final generation = _generation;
        _prepareTimer = Timer(
          prepareTimeout,
          () => _enqueue(() async {
            if (!_active && generation == _generation) {
              await _replyPrepare(fitness.SportResponse_Code.LACK_OF_ACCURACY);
              await _stop();
            }
          }),
        );
      }
    } catch (error) {
      await _replyPrepare(_failureCode(error));
      await _stop();
    }
  }

  Future<void> _request(fitness.SportRequest request) async {
    if (!_usesGps(request.sportType)) return;
    if (_sport != null && _sport != request.sportType) {
      await _replyRequest(request, fitness.SportResponse_Code.TYPE_NOT_MATCH);
      return;
    }
    if (request.state == common.SportState.SPORT_STOP) {
      await _replyRequest(request, fitness.SportResponse_Code.OK);
      await _stop();
      return;
    }
    if (!_sessions.enabled) {
      await _replyRequest(request, fitness.SportResponse_Code.NO_PERMISSION);
      return;
    }
    _sport = request.sportType;
    try {
      await _acquire();
      if (_disposed) return;
      _prepareTimer?.cancel();
      _prepareTimer = null;
      _preparing = false;
      _active = true;
      _paused = request.state == common.SportState.SPORT_PAUSE;
      await _replyRequest(request, fitness.SportResponse_Code.OK);
    } catch (error) {
      await _replyRequest(request, _failureCode(error));
      await _stop();
    }
  }

  Future<void> _acquire() async {
    if (_leased) return;
    final generation = _generation;
    _subscription = _sessions.positions.listen(
      (position) {
        _enqueue(() async {
          if (generation == _generation && valid(position)) {
            await _position(position);
          }
        });
      },
      onError: (Object error) => _enqueue(() async {
        _log.warning(
          'Phone workout location interrupted: ${error is PlatformException ? error.code : error.runtimeType}',
        );
        if (_preparing) {
          await _replyPrepare(_failureCode(error));
        }
        await _stop();
      }),
    );
    try {
      await _sessions.acquire(this);
      _leased = true;
      if (_disposed) await _stop();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  static fitness.SportResponse_Code _failureCode(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'SERVICE_DISABLED' ||
        'TIMEOUT' ||
        'LOCATION_START_TIMEOUT' ||
        'SERVICE_STOPPED' ||
        'LOCATION_START_FAILED' => fitness.SportResponse_Code.LACK_OF_ACCURACY,
        'PERMISSION_DENIED' ||
        'PRECISE_PERMISSION_REQUIRED' ||
        'FOREGROUND_PERMISSION_REQUIRED' ||
        'BACKGROUND_START_RESTRICTED' ||
        'PHONE_LOCATION_DISABLED' ||
        'NO_ACTIVITY' => fitness.SportResponse_Code.NO_PERMISSION,
        _ => fitness.SportResponse_Code.UNKNOWN,
      };
    }
    return fitness.SportResponse_Code.UNKNOWN;
  }

  static bool valid(Position p) {
    final age =
        p.ageMilliseconds ??
        DateTime.now().difference(p.timestamp).inMilliseconds;
    return age >= 0 &&
        age <= 10000 &&
        p.latitude.isFinite &&
        p.latitude.abs() <= 90 &&
        p.longitude.isFinite &&
        p.longitude.abs() <= 180 &&
        p.hasAccuracy &&
        p.accuracy.isFinite &&
        p.accuracy >= 0;
  }

  static fitness.GpsAccuracy quality(Position position) {
    if (position.satellitesUsed != null) {
      final used = position.satellitesUsed!;
      if (used > 3) return fitness.GpsAccuracy.GPS_HIGH;
      if (used > 0) return fitness.GpsAccuracy.GPS_MEDIUM;
    }
    if (position.hasAccuracy && position.accuracy.isFinite) {
      final acc = position.accuracy;
      if (acc <= 20) return fitness.GpsAccuracy.GPS_HIGH;
      if (acc <= 50) return fitness.GpsAccuracy.GPS_MEDIUM;
      if (acc <= 100) return fitness.GpsAccuracy.GPS_LOW;
    }
    return fitness.GpsAccuracy.GPS_UNKNOWN;
  }

  Future<void> _position(Position position) async {
    _latest = position;
    if (_preparing) {
      await _replyPrepare(fitness.SportResponse_Code.OK, quality(position));
    }
    if (!_active || _paused) return;
    final timestamp = position.timestamp.millisecondsSinceEpoch ~/ 1000;
    if (timestamp <= _lastTimestamp) return;
    final data = fitness.PhoneSportDataV2D(
      gpsAccuracy: quality(position),
      timestamp: timestamp,
      longitude: position.longitude,
      latitude: position.latitude,
    );
    if (position.hasAltitude &&
        position.altitude.isFinite &&
        position.provider != 'network') {
      data.altitude = position.altitude;
    }
    if (position.speed case final speed? when speed.isFinite && speed >= 0) {
      data.speed = speed;
    }
    if (position.bearing case final bearing?
        when bearing.isFinite && bearing >= 0 && bearing < 360) {
      data.bearing = bearing;
    }
    data.horizontalAccuracy = position.accuracy;
    if (position.verticalAccuracy case final accuracy?
        when accuracy.isFinite && accuracy >= 0) {
      data.verticalAccuracy = accuracy;
    }
    await _send(
      fitness.Fitness_FitnessID.PHONE_SPORT_DATA_V2D,
      fitness.Fitness(phoneSportDataV2d: data),
    );
    _lastTimestamp = timestamp;
  }

  Future<void> _replyPrepare(
    fitness.SportResponse_Code code, [
    fitness.GpsAccuracy accuracy = fitness.GpsAccuracy.GPS_UNKNOWN,
  ]) => _send(
    fitness.Fitness_FitnessID.SPORT_PRE_REQUEST,
    fitness.Fitness(
      sportPreResponse: fitness.SportPreResponse(
        code: code,
        selectVersion: 2,
        gpsAccuracy: accuracy,
      ),
    ),
  );
  Future<void> _replyRequest(
    fitness.SportRequest request,
    fitness.SportResponse_Code code,
  ) => _send(
    fitness.Fitness_FitnessID.SPORT_REQUEST,
    fitness.Fitness(
      sportResponse: fitness.SportResponse(
        code: code,
        ids: request.ids,
        selectVersion: 2,
        gpsAccuracy: _latest == null || !valid(_latest!)
            ? fitness.GpsAccuracy.GPS_UNKNOWN
            : quality(_latest!),
      ),
    ),
  );
  Future<void> _send(
    fitness.Fitness_FitnessID id,
    fitness.Fitness payload,
  ) async {
    if (_disposed) return;
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.FITNESS,
      id: id.value,
      fitness: payload,
    );
    await (_sendOverride?.call(packet) ?? component.sendPbPacket(packet));
  }

  Future<void> _stop() async {
    _generation++;
    _prepareTimer?.cancel();
    _prepareTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _preparing = false;
    _active = false;
    _paused = false;
    _latest = null;
    _sport = null;
    _lastTimestamp = -1;
    if (_leased) {
      _leased = false;
      await _sessions.release(this);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _stop();
    await _queue;
    await _stop();
    await super.dispose();
  }
}
