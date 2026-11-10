import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/services/device_share_link.dart';

void main() {
  const parameters =
      'source=deviceQr&name=Xiaomi%20Watch%20S5&mac=aabbccddeeff&authkey=0123456789abcdef0123456789abcdef';
  test('recognizes the shared parameter contract independently of the URL', () {
    for (final prefix in [
      'https://astrobox.online/open?',
      'https://oronbox.zxor.org/open?',
      'https://another.example/share?',
      'otherapp://device/import?',
      '?',
      '',
    ]) {
      final device = DeviceShareLink.parse('$prefix$parameters');
      expect(device?.addr, 'AA:BB:CC:DD:EE:FF', reason: prefix);
      expect(device?.name, 'Xiaomi Watch S5');
      expect(device?.authkey, '0123456789abcdef0123456789abcdef');
    }
  });
  test('accepts addr sharing without requiring source or kind', () {
    const fields =
        'name=%E5%B0%8F%E7%B1%B3%E6%89%8B%E7%8E%AF10+NFC%E7%89%88+++&addr=AA%3ABB%3ACC%3ADD%3AEE%3AFF&authkey=0123456789abcdef0123456789abcdef';
    for (final prefix in [
      'https://abox.run/open?source=device&kind=Xiaomi&',
      'https://unrelated.example/anything?',
      '?source=anything&source=ignored&kind=ignored&',
      '',
    ]) {
      final device = DeviceShareLink.parse('$prefix$fields');
      expect(device?.name, '小米手环10 NFC版');
      expect(device?.addr, 'AA:BB:CC:DD:EE:FF');
      expect(device?.authkey, '0123456789abcdef0123456789abcdef');
    }
  });

  test('normalizes colon and hyphen MAC addresses', () {
    for (final mac in ['AA:BB:CC:DD:EE:FF', 'aa-bb-cc-dd-ee-ff']) {
      expect(
        DeviceShareLink.parse('?$parameters'.replaceFirst('aabbccddeeff', mac))
            ?.addr,
        'AA:BB:CC:DD:EE:FF',
      );
    }
  });
  test(
    'rejects ambiguous or malformed credentials and unrelated QR values',
    () {
      for (final value in [
        parameters.replaceFirst('aabbccddeeff', 'not-a-mac'),
        parameters.replaceFirst('0123456789abcdef0123456789abcdef', 'invalid'),
        '$parameters&mac=112233445566',
        'https://example.com/ordinary',
        '?source=deviceQr&name=%&mac=aabbccddeeff',
        parameters.replaceFirst('Xiaomi%20Watch%20S5', '%20'),
      ]) {
        expect(DeviceShareLink.parse(value), isNull);
      }
    },
  );
  test(
    'accepts a device without a shared key and ignores unrelated fields',
    () {
      final device = DeviceShareLink.parse(
        '?source=deviceQr&name=Watch&mac=aabbccddeeff&other=ignored',
      );
      expect(device?.addr, 'AA:BB:CC:DD:EE:FF');
      expect(device?.authkey, isEmpty);
    },
  );
  test(
    'accepts equivalent address aliases and rejects conflicting addresses',
    () {
      expect(
        DeviceShareLink.parse('$parameters&addr=aa-bb-cc-dd-ee-ff')?.addr,
        'AA:BB:CC:DD:EE:FF',
      );
      expect(
        DeviceShareLink.parse('$parameters&addr=11:22:33:44:55:66'),
        isNull,
      );
    },
  );

  test('round-trips a device whose stored endpoint uses hyphens', () {
    const device = MiWearState(
      name: '手表 & Test',
      addr: 'aa-bb-cc-dd-ee-ff',
      connectType: 'spp',
      authkey: '0123456789abcdef0123456789abcdef',
    );
    for (final link in [
      DeviceShareLink.build(device),
      DeviceShareLink.buildDeepLink(device),
      DeviceShareLink.buildAstroBoxCompatible(device),
    ]) {
      expect(link.queryParameters['mac'], 'AABBCCDDEEFF');
      final parsed = DeviceShareLink.parse(link.toString());
      expect(parsed?.name, device.name);
      expect(parsed?.addr, 'AA:BB:CC:DD:EE:FF');
    }
  });
}
