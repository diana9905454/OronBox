import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_detail_page.dart';

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

  test('aggregates the latest 24 hours into 48 half-hour ranges', () {
    final start = DateTime(2026, 8, 21, 9);
    final ranges = aggregateHealthRanges(
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
      slots: 48,
    );

    expect(ranges, hasLength(48));
    expect(ranges.first?.minimum, 70);
    expect(ranges.first?.maximum, 70);
    expect(ranges[1]?.minimum, 96);
    expect(ranges[2], isNull);
    expect(ranges.last?.minimum, 64);
    expect(ranges.last?.maximum, 64);
  });

  testWidgets('home timeline does not extend heart-rate bars to 220 bpm', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 22);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 300,
            child: HealthMetricCard(
              metric: XiaomiHealthMetric.heartRate,
              title: '心率',
              icon: Icons.favorite_outline,
              color: Colors.redAccent,
              value: '218 bpm',
              detail: '10:05',
              samples: [
                HealthSample(
                  timestamp: start.add(const Duration(minutes: 5)),
                  metric: XiaomiHealthMetric.heartRate,
                  value: 218,
                ),
              ],
              chartStart: start,
              chartEnd: start.add(const Duration(hours: 24)),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(48));
    expect(
      chart.data.gridData.horizontalInterval,
      chart.data.titlesData.leftTitles.sideTitles.interval,
    );
    final measured = chart.data.barGroups.first.barRods.single;
    expect(measured.toY, lessThan(220));
    expect(measured.backDrawRodData.show, isTrue);
    final empty = chart.data.barGroups[2].barRods.single;
    expect(empty.backDrawRodData.show, isTrue);
    expect(chart.data.minY, 30);
    expect(chart.data.maxY, 220);
    expect(chart.data.gridData.horizontalInterval, 95);
  });

  testWidgets('phone layout keeps cards in one readable column', (
    tester,
  ) async {
    const keys = [Key('activity'), Key('first'), Key('second'), Key('third')];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets('workout home card titles the card before its latest workout', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 25, 8);
    final workout = HealthWorkoutSummary(
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 30)),
      activityType: 1,
      distanceMeters: 5000,
      averagePaceSecondsPerKilometer: 360,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HealthWorkoutCard(workouts: [workout], onPressed: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('运动'), findsOneWidget);
    expect(find.text('户外跑步'), findsOneWidget);
    expect(find.text('平均配速'), findsAtLeastNWidgets(1));
    expect(find.text("6'00\""), findsOneWidget);
    expect(find.text("6'00\" /km"), findsNothing);
    expect(tester.getSize(find.byType(Card)).height, lessThan(214));
  });

  testWidgets('home metric card keeps its chart in a bounded card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HealthMetricCard(
              metric: XiaomiHealthMetric.heartRate,
              title: '心率',
              icon: Icons.favorite_outline,
              color: Colors.redAccent,
              value: '72 bpm',
              detail: '60–90 bpm',
              samples: const [],
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Card)).height, 214);
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
        localizationsDelegates: appLocalizationsDelegates,
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
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 328,
            child: ActivityOverviewCard(summary: null, onPressed: () {}),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.fitness_center_outlined), findsNothing);
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
        localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets('vitality card uses a score and flat supporting facts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HealthVitalityCard(
              title: '元气值',
              icon: Icons.bolt_outlined,
              color: Colors.amber,
              summary: HealthDailySummary(
                date: DateTime(2026, 8, 27),
                vitalityCurrent: 72,
                vitalityLast7Days: 68,
                vitalityIncreaseLight: 12,
                vitalityIncreaseModerate: 8,
                vitalityIncreaseHigh: 4,
                vitalityNextTargetMinutes: 20,
              ),
              sevenDayTotal: 61,
              noDataLabel: '暂无数据',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The local calendar-window total wins over the device field, which can
    // skip zero days.
    expect(find.text('61'), findsOneWidget);
    expect(find.text('低强度'), findsOneWidget);
    expect(find.text('中高强度'), findsOneWidget);
    expect(find.text('下一目标'), findsOneWidget);
  });

  testWidgets('vitality card falls back to the device total', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HealthVitalityCard(
              title: '元气值',
              icon: Icons.bolt_outlined,
              color: Colors.amber,
              summary: HealthDailySummary(
                date: DateTime(2026, 8, 27),
                vitalityCurrent: 72,
                vitalityLast7Days: 68,
              ),
              noDataLabel: '暂无数据',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('68'), findsOneWidget);
  });

  testWidgets('vitality detail aligns its header, color, and training row', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 27);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 1200,
            child: XiaomiHealthDetailPage(
              args: XiaomiHealthDetailArgs(
                metric: XiaomiHealthMetric.vitality,
                data: XiaomiHealthData(
                  daily: [
                    HealthDailySummary(
                      date: date,
                      vitalityCurrent: 72,
                      vitalityLast7Days: 68,
                      remainingRecoveryHours: 3,
                      trainingLoadToday: 10,
                      trainingLoadLast7Days: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前元气值'), findsOneWidget);
    expect(find.text('近 7 日元气值'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.color, Colors.amber);
    final trainingLabels = [
      '恢复时间',
      '今日负荷',
      '7 日负荷',
    ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
    final minimum = trainingLabels.reduce(
      (left, right) => left < right ? left : right,
    );
    final maximum = trainingLabels.reduce(
      (left, right) => left > right ? left : right,
    );
    expect(maximum - minimum, lessThanOrEqualTo(1));
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
        localizationsDelegates: appLocalizationsDelegates,
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
          localizationsDelegates: appLocalizationsDelegates,
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
    expect(find.text('今日概览'), findsNothing);
    expect(find.text('每日摘要'), findsNothing);
    final dayChart = tester.widget<LineChart>(find.byType(LineChart).first);
    expect(dayChart.data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(
      dayChart.data.gridData.horizontalInterval,
      dayChart.data.titlesData.leftTitles.sideTitles.interval,
    );

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('本周概览'), findsNothing);
    expect(find.text('每日摘要'), findsNothing);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('本月概览'), findsNothing);
    expect(find.text('每日摘要'), findsNothing);
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
          localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets('activity detail uses period charts without the ring graphic', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 25);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.activity,
              data: XiaomiHealthData(
                daily: [
                  HealthDailySummary(
                    date: start,
                    steps: 4200,
                    activeCalories: 260,
                  ),
                  HealthDailySummary(
                    date: start.add(const Duration(days: 1)),
                    steps: 5300,
                    activeCalories: 310,
                  ),
                  HealthDailySummary(
                    date: start.add(const Duration(days: 2)),
                    steps: 2800,
                    activeCalories: 180,
                  ),
                ],
                activitySamples: [
                  HealthActivitySample(
                    timestamp: start.add(const Duration(days: 2, hours: 7)),
                    steps: 120,
                    activeCalories: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivityTimelineChart), findsNothing);
    expect(find.byType(ActivityHourlyChart), findsNWidgets(3));
    expect(find.text('24:00'), findsNWidgets(3));
    final activityCharts = tester.widgetList<BarChart>(find.byType(BarChart));
    expect(activityCharts, hasLength(3));
    for (final activityChart in activityCharts) {
      expect(activityChart.data.barGroups, hasLength(24));
      expect(
        activityChart.data.gridData.horizontalInterval,
        activityChart.data.titlesData.leftTitles.sideTitles.interval,
      );
      expect(
        activityChart.data.barGroups[7].barRods.single.toY,
        greaterThan(0),
      );
      expect(
        activityChart.data.barGroups[7].barRods.single.backDrawRodData.show,
        isTrue,
      );
      expect(
        activityChart.data.barGroups.first.barRods.single.backDrawRodData.show,
        isTrue,
      );
    }
    expect(
      activityCharts.last.data.titlesData.leftTitles.sideTitles.showTitles,
      isFalse,
    );
    expect(activityCharts.last.data.gridData.show, isFalse);
    expect(
      activityCharts.last.data.titlesData.leftTitles.sideTitles.reservedSize,
      0,
    );
    expect(find.byType(Card), findsNWidgets(3));
    expect(find.text('消耗'), findsOneWidget);
    expect(find.text('步数'), findsOneWidget);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityTimelineChart), findsNothing);
    expect(find.byType(HealthOfficialRangeChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sleep day view keeps the long sleep and later nap', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final longSleep = HealthSleepSummary(
      startedAt: today.subtract(const Duration(hours: 1)),
      endedAt: today.add(const Duration(hours: 7)),
      durationSeconds: 7 * 60 * 60,
      sleepIndex: 1,
    );
    final nap = HealthSleepSummary(
      startedAt: today.add(const Duration(hours: 13)),
      endedAt: today.add(const Duration(hours: 14)),
      durationSeconds: 60 * 60,
      sleepIndex: 2,
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
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: XiaomiHealthDetailPage(
            args: XiaomiHealthDetailArgs(
              metric: XiaomiHealthMetric.sleep,
              data: XiaomiHealthData(sleep: [longSleep, nap]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('长睡眠'), findsOneWidget);
    expect(find.text('小睡'), findsOneWidget);
    expect(find.text('7小时'), findsOneWidget);
    expect(find.text('1小时'), findsOneWidget);
    expect(find.text('睡眠结构'), findsOneWidget);
    expect(find.text('睡眠平均心率'), findsOneWidget);
    expect(find.text('睡眠平均血氧'), findsOneWidget);
    expect(find.text('最新'), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('暂无睡眠数据'), findsOneWidget);
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
          localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets('long sleep shows measured heart rate and oxygen curves', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 25, 23);
    final sleep = HealthSleepSummary(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 7)),
      durationSeconds: 7 * 3600,
      averageHeartRate: 65,
      averageBloodOxygen: 97,
      deepSleepDurationSeconds: 90 * 60,
      lightSleepDurationSeconds: 4 * 60 * 60,
      remSleepDurationSeconds: 90 * 60,
      heartRatePoints: [
        HealthSleepVitalPoint(timestamp: start, value: 62),
        HealthSleepVitalPoint(
          timestamp: start.add(const Duration(hours: 3)),
          value: 68,
        ),
      ],
      bloodOxygenPoints: [
        HealthSleepVitalPoint(
          timestamp: start.add(const Duration(minutes: 30)),
          value: 96,
        ),
        HealthSleepVitalPoint(
          timestamp: start.add(const Duration(hours: 3, minutes: 30)),
          value: 98,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
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

    expect(find.text('睡眠详情'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(find.text('睡眠平均心率'), findsOneWidget);
    expect(find.text('65 bpm'), findsOneWidget);
    expect(find.text('睡眠平均血氧'), findsOneWidget);
    expect(find.text('97%'), findsOneWidget);
  });

  testWidgets('workout history removes overview headings and shows y axes', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 25, 8);
    final workout = HealthWorkoutSummary(
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 30)),
      activityType: 1,
      averagePaceSecondsPerKilometer: 360,
      samples: [
        HealthWorkoutSample(timestamp: start, heartRate: 90, cadence: 80),
        HealthWorkoutSample(
          timestamp: start.add(const Duration(minutes: 20)),
          heartRate: 120,
          cadence: 100,
        ),
      ],
      heartRateZones: [
        for (var zone = 1; zone <= 5; zone++)
          HealthWorkoutHeartRateZone(zone: zone, durationSeconds: zone),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 1400,
            child: XiaomiHealthDetailPage(
              args: XiaomiHealthDetailArgs(
                metric: XiaomiHealthMetric.workout,
                data: XiaomiHealthData(workouts: [workout]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('运动概览'), findsNothing);
    expect(find.text('历史记录'), findsNothing);
    expect(find.text('运动时长'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('105 bpm'), findsAtLeastNWidgets(2));
    expect(find.text('平均配速'), findsOneWidget);
    final periodCalories = tester.getTopLeft(find.text('卡路里').first);
    final periodHeartRate = tester.getTopLeft(find.text('平均心率').first);
    expect(periodHeartRate.dy, closeTo(periodCalories.dy, 1));
    final periodRows = [
      '运动时长',
      '距离',
      '卡路里',
      '平均心率',
    ].map((label) => tester.getTopLeft(find.text(label).first).dy).toList();
    final periodMinimum = periodRows.reduce(
      (left, right) => left < right ? left : right,
    );
    final periodMaximum = periodRows.reduce(
      (left, right) => left > right ? left : right,
    );
    expect(periodMaximum - periodMinimum, lessThanOrEqualTo(1));
    await tester.tap(find.text('户外跑步'));
    await tester.pumpAndSettle();

    expect(find.text('平均配速'), findsAtLeastNWidgets(1));
    expect(find.text('热身'), findsOneWidget);
    expect(find.text('燃脂'), findsOneWidget);
    expect(find.text('有氧'), findsOneWidget);
    expect(find.text('无氧'), findsOneWidget);
    expect(find.text('极限'), findsOneWidget);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(chart.data.titlesData.rightTitles.sideTitles.showTitles, isTrue);
    expect(
      chart.data.titlesData.leftTitles.sideTitles.reservedSize,
      lessThanOrEqualTo(40),
    );
    expect(
      chart.data.titlesData.rightTitles.sideTitles.reservedSize,
      lessThanOrEqualTo(40),
    );
    expect(
      chart.data.gridData.horizontalInterval,
      chart.data.titlesData.leftTitles.sideTitles.interval,
    );
    expect(
      chart.data.lineBarsData.any((bar) => bar.spots.contains(FlSpot.nullSpot)),
      isTrue,
    );
    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList(growable: false);
    expect(
      renderedText.where((value) => RegExp(r'\d+\.\d').hasMatch(value)),
      isEmpty,
    );
  });

  testWidgets('official range chart renders a one-sided day without samples', (
    tester,
  ) async {
    // A daily summary can legitimately carry only a minimum (or only a
    // maximum) with no average. The week view used to force-unwrap the
    // missing average and crash the whole chart.
    final days = [
      HealthDailySummary(date: DateTime(2026, 8, 20), minHeartRate: 52),
      HealthDailySummary(date: DateTime(2026, 8, 21), maxHeartRate: 88),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 320,
            child: HealthOfficialRangeChart(
              metric: XiaomiHealthMetric.heartRate,
              period: HealthChartPeriod.week,
              samples: const [],
              days: days,
              color: Colors.redAccent,
              start: DateTime(2026, 8, 20),
              end: DateTime(2026, 8, 27),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HealthOfficialRangeChart), findsOneWidget);
  });

  testWidgets(
    'heart-rate detail page groups abnormal samples into standard card without bottom sheet',
    (tester) async {
      final date = DateTime(2026, 10, 4);
      final episodeStart = DateTime(2026, 10, 4, 20, 0);
      final episodeEnd = DateTime(2026, 10, 4, 20, 10);
      final abnormalSamples = [
        for (var index = 0; index < 10; index++)
          HealthAbnormalHealthRecord(
            timestamp: episodeStart.add(Duration(minutes: index)),
            kind: HealthAbnormalHealthKind.highHeartRate,
            value: 120 + (index % 2),
            threshold: 100,
            startedAt: episodeStart,
            endedAt: episodeEnd,
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox(
              width: 360,
              height: 1200,
              child: XiaomiHealthDetailPage(
                args: XiaomiHealthDetailArgs(
                  metric: XiaomiHealthMetric.heartRate,
                  data: XiaomiHealthData(
                    daily: [
                      HealthDailySummary(
                        date: date,
                        averageHeartRate: 85,
                        restingHeartRate: 61,
                        minHeartRate: 58,
                        maxHeartRate: 159,
                      ),
                    ],
                    samples: [
                      HealthSample(
                        timestamp: episodeStart,
                        metric: XiaomiHealthMetric.heartRate,
                        value: 105,
                      ),
                    ],
                    abnormalHealthRecords: abnormalSamples,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify day overview block exists
      expect(find.text('平均'), findsOneWidget);
      expect(find.text('静息'), findsOneWidget);

      // Verify abnormal section is grouped into standard card with localized title
      expect(find.text('心率过高'), findsOneWidget);
      expect(find.text('1 次'), findsOneWidget);
      expect(find.text('20:00 – 20:10'), findsOneWidget);
      expect(find.textContaining('120 - 121 bpm'), findsOneWidget);

      // Tap the row to confirm no modal bottom sheet is opened
      final episodeFinder = find.text('20:00 – 20:10');
      await tester.ensureVisible(episodeFinder);
      await tester.pumpAndSettle();
      await tester.tap(episodeFinder);
      await tester.pumpAndSettle();

      // Verify no bottom sheet exists and no workout duration appears
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('运动时长'), findsNothing);
    },
  );

  testWidgets(
    'heart-rate detail page distinguishes multiple abnormal high heart rate episodes in a single day',
    (tester) async {
      final date = DateTime(2026, 10, 4);
      final episode1Start = DateTime(2026, 10, 4, 10, 15);
      final episode1End = DateTime(2026, 10, 4, 10, 25);
      final episode2Start = DateTime(2026, 10, 4, 16, 30);
      final episode2End = DateTime(2026, 10, 4, 16, 40);

      final abnormalSamples = [
        for (var index = 0; index < 5; index++)
          HealthAbnormalHealthRecord(
            timestamp: episode1Start.add(Duration(minutes: index)),
            kind: HealthAbnormalHealthKind.highHeartRate,
            value: 125 + index,
            threshold: 110,
            startedAt: episode1Start,
            endedAt: episode1End,
          ),
        for (var index = 0; index < 5; index++)
          HealthAbnormalHealthRecord(
            timestamp: episode2Start.add(Duration(minutes: index)),
            kind: HealthAbnormalHealthKind.highHeartRate,
            value: 130 + index,
            threshold: 110,
            startedAt: episode2Start,
            endedAt: episode2End,
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox(
              width: 360,
              height: 1200,
              child: XiaomiHealthDetailPage(
                args: XiaomiHealthDetailArgs(
                  metric: XiaomiHealthMetric.heartRate,
                  data: XiaomiHealthData(
                    daily: [
                      HealthDailySummary(
                        date: date,
                        averageHeartRate: 88,
                        restingHeartRate: 63,
                        minHeartRate: 60,
                        maxHeartRate: 145,
                      ),
                    ],
                    abnormalHealthRecords: abnormalSamples,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that 2 distinct episodes are detected and displayed
      expect(find.text('心率过高'), findsOneWidget);
      expect(find.text('2 次'), findsOneWidget);
      expect(find.text('10:15 – 10:25'), findsOneWidget);
      expect(find.text('16:30 – 16:40'), findsOneWidget);
    },
  );
}
