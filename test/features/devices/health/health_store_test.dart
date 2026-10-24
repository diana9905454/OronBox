import 'package:drift/native.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HealthStore.databaseForTesting = HealthDatabase(NativeDatabase.memory());
    HealthStore.clearCache();
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

  test(
    'persists abnormal health records and prefers refreshed equal keys',
    () async {
      final store = HealthStore();
      const deviceId = 'health-store-regression';
      final day = DateTime(2026, 8, 25);
      final sampleTime = DateTime(2026, 8, 25, 8);
      final abnormalTime = DateTime(2026, 8, 25, 9);
      final abnormalStart = DateTime(2026, 8, 25, 8, 55);
      final abnormalEnd = DateTime(2026, 8, 25, 9, 5);

      await store.write(
        deviceId,
        XiaomiHealthData(
          daily: [HealthDailySummary(date: day, steps: 100)],
          samples: [
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 70,
            ),
          ],
          abnormalHealthRecords: [
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 125,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
          ],
          lastSyncedAt: DateTime(2026, 8, 25, 10),
        ),
      );

      await store.write(
        deviceId,
        XiaomiHealthData(
          daily: [
            HealthDailySummary(date: day, steps: 250),
            HealthDailySummary(date: day, steps: 100),
          ],
          samples: [
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 82,
            ),
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 70,
            ),
          ],
          abnormalHealthRecords: [
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 132,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 125,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
          ],
          lastSyncedAt: DateTime(2026, 8, 25, 11),
        ),
      );

      final saved = await store.read(deviceId);
      expect(saved.daily.single.steps, 250);
      expect(saved.latestSample(XiaomiHealthMetric.heartRate)?.value, 82);
      expect(saved.abnormalHealthRecords, hasLength(1));
      expect(saved.abnormalHealthRecords.single.value, 132);

      await HealthStore.flush();
      HealthStore.clearCache();
      final fromDisk = await store.read(deviceId);
      expect(fromDisk.daily.single.steps, 250);
      expect(fromDisk.latestSample(XiaomiHealthMetric.heartRate)?.value, 82);
      expect(fromDisk.abnormalHealthRecords, hasLength(1));
      expect(fromDisk.abnormalHealthRecords.single.value, 132);
    },
  );

  test('drops legacy health namespaces during the storage reset', () async {
    const deviceId = 'timezone-cache-regression';
    final legacyKey =
        'health_data_v5_${sha1.convert(deviceId.codeUnits).toString()}';
    SharedPreferences.setMockInitialValues({
      legacyKey: XiaomiHealthData(
        sleep: [
          HealthSleepSummary(
            startedAt: DateTime(2026, 9, 20, 18, 59),
            endedAt: DateTime(2026, 9, 20, 21, 39),
            durationSeconds: 2 * 60 * 60 + 40 * 60,
          ),
        ],
      ).encode(),
    });
    await SharedPrefsService.instance.reload();

    final store = HealthStore();
    await store.resetForStorageMigration();
    final data = await store.read(deviceId);

    expect(data.sleep, isEmpty);
    expect(SharedPrefsService.instance.getString(legacyKey), isNull);
  });

  test('collapses progressive sleep snapshots that share a bedtime', () async {
    final store = HealthStore();
    const deviceId = 'sleep-store-regression';
    // The full session plus shorter snapshots with the exact same bedtime,
    // as emitted while the watch progressively extends one night.
    HealthSleepSummary snapshot(DateTime start, DateTime end) =>
        HealthSleepSummary(
          startedAt: start,
          endedAt: end,
          durationSeconds: end.difference(start).inSeconds,
        );
    final bed = DateTime(2026, 8, 25, 4, 18);

    await store.write(
      deviceId,
      XiaomiHealthData(
        sleep: [
          // 04:18 – 10:04, the complete session.
          snapshot(bed, DateTime(2026, 8, 25, 10, 4)),
          // 04:18 – 09:04 and 04:18 – 08:04, contained in the session above.
          snapshot(bed, DateTime(2026, 8, 25, 9, 4)),
          snapshot(bed, DateTime(2026, 8, 25, 8, 4)),
          // A separate segment must not be swallowed just because it is
          // contained in the night interval.
          snapshot(DateTime(2026, 8, 25, 12), DateTime(2026, 8, 25, 13)),
        ],
      ),
    );

    final saved = await store.read(deviceId);
    // Only the longest snapshot for the exact bedtime remains; the separate
    // segment is preserved.
    expect(saved.sleep, hasLength(2));
    expect(
      saved.sleep.any((value) => value.endedAt == DateTime(2026, 8, 25, 10, 4)),
      isTrue,
    );
    expect(
      saved.sleep.any((value) => value.startedAt == DateTime(2026, 8, 25, 12)),
      isTrue,
    );
  });

  test(
    'merges repeated raw activity timestamps without summing deltas twice',
    () async {
      final store = HealthStore();
      const deviceId = 'activity-store-regression';
      final timestamp = DateTime(2026, 8, 25, 8);

      await store.write(
        deviceId,
        XiaomiHealthData(
          activitySamples: [
            HealthActivitySample(
              timestamp: timestamp,
              steps: 12,
              activeCalories: 2,
              caloriesDelta: 3,
            ),
            HealthActivitySample(timestamp: timestamp, floors: 1, pressure: 42),
          ],
        ),
      );

      final saved = await store.read(deviceId);
      expect(saved.activitySamples, hasLength(1));
      expect(saved.activitySamples.single.steps, 12);
      expect(saved.activitySamples.single.activeCalories, 2);
      expect(saved.activitySamples.single.caloriesDelta, 3);
      expect(saved.activitySamples.single.floors, 1);
      expect(saved.activitySamples.single.pressure, 42);
    },
  );
  test('clears v6 payloads without reconstructing health data', () async {
    const id = 'legacy-device';
    final hash = sha1.convert(id.codeUnits).toString();
    final raw = XiaomiHealthData(
      daily: [HealthDailySummary(date: DateTime(2026, 10, 19), steps: 321)],
    ).encode();
    final key = 'health_data_v6_$hash';
    await SharedPrefsService.instance.setString(key, raw);
    final store = HealthStore();
    await store.resetForStorageMigration();
    final data = await store.read(id);
    expect(data.daily, isEmpty);
    final source = await HealthStore.databaseForTesting!
        .customSelect('SELECT source FROM health_legacy_archive')
        .get();
    expect(source, isEmpty);
    expect(SharedPrefsService.instance.getString(key), isNull);
  });

  test(
    'a corrupt v6 source is not removed or replaced with empty data',
    () async {
      const id = 'damaged-device';
      final key = 'health_data_v6_${sha1.convert(id.codeUnits)}';
      await SharedPrefsService.instance.setString(key, '{broken');
      await HealthStore().resetForStorageMigration();
      expect(await HealthStore().read(id), isA<XiaomiHealthData>());
      expect(SharedPrefsService.instance.getString(key), isNull);
    },
  );
}
