import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'health_models.dart';
import 'health_database_connection.dart';

final healthDatabase = HealthDatabase(openHealthDatabase());

String _sourceDigest(String source) =>
    sha256.convert(utf8.encode(source)).toString();

class HealthWorkoutTotals {
  const HealthWorkoutTotals({
    required this.durationSeconds,
    this.distanceMeters,
    this.calories,
    this.averageHeartRate,
  });
  final int durationSeconds;
  final int? distanceMeters, calories, averageHeartRate;
}

/// Record payloads retain the current health schema; SQL owns identity and indexing.
class HealthDatabase extends GeneratedDatabase {
  HealthDatabase(super.executor);
  @override
  int get schemaVersion => 4;
  @override
  Iterable<TableInfo> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE health_devices (device TEXT PRIMARY KEY, metadata TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE health_records (device TEXT NOT NULL, kind TEXT NOT NULL, record_key TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(device, kind, record_key))',
      );
      await _createLegacyArchive();
      await _createQueryIndex();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createLegacyArchive();
      if (from == 2) {
        await transaction(() async {
          await customStatement(
            'ALTER TABLE health_legacy_archive RENAME TO health_legacy_archive_v2',
          );
          await _createLegacyArchive();
          final old = await customSelect(
            'SELECT device, source FROM health_legacy_archive_v2',
          ).get();
          for (final row in old) {
            await preserveLegacySource(
              row.read<String>('device'),
              row.read<String>('source'),
            );
          }
          await customStatement('DROP TABLE health_legacy_archive_v2');
        });
      }
      if (from < 4) {
        await _createQueryIndex();
        var offset = 0;
        while (true) {
          final rows = await customSelect(
            'SELECT device, kind, record_key, payload FROM health_records LIMIT 200 OFFSET ?',
            variables: [Variable(offset)],
          ).get();
          if (rows.isEmpty) break;
          final indexed = await compute(
            _indexRows,
            rows
                .map(
                  (row) => [
                    row.read<String>('device'),
                    row.read<String>('kind'),
                    row.read<String>('record_key'),
                    row.read<String>('payload'),
                  ],
                )
                .toList(),
          );
          await batch((batch) {
            for (final row in indexed) {
              batch.customStatement(
                'UPDATE health_records SET record_at = ?, end_at = ?, preview = ? WHERE device = ? AND kind = ? AND record_key = ?',
                [row.$4, row.$5, row.$6, row.$1, row.$2, row.$3],
              );
            }
          });
          offset += rows.length;
        }
      }
    },
  );

  Future<void> _createQueryIndex() async {
    await customStatement(
      'ALTER TABLE health_records ADD COLUMN record_at INTEGER',
    );
    await customStatement(
      'ALTER TABLE health_records ADD COLUMN end_at INTEGER',
    );
    await customStatement('ALTER TABLE health_records ADD COLUMN preview TEXT');
    await customStatement(
      'CREATE INDEX health_records_time ON health_records(device, kind, record_at, record_key)',
    );
    await customStatement(
      'CREATE INDEX health_records_device_time ON health_records(device, record_at)',
    );
  }

  Future<bool> containsDevice(String device) async =>
      (await customSelect(
        'SELECT 1 FROM health_devices WHERE device = ?',
        variables: [Variable(device)],
      ).getSingleOrNull()) !=
      null;

  Future<int> storedBytes() async {
    final pages = await customSelect('PRAGMA page_count').getSingle();
    final size = await customSelect('PRAGMA page_size').getSingle();
    return pages.read<int>('page_count') * size.read<int>('page_size');
  }

  Future<void> compact() async {
    await customStatement('VACUUM');
  }

  Future<void> clearAll() async {
    await transaction(() async {
      await customStatement('DELETE FROM health_records');
      await customStatement('DELETE FROM health_devices');
      await customStatement('DELETE FROM health_legacy_archive');
    });
  }

  Future<XiaomiHealthData> readRange(
    String device, {
    required DateTime start,
    required DateTime end,
    bool summaries = true,
    List<String>? kinds,
    int? limit,
    int offset = 0,
  }) async {
    if (!end.isAfter(start) || offset < 0 || (limit != null && limit < 1)) {
      throw ArgumentError('Invalid health query range');
    }
    final rows = await transaction(() async {
      final metadata = await customSelect(
        'SELECT metadata FROM health_devices WHERE device = ?',
        variables: [Variable(device)],
      ).getSingleOrNull();
      if (metadata == null) return null;
      final filter = kinds == null
          ? ''
          : ' AND kind IN (${List.filled(kinds.length, '?').join(',')})';
      final records = await customSelect(
        'SELECT kind, ${summaries ? 'COALESCE(preview, payload)' : 'payload'} AS payload FROM health_records WHERE device = ? AND record_at < ? AND end_at >= ?$filter ORDER BY record_at DESC, record_key DESC${limit == null ? '' : ' LIMIT ? OFFSET ?'}',
        variables: [
          Variable(device),
          Variable(end.millisecondsSinceEpoch),
          Variable(start.millisecondsSinceEpoch),
          if (kinds != null) ...kinds.map(Variable.new),
          if (limit != null) ...[Variable(limit), Variable(offset)],
        ],
      ).get();
      return <Object?>[
        metadata.read<String>('metadata'),
        records
            .map(
              (row) => [row.read<String>('kind'), row.read<String>('payload')],
            )
            .toList(),
      ];
    });
    return rows == null
        ? const XiaomiHealthData()
        : compute(_decodeDevice, rows);
  }

  Future<HealthWorkoutTotals> workoutTotals(
    String device,
    DateTime start,
    DateTime end,
  ) async {
    final row = await customSelect(
      "SELECT SUM(COALESCE(json_extract(preview, '\$.totalDurationSeconds'), (end_at - record_at) / 1000)) AS duration, SUM(json_extract(preview, '\$.distanceMeters')) AS distance, SUM(json_extract(preview, '\$.calories')) AS calories, AVG(CASE WHEN json_extract(preview, '\$.averageHeartRate') > 0 THEN json_extract(preview, '\$.averageHeartRate') END) AS heart_rate FROM health_records WHERE device = ? AND kind = 'workouts' AND record_at < ? AND end_at >= ?",
      variables: [
        Variable(device),
        Variable(end.millisecondsSinceEpoch),
        Variable(start.millisecondsSinceEpoch),
      ],
    ).getSingle();
    return HealthWorkoutTotals(
      durationSeconds: row.readNullable<int>('duration') ?? 0,
      distanceMeters: (row.data['distance'] as num?)?.round(),
      calories: (row.data['calories'] as num?)?.round(),
      averageHeartRate: (row.data['heart_rate'] as num?)?.round(),
    );
  }

  Future<HealthWorkoutSummary?> readWorkout(
    String device,
    String routeId,
  ) async {
    final split = routeId.lastIndexOf('-');
    if (split < 0) return null;
    final timestamp = int.tryParse(routeId.substring(0, split));
    final type = int.tryParse(routeId.substring(split + 1));
    if (timestamp == null || type == null) return null;
    final records = await customSelect(
      "SELECT payload FROM health_records WHERE device = ? AND kind = 'workouts' AND record_at = ?",
      variables: [Variable(device), Variable(timestamp)],
    ).get();
    for (final row in records) {
      final workout = await compute(
        _decodeWorkout,
        row.read<String>('payload'),
      );
      if (workout.activityType == type) return workout;
    }
    return null;
  }

  Future<void> _createLegacyArchive() => customStatement(
    'CREATE TABLE health_legacy_archive (device TEXT NOT NULL, digest TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY(device, digest))',
  );

  Future<void> preserveLegacySource(String device, String source) async {
    final digest = await compute(_sourceDigest, source);
    await customStatement(
      'INSERT OR IGNORE INTO health_legacy_archive(device, digest, source) VALUES(?, ?, ?)',
      [device, digest, source],
    );
    final archived = await customSelect(
      'SELECT source FROM health_legacy_archive WHERE device = ? AND digest = ?',
      variables: [Variable(device), Variable(digest)],
    ).getSingleOrNull();
    if (archived == null || archived.read<String>('source') != source) {
      throw StateError('Unable to preserve original health data');
    }
  }

  Future<XiaomiHealthData?> readDevice(String device) async {
    final rows = await transaction(() async {
      final metadata = await customSelect(
        'SELECT metadata FROM health_devices WHERE device = ?',
        variables: [Variable(device)],
      ).getSingleOrNull();
      if (metadata == null) return null;
      final records = await customSelect(
        'SELECT kind, payload FROM health_records WHERE device = ? ORDER BY kind, record_key DESC',
        variables: [Variable(device)],
      ).get();
      return <Object?>[
        metadata.read<String>('metadata'),
        records
            .map(
              (row) => [row.read<String>('kind'), row.read<String>('payload')],
            )
            .toList(),
      ];
    });
    return rows == null ? null : compute(_decodeDevice, rows);
  }

  Future<void> writeDevice(
    String device,
    XiaomiHealthData data, {
    XiaomiHealthData? previous,
  }) async {
    final changes = await compute(_changes, (data, previous));
    await transaction(() async {
      for (final deletion in changes.$2) {
        await customStatement(
          'DELETE FROM health_records WHERE device = ? AND kind = ? AND record_key = ?',
          [device, deletion.$1, deletion.$2],
        );
      }
      await batch((batch) {
        batch.customStatement(
          'INSERT INTO health_devices(device, metadata) VALUES(?, ?) ON CONFLICT(device) DO UPDATE SET metadata = excluded.metadata',
          [device, changes.$3],
        );
        for (final row in changes.$1) {
          batch.customStatement(
            'INSERT INTO health_records(device, kind, record_key, payload, record_at, end_at, preview) VALUES(?, ?, ?, ?, ?, ?, ?) ON CONFLICT(device, kind, record_key) DO UPDATE SET payload = excluded.payload, record_at = excluded.record_at, end_at = excluded.end_at, preview = excluded.preview WHERE payload != excluded.payload',
            [device, row.$1, row.$2, row.$3, row.$4, row.$5, row.$6],
          );
        }
      });
    });
  }

  Future<Map<String, String>> exportData() => transaction(() async {
    final result = <String, String>{};
    final devices = await customSelect('SELECT device FROM health_devices')
        .get();
    for (final row in devices) {
      final key = row.read<String>('device');
      final data = await readDevice(key);
      if (data != null) result[key] = await compute(_encodeDevice, data);
    }
    return result;
  });

  Future<void> importData(Map<String, XiaomiHealthData> devices) =>
      transaction(() async {
        for (final entry in devices.entries) {
          // Restore is an explicit replacement of each selected device's local history.
          await customStatement('DELETE FROM health_records WHERE device = ?', [
            entry.key,
          ]);
          await writeDevice(entry.key, entry.value);
        }
      });

  Future<void> replaceData(Map<String, XiaomiHealthData> devices) =>
      transaction(() async {
        await customStatement('DELETE FROM health_records');
        await customStatement('DELETE FROM health_devices');
        await importData(devices);
      });
}

String _encodeDevice(XiaomiHealthData data) => data.encode();
Future<bool> healthDataEquivalent(XiaomiHealthData a, XiaomiHealthData b) =>
    compute(_equivalent, (a, b));

bool _equivalent((XiaomiHealthData, XiaomiHealthData) input) {
  final a = _records(input.$1);
  final b = _records(input.$2);
  return a.keys.every(
        (kind) =>
            a[kind]!.length == b[kind]!.length &&
            a[kind]!.entries.every(
              (entry) => b[kind]![entry.key] == entry.value,
            ),
      ) &&
      jsonEncode(input.$1.capabilities.toJson()) ==
          jsonEncode(input.$2.capabilities.toJson()) &&
      input.$1.lastSyncedAt == input.$2.lastSyncedAt;
}

XiaomiHealthData _decodeDevice(List<Object?> input) {
  final json = (jsonDecode(input[0] as String) as Map).cast<String, Object?>();
  for (final raw in input[1] as List) {
    final row = raw as List;
    (json.putIfAbsent(row[0] as String, () => <Object?>[]) as List).add(
      jsonDecode(row[1] as String),
    );
  }
  for (final entry in json.entries) {
    if (entry.value is! List) continue;
    final field = switch (entry.key) {
      'daily' => 'date',
      'sleep' => 'endedAt',
      'workouts' => 'startedAt',
      _ => 'timestamp',
    };
    (entry.value as List).sort(
      (a, b) =>
          DateTime.parse((b as Map)[field] as String)
              .compareTo(DateTime.parse((a as Map)[field] as String)),
    );
  }
  return XiaomiHealthData.fromJson(json);
}

typedef HealthChanges = (
  List<(String, String, String, int, int, String?)>,
  List<(String, String)>,
  String,
);
HealthChanges _changes((XiaomiHealthData, XiaomiHealthData?) input) {
  final next = _records(input.$1);
  final previous = input.$2 == null
      ? <String, Map<String, String>>{}
      : _records(input.$2!);
  final writes = <(String, String, String, int, int, String?)>[];
  final deletes = <(String, String)>[];
  for (final group in next.entries) {
    final old = previous[group.key] ?? const <String, String>{};
    for (final row in group.value.entries) {
      if (old[row.key] != row.value) {
        final index = _recordIndex(group.key, row.value);
        writes.add((
          group.key,
          row.key,
          row.value,
          index.$1,
          index.$2,
          index.$3,
        ));
      }
    }
    for (final key in old.keys) {
      if (!group.value.containsKey(key)) deletes.add((group.key, key));
    }
  }
  final data = input.$1;
  return (
    writes,
    deletes,
    jsonEncode({
      'schema': 2,
      'capabilities': data.capabilities.toJson(),
      'lastSyncedAt': data.lastSyncedAt?.toIso8601String(),
    }),
  );
}

Map<String, Map<String, String>> _records(XiaomiHealthData data) {
  Map<String, String> rows(
    Iterable<Map<String, Object?>> values,
    List<String> keys,
  ) => {
    for (final value in values)
      jsonEncode([for (final key in keys) value[key]]): jsonEncode(value),
  };
  return {
    'daily': rows(data.daily.map((v) => v.toJson()), ['date']),
    'samples': rows(data.samples.map((v) => v.toJson()), [
      'metric',
      'timestamp',
    ]),
    'activitySamples': rows(data.activitySamples.map((v) => v.toJson()), [
      'timestamp',
    ]),
    'sleep': rows(data.sleep.map((v) => v.toJson()), ['startedAt']),
    'workouts': rows(data.workouts.map((v) => v.toJson()), [
      'activityType',
      'startedAt',
    ]),
    'abnormalHealthRecords': rows(
      data.abnormalHealthRecords.map((v) => v.toJson()),
      ['kind', 'timestamp', 'startedAt', 'endedAt'],
    ),
  };
}

HealthWorkoutSummary _decodeWorkout(String payload) =>
    HealthWorkoutSummary.fromJson((jsonDecode(payload) as Map).cast());

(int, int, String?) _recordIndex(String kind, String payload) {
  final json = (jsonDecode(payload) as Map).cast<String, Object?>();
  final field = switch (kind) {
    'daily' => 'date',
    'sleep' || 'workouts' => 'startedAt',
    _ => 'timestamp',
  };
  final start = DateTime.parse(json[field] as String).millisecondsSinceEpoch;
  final end = json['endedAt'] == null
      ? start
      : DateTime.parse(json['endedAt'] as String).millisecondsSinceEpoch;
  if (kind != 'workouts') return (start, end, null);
  final workout = HealthWorkoutSummary.fromJson(json);
  if (workout.effectiveAverageHeartRate case final value?) {
    json['averageHeartRate'] = value;
  }
  if (workout.effectiveMinimumHeartRate case final value?) {
    json['minimumHeartRate'] = value;
  }
  if (workout.effectiveMaximumHeartRate case final value?) {
    json['maximumHeartRate'] = value;
  }
  json.remove('samples');
  json.remove('route');
  return (start, end, jsonEncode(json));
}

List<(String, String, String, int, int, String?)> _indexRows(
  List<List<String>> rows,
) => [
  for (final row in rows)
    (() {
      final index = _recordIndex(row[1], row[3]);
      return (row[0], row[1], row[2], index.$1, index.$2, index.$3);
    })(),
];
