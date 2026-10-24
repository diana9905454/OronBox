import 'package:drift/native.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HealthStore.databaseForTesting = HealthDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
  });

  tearDown(() async {
    await HealthStore.flush();
    await HealthStore.databaseForTesting?.close();
    HealthStore.databaseForTesting = null;
    HealthStore.clearCache();
  });

  test('raw snapshot replay preserves health data outside the snapshot', () async {
    const deviceId = 'snapshot-overlay-regression';
    final previousDay = DateTime(2026, 8, 1);
    final previousSampleTime = DateTime(2026, 8, 1, 9);
    final parser = XiaomiHealthSystem();
    final file = File(
      '${Directory.current.path}/test/device/xiaomi/fixtures/c0e9ae6a100400.bin',
    );
    final rawFile = XiaomiActivityRawFile(
      id: 'c0e9ae6a100400',
      data: file.readAsBytesSync(),
    );
    final freshHeartRate = parser
        .parseActivityFilesForDebug([rawFile])
        .samples
        .firstWhere((sample) => sample.heartRate != null);
    final store = HealthStore();
    await store.write(
      deviceId,
      XiaomiHealthData(
        daily: [HealthDailySummary(date: previousDay, steps: 1200)],
        samples: [
          HealthSample(
            timestamp: previousSampleTime,
            metric: XiaomiHealthMetric.heartRate,
            value: 77,
          ),
          HealthSample(
            timestamp: freshHeartRate.timestamp,
            metric: XiaomiHealthMetric.heartRate,
            value: 30,
          ),
        ],
        activitySamples: [
          HealthActivitySample(timestamp: previousSampleTime, steps: 15),
        ],
      ),
    );

    final service = XiaomiHealthSyncService(
      system: parser,
      deviceId: deviceId,
      store: store,
    );
    final replayed = await service.replayFromRawFiles([rawFile]);
    await parser.dispose();

    expect(replayed.daily.any((day) => day.date == previousDay), isTrue);
    expect(
      replayed.samples.any(
        (sample) =>
            sample.timestamp == previousSampleTime && sample.value == 77,
      ),
      isTrue,
    );
    expect(
      replayed.activitySamples.any(
        (sample) =>
            sample.timestamp == previousSampleTime && sample.steps == 15,
      ),
      isTrue,
    );
    expect(replayed.samples, isNotEmpty);
    expect(
      replayed.samples
          .where(
            (sample) =>
                sample.timestamp == freshHeartRate.timestamp &&
                sample.metric == XiaomiHealthMetric.heartRate,
          )
          .single
          .value,
      freshHeartRate.heartRate!.toDouble(),
    );
  });
}
