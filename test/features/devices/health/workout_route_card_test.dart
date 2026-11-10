import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_workout_page.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  testWidgets('WorkoutRouteCard renders nothing when route has less than 2 points',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        WorkoutRouteCard(
          route: [
            HealthWorkoutRoutePoint(
              timestamp: DateTime(2026, 10, 1, 10, 0),
              latitude: 31.2304,
              longitude: 121.4737,
            ),
          ],
          color: Colors.blue,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('起'), findsNothing);
    expect(find.text('终'), findsNothing);
  });

  testWidgets('WorkoutRouteCard renders FlutterMap with route and markers',
      (tester) async {
    final route = [
      HealthWorkoutRoutePoint(
        timestamp: DateTime(2026, 10, 1, 10, 0),
        latitude: 31.2304,
        longitude: 121.4737,
      ),
      HealthWorkoutRoutePoint(
        timestamp: DateTime(2026, 10, 1, 10, 5),
        latitude: 31.2320,
        longitude: 121.4750,
      ),
      HealthWorkoutRoutePoint(
        timestamp: DateTime(2026, 10, 1, 10, 10),
        latitude: 31.2340,
        longitude: 121.4780,
      ),
    ];

    await tester.pumpWidget(
      buildTestWidget(
        WorkoutRouteCard(
          route: route,
          color: Colors.deepOrange,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(find.text('起'), findsOneWidget);
    expect(find.text('终'), findsOneWidget);
  });

  testWidgets('WorkoutRouteCard toggles between street map and vector route',
      (tester) async {
    final route = [
      HealthWorkoutRoutePoint(
        timestamp: DateTime(2026, 10, 1, 10, 0),
        latitude: 39.9042,
        longitude: 116.4074,
      ),
      HealthWorkoutRoutePoint(
        timestamp: DateTime(2026, 10, 1, 10, 15),
        latitude: 39.9142,
        longitude: 116.4174,
      ),
    ];

    await tester.pumpWidget(
      buildTestWidget(
        WorkoutRouteCard(
          route: route,
          color: Colors.green,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);

    // Tap toggle button to switch to vector preview
    final toggleBtn = find.byIcon(Icons.map_outlined);
    expect(toggleBtn, findsOneWidget);
    await tester.tap(toggleBtn);
    await tester.pump();

    // Map should be replaced by CustomPaint
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byIcon(Icons.gesture_outlined), findsOneWidget);

    // Tap toggle button again to switch back to map
    await tester.tap(find.byIcon(Icons.gesture_outlined));
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
