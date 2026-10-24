import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HealthDatabase db;
  setUp(() => db = HealthDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
  final start = DateTime.utc(2026, 10, 18);
  HealthWorkoutSummary workout(int index) => HealthWorkoutSummary(
    startedAt: start.add(Duration(hours: index)),
    endedAt: start.add(Duration(hours: index, minutes: 30)),
    activityType: index,
    distanceMeters: 0,
    calories: 0,
    samples: [HealthWorkoutSample(timestamp: start, heartRate: 80)],
    route: [
      HealthWorkoutRoutePoint(timestamp: start, latitude: 30, longitude: 120),
    ],
  );
  test(
    'range queries use half-open bounds and retain zero and overnight sleep',
    () async {
      await db.writeDevice(
        'a',
        XiaomiHealthData(
          daily: [
            HealthDailySummary(date: start, steps: 0),
            HealthDailySummary(
              date: start.subtract(const Duration(days: 1)),
              steps: 99,
            ),
          ],
          sleep: [
            HealthSleepSummary(
              durationSeconds: 8 * 3600,
              startedAt: start.subtract(const Duration(hours: 2)),
              endedAt: start.add(const Duration(hours: 6)),
            ),
          ],
        ),
      );
      final data = await db.readRange(
        'a',
        start: start,
        end: start.add(const Duration(days: 1)),
      );
      expect(data.daily.single.steps, 0);
      expect(data.sleep, hasLength(1));
      expect(await db.storedBytes(), greaterThan(0));
    },
  );
  test(
    'summaries omit payloads while details preserve routes and samples',
    () async {
      final value = workout(1);
      await db.writeDevice('a', XiaomiHealthData(workouts: [value]));
      final list = await db.readRange(
        'a',
        start: start,
        end: start.add(const Duration(days: 1)),
      );
      expect(list.workouts.single.route, isEmpty);
      expect(list.workouts.single.samples, isEmpty);
      expect(list.workouts.single.effectiveAverageHeartRate, 80);
      final detail = await db.readWorkout(
        'a',
        '${value.startedAt.millisecondsSinceEpoch}-1',
      );
      expect(detail!.route.single.longitude, 120);
      expect(detail.samples.single.heartRate, 80);
    },
  );
  test('pagination does not truncate the independent period totals', () async {
    await db.writeDevice(
      'a',
      XiaomiHealthData(workouts: [for (var i = 0; i < 5; i++) workout(i)]),
    );
    final a = await db.readRange(
      'a',
      start: start,
      end: start.add(const Duration(days: 1)),
      kinds: ['workouts'],
      limit: 2,
    );
    final b = await db.readRange(
      'a',
      start: start,
      end: start.add(const Duration(days: 1)),
      kinds: ['workouts'],
      limit: 2,
      offset: 2,
    );
    expect(a.workouts.map((value) => value.activityType), [4, 3]);
    expect(b.workouts.map((value) => value.activityType), [2, 1]);
    final totals = await db.workoutTotals(
      'a',
      start,
      start.add(const Duration(days: 1)),
    );
    expect(totals.durationSeconds, 5 * 1800);
    expect(totals.distanceMeters, 0);
    expect(totals.calories, 0);
    expect(totals.averageHeartRate, 80);
  });
  test(
    'upgrades v3 rows without rewriting their authoritative payload',
    () async {
      await db.close();
      final payload = jsonEncode(workout(1).toJson());
      db = HealthDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute(
              'CREATE TABLE health_devices (device TEXT PRIMARY KEY, metadata TEXT NOT NULL)',
            );
            sqlite.execute(
              'CREATE TABLE health_records (device TEXT NOT NULL, kind TEXT NOT NULL, record_key TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(device, kind, record_key))',
            );
            sqlite.execute(
              'CREATE TABLE health_legacy_archive (device TEXT NOT NULL, digest TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY(device, digest))',
            );
            sqlite.execute('INSERT INTO health_devices VALUES(?, ?)', [
              'a',
              '{"schema":2,"capabilities":{}}',
            ]);
            sqlite.execute('INSERT INTO health_records VALUES(?, ?, ?, ?)', [
              'a',
              'workouts',
              'key',
              payload,
            ]);
            sqlite.execute('PRAGMA user_version = 3');
          },
        ),
      );
      final data = await db.readRange(
        'a',
        start: start,
        end: start.add(const Duration(days: 1)),
      );
      expect(data.workouts.single.activityType, 1);
      expect(
        (await db
                .customSelect('SELECT payload FROM health_records')
                .getSingle())
            .read<String>('payload'),
        payload,
      );
    },
  );
}
