import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/pages/more/xiaomi_health_detail_page.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  test('treats zero stress as a missing measurement', () {
    final timestamp = DateTime(2026, 8, 22, 9);
    expect(
      HealthSample(
        timestamp: timestamp,
        metric: XiaomiHealthMetric.stress,
        value: 0,
      ).isUsable,
      isFalse,
    );
    expect(
      HealthSample(
        timestamp: timestamp,
        metric: XiaomiHealthMetric.stress,
        value: 51,
      ).isUsable,
      isTrue,
    );
  });

  test('aggregates the latest 24 hours into fixed hourly ranges', () {
    final start = DateTime(2026, 8, 21, 9);
    final ranges = aggregateHealthHourlyRanges(
      [
        HealthSample(
          timestamp: start.add(const Duration(minutes: 5)),
          metric: XiaomiHealthMetric.heartRate,
          value: 70,
        ),
        HealthSample(
          timestamp: start.add(const Duration(minutes: 45)),
          metric: XiaomiHealthMetric.heartRate,
          value: 96,
        ),
        HealthSample(
          timestamp: start.add(const Duration(hours: 23, minutes: 30)),
          metric: XiaomiHealthMetric.heartRate,
          value: 64,
        ),
      ],
      start: start,
      end: start.add(const Duration(hours: 24)),
    );

    expect(ranges, hasLength(24));
    expect(ranges.first?.minimum, 70);
    expect(ranges.first?.maximum, 96);
    expect(ranges[1], isNull);
    expect(ranges.last?.minimum, 64);
    expect(ranges.last?.maximum, 64);
  });

  testWidgets('phone layout keeps cards in one readable column', (
    tester,
  ) async {
    const keys = [Key('activity'), Key('first'), Key('second'), Key('third')];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 328,
              child: AdaptiveHealthCardWrap(
                children: [
                  SizedBox(key: keys[0], height: 20),
                  SizedBox(key: keys[1], height: 20),
                  SizedBox(key: keys[2], height: 20),
                  SizedBox(key: keys[3], height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final activity = tester.getRect(find.byKey(keys[0]));
    final first = tester.getRect(find.byKey(keys[1]));
    final second = tester.getRect(find.byKey(keys[2]));
    final third = tester.getRect(find.byKey(keys[3]));
    expect(activity.width, 328);
    expect(first.width, 328);
    expect(second.width, 328);
    expect(third.width, 328);
    expect(first.top, greaterThan(activity.top));
    expect(second.top, greaterThan(first.top));
    expect(third.top, greaterThan(second.top));
  });

  testWidgets('sleep card exposes stage and sleep vital summaries', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 25, 12, 55);
    final sleep = HealthSleepSummary(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 7, minutes: 29)),
      durationSeconds: 7 * 3600 + 29 * 60,
      averageHeartRate: 67,
      averageBloodOxygen: 96,
      deepSleepDurationSeconds: 60 * 60 + 1 * 60,
      lightSleepDurationSeconds: 4 * 3600 + 59 * 60,
      remSleepDurationSeconds: 60 * 60 + 29 * 60,
      hrvPoints: [
        HealthSleepHrvPoint(timestamp: start, value: 16),
        HealthSleepHrvPoint(
          timestamp: start.add(const Duration(hours: 7)),
          value: 32,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HealthSleepCard(
              title: '睡眠',
              icon: Icons.bedtime_outlined,
              color: Colors.deepPurple,
              summary: sleep,
              noDataLabel: '暂无数据',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深睡'), findsOneWidget);
    expect(find.text('浅睡'), findsOneWidget);
    expect(find.text('REM'), findsOneWidget);
    expect(find.text('1h 1m'), findsOneWidget);
    expect(find.text('4h 59m'), findsOneWidget);
    expect(find.text('1h 29m'), findsOneWidget);
    expect(find.text('睡眠 HRV'), findsOneWidget);
    expect(find.text('24 ms'), findsOneWidget);
    expect(find.text('67 bpm'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
  });

  testWidgets('activity values are distributed around the card width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 328,
            child: ActivityOverviewCard(summary: null, onPressed: () {}),
          ),
        ),
      ),
    );

    final labels = [
      '消耗',
      '步数',
      '站立',
    ].map((label) => tester.getCenter(find.text(label)).dx).toList();
    expect(labels[1] - labels[0], closeTo(labels[2] - labels[1], 2));
  });

  testWidgets('sleep card omits unavailable REM data', (tester) async {
    final start = DateTime(2026, 8, 27, 16, 14);
    final sleep = HealthSleepSummary(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 6)),
      durationSeconds: 6 * 3600,
      stages: [
        HealthSleepStageSegment(
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 90)),
          kind: HealthSleepStageKind.deep,
        ),
        HealthSleepStageSegment(
          startedAt: start.add(const Duration(minutes: 90)),
          endedAt: start.add(const Duration(hours: 6)),
          kind: HealthSleepStageKind.light,
        ),
      ],
      deepSleepDurationSeconds: 90 * 60,
      lightSleepDurationSeconds: 270 * 60,
      remSleepDurationSeconds: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HealthSleepCard(
            title: '睡眠',
            icon: Icons.bedtime_outlined,
            color: Colors.deepPurple,
            summary: sleep,
            noDataLabel: '暂无数据',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深睡'), findsOneWidget);
    expect(find.text('浅睡'), findsOneWidget);
    expect(find.text('REM'), findsNothing);
  });

  testWidgets('daily and abnormal heart-rate cards fit the phone layout', (
    tester,
  ) async {
    final days = [
      HealthDailySummary(date: DateTime(2026, 8, 20), restingHeartRate: 58),
      HealthDailySummary(date: DateTime(2026, 8, 21), restingHeartRate: 56),
      HealthDailySummary(date: DateTime(2026, 8, 22), restingHeartRate: 57),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 328,
            child: Column(
              children: [
                HealthDailyMetricCard(
                  title: '静息心率',
                  icon: Icons.favorite_border,
                  color: Colors.pinkAccent,
                  value: '57 bpm',
                  detail: '2026/8/22',
                  days: days,
                  valueFor: (day) => day.restingHeartRate,
                  onPressed: () {},
                ),
                HealthAbnormalHeartRateCard(
                  title: '异常心率',
                  records: [
                    HealthAbnormalHeartRateRecord(
                      timestamp: DateTime(2026, 8, 22, 10),
                      value: 126,
                      kind: HealthAbnormalHeartRateKind.high,
                      threshold: 120,
                    ),
                  ],
                  highLabel: '心率过高',
                  lowLabel: '心率过低',
                  recordLabel: '条记录',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('official health detail chart switches day, week, and month', (
    tester,
  ) async {
    final days = [
      for (var index = 0; index < 31; index++)
        HealthDailySummary(
          date: DateTime(2026, 8, 1 + index),
          averageHeartRate: 70 + index % 5,
          minHeartRate: 60 + index % 3,
          maxHeartRate: 90 + index % 4,
        ),
    ];
    final samples = [
      for (var hour = 0; hour < 24; hour++)
        HealthSample(
          timestamp: DateTime(2026, 8, 31, hour),
          metric: XiaomiHealthMetric.heartRate,
          value: 65 + hour % 20,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.heartRate,
              data: XiaomiHealthData(daily: days, samples: samples),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('health detail date navigation can return to the current day', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBeforeYesterday = today.subtract(const Duration(days: 2));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.heartRate,
              data: XiaomiHealthData(
                samples: [
                  HealthSample(
                    timestamp: today.add(const Duration(hours: 8)),
                    metric: XiaomiHealthMetric.heartRate,
                    value: 72,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String label(DateTime date) => '${date.year}年${date.month}月${date.day}日';

    expect(find.text(label(today)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(label(yesterday)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text(label(today)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(label(dayBeforeYesterday)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text(label(yesterday)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text(label(today)), findsOneWidget);
  });

  testWidgets('sleep day view shows one all-day record and week expands it', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final previousDay = today.subtract(const Duration(days: 1));
    final previousSleep = HealthSleepSummary(
      startedAt: previousDay.add(const Duration(hours: 12)),
      endedAt: previousDay.add(const Duration(hours: 14)),
      durationSeconds: 2 * 60 * 60,
    );
    final currentSleep = HealthSleepSummary(
      startedAt: today.add(const Duration(hours: 18)),
      endedAt: today.add(const Duration(hours: 19)),
      durationSeconds: 60 * 60,
      averageHeartRate: 67,
      averageBloodOxygen: 96,
      deepSleepDurationSeconds: 18 * 60,
      lightSleepDurationSeconds: 31 * 60,
      remSleepDurationSeconds: 11 * 60,
      stages: [
        HealthSleepStageSegment(
          startedAt: today.add(const Duration(hours: 18)),
          endedAt: today.add(const Duration(hours: 18, minutes: 20)),
          kind: HealthSleepStageKind.deep,
        ),
        HealthSleepStageSegment(
          startedAt: today.add(const Duration(hours: 18, minutes: 20)),
          endedAt: today.add(const Duration(hours: 18, minutes: 50)),
          kind: HealthSleepStageKind.light,
        ),
        HealthSleepStageSegment(
          startedAt: today.add(const Duration(hours: 18, minutes: 50)),
          endedAt: today.add(const Duration(hours: 19)),
          kind: HealthSleepStageKind.rem,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.sleep,
              data: XiaomiHealthData(sleep: [previousSleep, currentSleep]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('长睡眠'), findsOneWidget);
    expect(find.text('1小时'), findsOneWidget);
    expect(find.text('2小时'), findsNothing);
    expect(find.text('睡眠结构'), findsOneWidget);
    expect(find.text('睡眠平均心率'), findsOneWidget);
    expect(find.text('睡眠平均血氧'), findsOneWidget);
    expect(find.text('最新'), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsNothing);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(find.text('2小时'), findsOneWidget);
    expect(
      find.text('${previousDay.year}/${previousDay.month}/${previousDay.day}'),
      findsOneWidget,
    );
  });

  testWidgets('sleep detail omits unavailable REM stage', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 1);
    final sleep = HealthSleepSummary(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 6)),
      durationSeconds: 6 * 3600,
      deepSleepDurationSeconds: 90 * 60,
      lightSleepDurationSeconds: 270 * 60,
      remSleepDurationSeconds: 0,
      stages: [
        HealthSleepStageSegment(
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 90)),
          kind: HealthSleepStageKind.deep,
        ),
        HealthSleepStageSegment(
          startedAt: start.add(const Duration(minutes: 90)),
          endedAt: start.add(const Duration(hours: 6)),
          kind: HealthSleepStageKind.light,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.sleep,
              data: XiaomiHealthData(sleep: [sleep]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深睡'), findsNWidgets(2));
    expect(find.text('浅睡'), findsNWidgets(2));
    expect(find.text('REM'), findsNothing);
    expect(find.text('0%'), findsNothing);
  });
}
