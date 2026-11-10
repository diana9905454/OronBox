import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_protocol_trace.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_gnss.pb.dart'
    as pb_gnss;

void main() {
  test('decodes WearPacket metadata without feature-specific fields', () {
    final traces = <Map<String, Object?>>[];
    final tracer = XiaomiProtocolTracer(traces.add);
    final bytes = pb.WearPacket(
      type: pb.WearPacket_Type.GNSS,
      id: pb_gnss.Gnss_GnssID.REQUEST_ONLINE.value,
      gnss: pb_gnss.Gnss(data: pb_gnss.Data(source: 'synaptics_rto', days: 0)),
    ).writeToBuffer();

    tracer.emitWearPacket(direction: 'in', bytes: Uint8List.fromList(bytes));

    expect(traces, hasLength(1));
    expect(traces.single['layer'], 'wear_packet');
    expect(traces.single['type'], 'GNSS');
    expect(traces.single['id'], 0);
    expect(traces.single.containsKey('gnss'), isFalse);
    expect(traces.single['hex'], isA<String>());
  });

  test('location packets retain metadata without storing coordinate bytes', () {
    final traces = <Map<String, Object?>>[];
    XiaomiProtocolTracer(traces.add).emitWearPacket(
      direction: 'out',
      bytes: pb.WearPacket(
        type: pb.WearPacket_Type.GNSS,
        id: 2,
        gnss: pb_gnss.Gnss(
          gpsInfo: pb_gnss.GpsInfo(timestamp: 1, latitude: 0, longitude: 0),
        ),
      ).writeToBuffer(),
    );
    expect(traces.single['type'], 'GNSS');
    expect(traces.single['redacted'], isTrue);
    expect(traces.single.containsKey('hex'), isFalse);
  });

  test('records a reusable operation lifecycle', () {
    final traces = <Map<String, Object?>>[];
    final tracer = XiaomiProtocolTracer(traces.add);
    final operation = tracer.beginOperation(
      'screenshot.capture',
      data: {'origin': 'phone'},
    );
    operation.step('request_sent');
    operation.complete(data: {'imageLength': 12});

    expect(traces.map((trace) => trace['stage']), [
      'started',
      'request_sent',
      'completed',
    ]);
    expect(traces.every((trace) => trace['operationId'] == '1'), isTrue);
  });
}
