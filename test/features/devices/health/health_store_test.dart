import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HealthStore.clearCache();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
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

  test('drops the pre-timezone-fix health namespace before reading', () async {
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

    final data = await HealthStore().read(deviceId);

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
}
