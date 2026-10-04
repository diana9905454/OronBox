import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/device/xiaomi/utils/auth_utils.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/spp_v1_packet.dart';

void main() {
  test('routes Vela generations to the correct SPP protocol', () {
    expect(
      normalizeXiaomiWearableIdentity('Xiaomi Watch S1 Pro A1B2')?.codename,
      'l61',
    );
    expect(
      xiaomiWearableIdentities['m67']?.protocol,
      XiaomiWearableProtocol.sppV1,
    );
    expect(
      xiaomiWearableIdentities['n65']?.protocol,
      XiaomiWearableProtocol.sppV1,
    );
    expect(
      xiaomiWearableIdentities['l61']?.protocol,
      XiaomiWearableProtocol.sppV1,
    );
    for (final codename in ['n66', 'n67', 'o66', 'n62', 'o62', 'o65']) {
      expect(
        xiaomiWearableIdentities[codename]?.protocol,
        XiaomiWearableProtocol.sppV2,
        reason: codename,
      );
    }
  });

  test('encodes the Xiaomi SPP v1 version request', () {
    expect(
      XiaomiSppV1Codec().versionRequest(),
      Uint8List.fromList([
        0xba,
        0xdc,
        0xfe,
        0x00,
        0xc0,
        0x03,
        0x00,
        0x00,
        0x00,
        0x00,
        0xef,
      ]),
    );
  });

  test('buffers fragmented SPP v1 protobuf frames', () {
    final sender = XiaomiSppV1Codec();
    final receiver = XiaomiSppV1Codec();
    final encoded = sender.encodeProtobuf(
      Uint8List.fromList([1, 2, 3, 4]),
      authenticate: true,
    );

    expect(receiver.add(Uint8List.sublistView(encoded, 0, 6)), isEmpty);
    final packets = receiver.add(Uint8List.sublistView(encoded, 6));

    expect(packets, hasLength(1));
    expect(packets.single.channel, XiaomiSppV1Channel.protobuf);
    expect(packets.single.dataType, XiaomiSppV1Packet.auth);
    expect(packets.single.payload, [1, 2, 3, 4]);
  });

  test('encrypts and decrypts SPP v1 protobuf frames', () {
    final key = Uint8List.fromList(List<int>.generate(16, (index) => index));
    final nonce = Uint8List.fromList([1, 2, 3, 4]);
    final keys = XiaomiAuthKeys(
      encKey: key,
      decKey: key,
      encNonce: nonce,
      decNonce: nonce,
    );
    final sender = XiaomiSppV1Codec()..authKeys = keys;
    final encoded = sender.encodeProtobuf(
      Uint8List.fromList([9, 8, 7]),
      authenticate: false,
    );

    expect(encoded[9], XiaomiSppV1Packet.encrypted);
    expect(encoded[10], 1);
  });
}
