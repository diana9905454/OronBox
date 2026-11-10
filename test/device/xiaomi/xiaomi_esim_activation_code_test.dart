import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/esim/esim_activation_code.dart';
import 'package:oronbox/src/device/xiaomi/systems/lpa_system.dart';

void main() {
  test('normalizes activation QR prefix and retains retry flag', () {
    final code = XiaomiEsimActivationCode.parse(
      r' lpa:1$carrier.example$matching-id$$1 ',
    );
    expect(code!.value, r'1$carrier.example$matching-id$$1');
    expect(code.retryDownload, isTrue);
  });
  test(
    'rejects incomplete activation codes before any device operation',
    () async {
      for (final raw in [
        '',
        r'1$$token',
        r'1$carrier$',
        r'2$carrier$token',
        'https://example.com',
      ]) {
        expect(XiaomiEsimActivationCode.parse(raw), isNull);
        await expectLater(
          XiaomiLpaSystem().downloadProfile(raw),
          throwsFormatException,
        );
      }
    },
  );
}
