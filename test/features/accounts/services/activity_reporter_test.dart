import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/accounts/services/activity_reporter.dart';

void main() {
  test('deduplicates successes, reports upgrades and accounts, rolls over on server day', () async {
    final cache = <String, String>{};
    var now = DateTime.utc(2026, 10, 17, 10);
    var calls = 0;
    final reporter = ActivityReporter(
      read: (k) => cache[k],
      write: (k, v) async {
        cache[k] = v;
      },
      clock: () => now,
      send: (_, _, _) async {
        calls++;
        return {
          'server_time': now.toIso8601String(),
          'next_day_start': DateTime.utc(
            2026,
            10,
            now.day,
            16,
          ).toIso8601String(),
        };
      },
    );
    await reporter.report('u1', '1', 'android');
    await reporter.report('u1', '1', 'android');
    expect(calls, 1);
    await reporter.report('u1', '2', 'android');
    await reporter.report('u2', '2', 'android');
    expect(calls, 3);
    now = DateTime.utc(2026, 10, 18, 0);
    await reporter.report('u1', '1', 'android');
    expect(calls, 4);
  });
  test(
    'coalesces in-flight triggers and retries failure only when triggered',
    () async {
      var calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      final reporter = ActivityReporter(
        read: (_) => null,
        write: (_, _) async {},
        send: (_, _, _) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.error(Exception('offline'));
        },
      );
      final a = reporter.report('u', '1', 'ios');
      final b = reporter.report('u', '1', 'ios');
      expect(calls, 1);
      pending.completeError(Exception('offline'));
      await Future.wait([a, b]);
      expect(calls, 1);
      await reporter.report('u', '1', 'ios');
      expect(calls, 2);
    },
  );
  test('uses server clock offset and recovers corrupt cache', () async {
    var value = 'broken';
    var calls = 0;
    final reporter = ActivityReporter(
      read: (_) => value,
      write: (_, v) async {
        value = v;
      },
      clock: () => DateTime.utc(2020),
      send: (_, _, _) async {
        calls++;
        return {
          'server_time': '2026-10-17T10:00:00Z',
          'next_day_start': '2026-10-17T16:00:00Z',
        };
      },
    );
    await reporter.report('u', '1', 'android');
    await reporter.report('u', '1', 'android');
    expect(calls, 1);
  });
}
