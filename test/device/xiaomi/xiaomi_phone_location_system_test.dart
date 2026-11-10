import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/core/services/phone_location_sessions.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_fitness.pb.dart'
    as f;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_common.pb.dart'
    as c;
import 'package:oronbox/src/device/xiaomi/systems/phone_location_system.dart';

class _Sessions extends PhoneLocationSessions {
  final updates = StreamController<Position>.broadcast();
  bool allowed = true;
  int starts = 0, stops = 0;
  PlatformException? failure;
  @override
  bool get enabled => allowed;
  @override
  Stream<Position> get positions => updates.stream;
  @override
  Future<void> acquire(Object lease) async {
    starts++;
    if (failure case final error?) throw error;
  }

  @override
  Future<void> release(Object lease) async {
    stops++;
  }
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 10));
pb.WearPacket _prepare() => pb.WearPacket(
  type: pb.WearPacket_Type.FITNESS,
  id: f.Fitness_FitnessID.SPORT_PRE_REQUEST.value,
  fitness: f.Fitness(
    sportPreRequest: f.SportPreRequest(
      sportType: c.SportType.RUN_OUTDOOR,
      supportVersions: 2,
    ),
  ),
);
pb.WearPacket _state(c.SportState state) => pb.WearPacket(
  type: pb.WearPacket_Type.FITNESS,
  id: f.Fitness_FitnessID.SPORT_REQUEST.value,
  fitness: f.Fitness(
    sportRequest: f.SportRequest(
      timestamp: 1,
      timezone: c.Timezone(),
      sportType: c.SportType.RUN_OUTDOOR,
      state: state,
      ids: [1, 2],
      supportVersions: 2,
    ),
  ),
);
Position _fix(int second, {bool altitude = false}) => Position(
  latitude: 0,
  longitude: 0,
  timestamp: DateTime.fromMillisecondsSinceEpoch(second * 1000),
  ageMilliseconds: 0,
  accuracy: 5,
  provider: 'gps',
  satellitesUsed: 5,
  hasAltitude: altitude,
);

void main() {
  late _Sessions sessions;
  late List<pb.WearPacket> sent;
  late XiaomiPhoneLocationSystem system;
  setUp(() {
    sessions = _Sessions();
    sent = [];
    system = XiaomiPhoneLocationSystem(
      sessions: sessions,
      send: (p) async {
        sent.add(p);
      },
      prepareTimeout: const Duration(milliseconds: 30),
    );
  });
  tearDown(() async {
    await system.dispose();
    await sessions.updates.close();
  });
  test('disabled permission replies without starting the OS session', () async {
    sessions.allowed = false;
    system.onWearPacket(_prepare());
    await _flush();
    expect(sessions.starts, 0);
    expect(
      sent.single.fitness.sportPreResponse.code,
      f.SportResponse_Code.NO_PERMISSION,
    );
  });
  test('disabled provider is not misreported as missing permission', () async {
    sessions.failure = PlatformException(code: 'SERVICE_DISABLED');
    system.onWearPacket(_prepare());
    await _flush();
    expect(
      sent.single.fitness.sportPreResponse.code,
      f.SportResponse_Code.LACK_OF_ACCURACY,
    );
  });
  test(
    'first fix confirms preparation and preserves valid zero coordinates',
    () async {
      system.onWearPacket(_prepare());
      await _flush();
      sessions.updates.add(_fix(1));
      await _flush();
      expect(
        sent.single.fitness.sportPreResponse.gpsAccuracy,
        f.GpsAccuracy.GPS_HIGH,
      );
      expect(sent.single.fitness.sportPreResponse.selectVersion, 2);
    },
  );
  test(
    'active workout survives preparation timeout and deduplicates timestamps',
    () async {
      system.onWearPacket(_prepare());
      await _flush();
      system.onWearPacket(_state(c.SportState.SPORT_START));
      await _flush();
      await Future<void>.delayed(const Duration(milliseconds: 45));
      sessions.updates.add(_fix(1));
      sessions.updates.add(_fix(1));
      await _flush();
      final updates = sent
          .where((p) => p.fitness.hasPhoneSportDataV2d())
          .toList();
      expect(updates, hasLength(1));
      expect(updates.single.fitness.phoneSportDataV2d.latitude, 0);
      expect(updates.single.fitness.phoneSportDataV2d.hasAltitude(), isFalse);
      expect(sessions.stops, 0);
    },
  );
  test(
    'pause suppresses positions, resume sends, stop releases lease',
    () async {
      system.onWearPacket(_state(c.SportState.SPORT_START));
      await _flush();
      system.onWearPacket(_state(c.SportState.SPORT_PAUSE));
      await _flush();
      sessions.updates.add(_fix(1));
      await _flush();
      expect(sent.where((p) => p.fitness.hasPhoneSportDataV2d()), isEmpty);
      system.onWearPacket(_state(c.SportState.SPORT_RESUME));
      await _flush();
      sessions.updates.add(_fix(2, altitude: true));
      await _flush();
      expect(sent.last.fitness.phoneSportDataV2d.hasAltitude(), isTrue);
      system.onWearPacket(_state(c.SportState.SPORT_STOP));
      await _flush();
      expect(sent.last.fitness.sportResponse.ids, [1, 2]);
      expect(sessions.stops, 1);
    },
  );
  test('abandoned preparation releases the location session', () async {
    system.onWearPacket(_prepare());
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      sent.last.fitness.sportPreResponse.code,
      f.SportResponse_Code.LACK_OF_ACCURACY,
    );
    expect(sessions.stops, 1);
  });
  test('quality accurately maps fused and raw gps accuracies', () {
    final highGps = Position(
      latitude: 30,
      longitude: 120,
      timestamp: DateTime.now(),
      provider: 'gps',
      satellitesUsed: 6,
      accuracy: 25,
    );
    expect(XiaomiPhoneLocationSystem.quality(highGps), f.GpsAccuracy.GPS_HIGH);

    final fusedHigh = Position(
      latitude: 30,
      longitude: 120,
      timestamp: DateTime.now(),
      provider: 'fused',
      satellitesUsed: null,
      accuracy: 12,
    );
    expect(
      XiaomiPhoneLocationSystem.quality(fusedHigh),
      f.GpsAccuracy.GPS_HIGH,
    );

    final fusedMedium = Position(
      latitude: 30,
      longitude: 120,
      timestamp: DateTime.now(),
      provider: 'fused',
      satellitesUsed: null,
      accuracy: 35,
    );
    expect(
      XiaomiPhoneLocationSystem.quality(fusedMedium),
      f.GpsAccuracy.GPS_MEDIUM,
    );

    final fusedLow = Position(
      latitude: 30,
      longitude: 120,
      timestamp: DateTime.now(),
      provider: 'fused',
      satellitesUsed: null,
      accuracy: 80,
    );
    expect(XiaomiPhoneLocationSystem.quality(fusedLow), f.GpsAccuracy.GPS_LOW);

    final fusedUnknown = Position(
      latitude: 30,
      longitude: 120,
      timestamp: DateTime.now(),
      provider: 'fused',
      satellitesUsed: null,
      accuracy: 150,
    );
    expect(
      XiaomiPhoneLocationSystem.quality(fusedUnknown),
      f.GpsAccuracy.GPS_UNKNOWN,
    );
  });
  test('dispose cancels preparation and prevents later packets', () async {
    system.onWearPacket(_prepare());
    await _flush();
    await system.dispose();
    sessions.updates.add(_fix(1));
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(sent, isEmpty);
    expect(sessions.stops, 1);
  });
}
