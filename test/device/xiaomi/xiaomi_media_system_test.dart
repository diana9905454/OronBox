import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_media.pb.dart'
    as pb_media;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_media.pbenum.dart'
    as pb_media_enum;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/mass_packet.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/spp_v1_packet.dart';
import 'package:oronbox/src/device/xiaomi/systems/media_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';

void main() {
  test(
    'reassembles audio record segments, validates CRC and sends confirm packet',
    () async {
      final transport = _FakeTransport();
      final eventBus = DeviceEventBus();
      final entity = DeviceEntity(
        id: 'test-device',
        kind: 'xiaomi',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      final system = XiaomiMediaSystem();
      entity.set(component);
      entity.registerSystem(system);

      final recordEventFuture = eventBus.stream
          .where((event) => event is XiaomiAudioRecordReceived)
          .cast<XiaomiAudioRecordReceived>()
          .first;

      const recordId = '20241029_1400.opus';
      final idBytes = utf8.encode(recordId);
      final audioRaw = Uint8List.fromList([
        0x4F,
        0x70,
        0x75,
        0x73,
        0x01,
        0x02,
        0x03,
        0x04,
      ]);

      final contentBuilder = BytesBuilder()
        ..addByte(idBytes.length)
        ..add(idBytes)
        ..add(List.filled(5, 0)) // 5 bytes reserved header
        ..add(audioRaw);
      final content = contentBuilder.toBytes();

      final crc = calculateCrc32(Uint8List.fromList(content));
      final packetBody = BytesBuilder()
        ..add(content)
        ..add(_uint32Le(crc));
      final fullPayload = packetBody.toBytes();

      final split = fullPayload.length ~/ 2;
      final part1 = Uint8List.sublistView(fullPayload, 0, split);
      final part2 = Uint8List.sublistView(fullPayload, split);

      // Segment 1 / 2
      system.onLayer2Packet(
        L2Channel.mass,
        L2OpCode.write,
        _audioSegment(total: 2, sequence: 1, data: part1),
      );

      // Segment 2 / 2
      system.onLayer2Packet(
        L2Channel.mass,
        L2OpCode.write,
        _audioSegment(total: 2, sequence: 2, data: part2),
      );

      final event = await recordEventFuture.timeout(const Duration(seconds: 2));
      expect(event.deviceId, 'test-device');
      expect(event.id, recordId);
      expect(event.bytes, audioRaw);

      // Verify ACK confirmation sent
      final codec = XiaomiSppV1Codec();
      final packets = <XiaomiSppV1Packet>[];
      for (final write in transport.writes) {
        packets.addAll(codec.add(write));
      }
      expect(packets, isNotEmpty);
      final lastPacket = packets.last;
      final wearPacket = pb.WearPacket.fromBuffer(lastPacket.payload);
      expect(wearPacket.type, pb.WearPacket_Type.MEDIA);
      expect(
        wearPacket.id,
        pb_media_enum.Media_MediaID.CONFIRM_MEDIA_FILE.value,
      );
      expect(wearPacket.media.mediaFileIdentifier.id, recordId);

      await entity.dispose();
      eventBus.dispose();
    },
  );

  test('rejects audio record with invalid CRC32', () async {
    final transport = _FakeTransport();
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiMediaSystem();
    entity.set(component);
    entity.registerSystem(system);

    var eventFired = false;
    eventBus.stream
        .where((event) => event is XiaomiAudioRecordReceived)
        .listen((_) => eventFired = true);

    const recordId = 'bad_crc.opus';
    final idBytes = utf8.encode(recordId);
    final audioRaw = Uint8List.fromList([1, 2, 3, 4]);

    final contentBuilder = BytesBuilder()
      ..addByte(idBytes.length)
      ..add(idBytes)
      ..add(List.filled(5, 0))
      ..add(audioRaw);
    final content = contentBuilder.toBytes();

    // Wrong CRC32
    final packetBody = BytesBuilder()
      ..add(content)
      ..add(_uint32Le(0xDEADBEEF));
    final fullPayload = packetBody.toBytes();

    system.onLayer2Packet(
      L2Channel.mass,
      L2OpCode.write,
      _audioSegment(total: 1, sequence: 1, data: fullPayload),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(eventFired, isFalse);
    expect(transport.writes, isEmpty);

    await entity.dispose();
    eventBus.dispose();
  });

  test('rejects out-of-order audio record segments', () async {
    final transport = _FakeTransport();
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiMediaSystem();
    entity.set(component);
    entity.registerSystem(system);

    var eventFired = false;
    eventBus.stream
        .where((event) => event is XiaomiAudioRecordReceived)
        .listen((_) => eventFired = true);

    // Send sequence 2 before 1
    system.onLayer2Packet(
      L2Channel.mass,
      L2OpCode.write,
      _audioSegment(total: 2, sequence: 2, data: Uint8List.fromList([1, 2])),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(eventFired, isFalse);

    await entity.dispose();
    eventBus.dispose();
  });

  test(
    'pullAudioRecord requests file and returns assembled audio data',
    () async {
      final transport = _FakeTransport();
      final eventBus = DeviceEventBus();
      final entity = DeviceEntity(
        id: 'test-device',
        kind: 'xiaomi',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      final system = XiaomiMediaSystem();
      entity.set(component);
      entity.registerSystem(system);

      const recordId = '/sdcard/record/meeting.pcm';
      final idBytes = utf8.encode(recordId);
      final audioRaw = Uint8List.fromList([0x10, 0x20, 0x30, 0x40, 0x50]);

      final contentBuilder = BytesBuilder()
        ..addByte(idBytes.length)
        ..add(idBytes)
        ..add(List.filled(5, 0))
        ..add(audioRaw);
      final content = contentBuilder.toBytes();

      final crc = calculateCrc32(Uint8List.fromList(content));
      final fullPayload =
          (BytesBuilder()
                ..add(content)
                ..add(_uint32Le(crc)))
              .toBytes();

      final pullFuture = system.pullAudioRecord(
        pb_media.MediaFile_Identifier(id: recordId, thumbnail: false),
      );

      // Watch returns data
      system.onLayer2Packet(
        L2Channel.mass,
        L2OpCode.write,
        _audioSegment(total: 1, sequence: 1, data: fullPayload),
      );

      final result = await pullFuture.timeout(const Duration(seconds: 2));
      expect(result, audioRaw);

      await entity.dispose();
      eventBus.dispose();
    },
  );

  test('decodes media file descriptor from the production parser', () {
    // Build a protobuf MediaFile payload:
    // tag 1 (length-delimited): MediaFile.Identifier { id: '/record/memo.opus', thumbnail: false }
    // tag 2 (varint): type = OPUS (5)
    // tag 3 (varint): size = 20480
    // tag 4 (varint): createdAt = 1730000000 (seconds -> converted to ms)
    // tag 5 (varint): duration = 45 (seconds)
    final identifierPb = pb_media.MediaFile_Identifier(
      id: '/record/memo.opus',
      thumbnail: false,
    );
    final idBuf = identifierPb.writeToBuffer();

    final builder = BytesBuilder()
      ..add(_fieldBytes(1, idBuf))
      ..add(_fieldVarint(2, pb_media_enum.MediaFile_Type.OPUS.value))
      ..add(_fieldVarint(3, 20480))
      ..add(_fieldVarint(4, 1730000000))
      ..add(_fieldVarint(5, 45));

    final rawList = BytesBuilder()..add(_fieldBytes(1, builder.toBytes()));

    final list = decodeMediaFileListForTesting(rawList.toBytes());
    expect(list, hasLength(1));
    final descriptor = list.first;

    expect(descriptor.identifier?.id, '/record/memo.opus');
    expect(descriptor.name, 'memo.opus'); // basename extracted
    expect(descriptor.mediaType, pb_media_enum.MediaFile_Type.OPUS);
    expect(descriptor.size, 20480);
    expect(descriptor.createdAtMs, 1730000000 * 1000);
    expect(descriptor.durationSecs, 45);
  });

  test('Song protobuf schema validates required album field', () {
    final song = pb_media.Song(
      id: [1, 2, 3],
      name: 'Test Song',
      size: 1024,
      duration: 180,
      album: 'Test Album',
      artist: 'Test Artist',
    );
    final bytes = song.writeToBuffer();
    final parsed = pb_media.Song.fromBuffer(bytes);
    expect(parsed.name, 'Test Song');
    expect(parsed.album, 'Test Album');
    expect(parsed.duration, 180);
  });

  test('handles recordStatus media payload packet without throwing', () async {
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiMediaSystem();
    entity.set(component);
    entity.registerSystem(system);

    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.MEDIA,
      id: pb_media_enum.Media_MediaID.REPORT_RECORD_STATUS.value,
      media: pb_media.Media(recordStatus: pb_media.RecordStatus()),
    );
    system.onLayer2Packet(L2Channel.pb, L2OpCode.write, packet.writeToBuffer());

    await entity.dispose();
  });
}

Uint8List _audioSegment({
  required int total,
  required int sequence,
  required Uint8List data,
}) {
  final header = BytesBuilder()
    ..addByte(0x00) // version
    ..addByte(0x84) // 132 = audioRecord
    ..addByte(total & 0xff)
    ..addByte((total >> 8) & 0xff)
    ..addByte(sequence & 0xff)
    ..addByte((sequence >> 8) & 0xff)
    ..add(data);
  return header.toBytes();
}

List<int> _uint32Le(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

List<int> _fieldVarint(int number, int value) => [
  ..._encodeVarint((number << 3) | 0),
  ..._encodeVarint(value),
];

List<int> _fieldBytes(int number, List<int> value) => [
  ..._encodeVarint((number << 3) | 2),
  ..._encodeVarint(value.length),
  ...value,
];

List<int> _encodeVarint(int value) {
  final bytes = <int>[];
  var remaining = value;
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    bytes.add(byte);
  } while (remaining != 0);
  return bytes;
}

class _FakeTransport implements Transport {
  final writes = <Uint8List>[];

  @override
  String get deviceId => 'test-device';

  @override
  String get deviceName => 'Test Xiaomi';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> dispose() async {}
}
