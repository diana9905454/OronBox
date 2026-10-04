import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/commands/xiaomi_request_pool.dart';

void main() {
  test('routes one response to only one matching request', () async {
    final pool = XiaomiRequestPool(sendPacket: (_) async {});
    final request = pb.WearPacket(type: pb.WearPacket_Type.MASS, id: 1);

    Future<int> sendRequest() => pool.request<int>(
      packet: request,
      typeMatcher: (_) => true,
      responseMapper: (packet) => packet.id,
    );

    final first = sendRequest();
    final second = sendRequest();
    await Future<void>.delayed(Duration.zero);

    pool.onPacket(pb.WearPacket(type: pb.WearPacket_Type.MASS, id: 42));

    expect(await first, 42);
    final secondResult = second
        .then<int?>((value) => value)
        .catchError((_) => null);
    expect(
      await secondResult.timeout(
        const Duration(milliseconds: 20),
        onTimeout: () => -1,
      ),
      -1,
    );

    pool.clear();
    await secondResult;
  });

  test('removes a slot when sending the request fails', () async {
    var fail = true;
    final pool = XiaomiRequestPool(
      sendPacket: (_) async {
        if (fail) {
          fail = false;
          throw StateError('send failed');
        }
      },
    );
    final packet = pb.WearPacket(type: pb.WearPacket_Type.MASS, id: 1);

    await expectLater(
      pool.request<int>(
        packet: packet,
        typeMatcher: (_) => true,
        responseMapper: (value) => value.id,
      ),
      throwsA(isA<StateError>()),
    );

    final next = pool.request<int>(
      packet: packet,
      typeMatcher: (_) => true,
      responseMapper: (value) => value.id,
    );
    await Future<void>.delayed(Duration.zero);
    pool.onPacket(pb.WearPacket(type: pb.WearPacket_Type.MASS, id: 42));

    expect(await next, 42);
  });
}
