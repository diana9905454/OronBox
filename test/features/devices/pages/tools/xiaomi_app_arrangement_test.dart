import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/bt_models.dart';

void main() {
  group('XiaomiAppArrangement app reordering behaviors', () {
    test('reorders apps correctly when moved from top to middle', () {
      final initial = [
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
        const AppInfo(packageName: 'com.mi.heartrate', appName: 'Heart Rate'),
        const AppInfo(packageName: 'com.mi.weather', appName: 'Weather'),
      ];

      final next = [...initial];
      final moved = next.removeAt(0);
      next.insert(1, moved);

      expect(next.map((a) => a.packageName).toList(), [
        'com.mi.heartrate',
        'com.mi.workout',
        'com.mi.weather',
      ]);
    });

    test('reorders apps correctly when moved from bottom to top', () {
      final initial = [
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
        const AppInfo(packageName: 'com.mi.heartrate', appName: 'Heart Rate'),
        const AppInfo(packageName: 'com.mi.weather', appName: 'Weather'),
      ];

      final next = [...initial];
      final moved = next.removeAt(2);
      next.insert(0, moved);

      expect(next.map((a) => a.packageName).toList(), [
        'com.mi.weather',
        'com.mi.workout',
        'com.mi.heartrate',
      ]);
    });

    test('detects dirty state when order changes', () {
      final saved = [
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
        const AppInfo(packageName: 'com.mi.heartrate', appName: 'Heart Rate'),
      ];
      final current = [
        const AppInfo(packageName: 'com.mi.heartrate', appName: 'Heart Rate'),
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
      ];

      var dirty = false;
      if (current.length != saved.length) {
        dirty = true;
      } else {
        for (var i = 0; i < current.length; i++) {
          if (current[i].packageName != saved[i].packageName) {
            dirty = true;
            break;
          }
        }
      }

      expect(dirty, isTrue);
    });

    test('hides non-persist app and marks dirty', () {
      final saved = [
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
        const AppInfo(packageName: 'com.mi.weather', appName: 'Weather'),
      ];
      final current = saved
          .map((app) => app.packageName == 'com.mi.weather'
              ? app.copyWith(hidden: true)
              : app)
          .toList();

      expect(current.where((a) => !a.hidden).map((a) => a.packageName).toList(), [
        'com.mi.workout',
      ]);
      expect(current.where((a) => a.hidden).map((a) => a.packageName).toList(), [
        'com.mi.weather',
      ]);

      var dirty = false;
      for (var i = 0; i < current.length; i++) {
        if (current[i].packageName != saved[i].packageName ||
            current[i].hidden != saved[i].hidden) {
          dirty = true;
          break;
        }
      }
      expect(dirty, isTrue);
    });

    test('unhides app moves it back to visible list', () {
      final initial = [
        const AppInfo(packageName: 'com.mi.workout', appName: 'Workout'),
        const AppInfo(packageName: 'com.mi.weather', appName: 'Weather', hidden: true),
      ];

      final visible = initial.where((a) => !a.hidden).toList();
      final hidden = initial.where((a) => a.hidden).toList();
      final target = hidden.first;
      hidden.removeWhere((a) => a.packageName == target.packageName);
      visible.add(target.copyWith(hidden: false));
      final next = [...visible, ...hidden];

      expect(next.where((a) => !a.hidden).map((a) => a.packageName).toList(), [
        'com.mi.workout',
        'com.mi.weather',
      ]);
      expect(next.where((a) => a.hidden).isEmpty, isTrue);
    });
  });
}
