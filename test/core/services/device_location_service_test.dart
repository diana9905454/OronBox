import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/device_location_service.dart';

void main() {
  test('returns null immediately when isSupported is false (desktop/web platforms)', () async {
    final service = DeviceLocationService(isSupportedOverride: false);
    expect(service.isSupported, isFalse);

    final result = await service.getGpsInfo();
    expect(result, isNull);
  });
}
