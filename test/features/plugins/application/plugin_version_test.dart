import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/plugins/application/plugin_repository.dart';

void main() {
  group('comparePluginVersions', () {
    test('compares semantic version components numerically', () {
      expect(comparePluginVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(comparePluginVersions('v2.0', '1.99.99'), greaterThan(0));
      expect(comparePluginVersions('1.0', '1.0.0'), 0);
    });

    test('orders prereleases before stable releases', () {
      expect(
        comparePluginVersions('1.0.0-beta.2', '1.0.0-beta.1'),
        greaterThan(0),
      );
      expect(comparePluginVersions('1.0.0', '1.0.0-rc.1'), greaterThan(0));
    });
  });
}
