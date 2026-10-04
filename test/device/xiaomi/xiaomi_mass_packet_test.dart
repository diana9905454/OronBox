import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/systems/mass_system.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/mass_packet.dart';
import 'package:oronbox/src/device/xiaomi/protocol/transport/mass_transfer.dart';

void main() {
  test('writes the remaining length when resuming a MASS transfer', () {
    final file = Uint8List.fromList(List<int>.generate(17, (index) => index));
    final packet = MassPacket.build(file, MassDataType.gnssAgpsOnline);

    final encoded = packet.encodeWithCrc32(sentLength: 5);

    expect(encoded[0], 0);
    expect(encoded[1], MassDataType.gnssAgpsOnline.value);
    expect(_readUint32Le(encoded, 18), file.length - 5);
    expect(encoded.sublist(22, encoded.length - 4), file.sublist(5));
    expect(
      _readUint32Le(encoded, encoded.length - 4),
      _crc32(encoded.sublist(0, encoded.length - 4)),
    );
  });

  test('serializes different MASS jobs and coalesces duplicate data', () async {
    final releaseFirst = Completer<void>();
    final started = <MassDataType>[];
    final progressCalls = <int>[];
    final queue = XiaomiMassSendQueue(
      execute:
          ({
            required fileData,
            required dataType,
            expectedSliceLength,
            onProgress,
          }) async {
            started.add(dataType);
            if (dataType == MassDataType.watchface) {
              await releaseFirst.future;
            }
            onProgress?.call(
              SendMassCallbackData(
                progress: 1,
                totalParts: 1,
                currentPartNum: 1,
                actualDataPayloadLen: fileData.length,
              ),
            );
          },
    );

    final first = queue.enqueue(
      fileData: Uint8List.fromList([1, 2, 3]),
      dataType: MassDataType.watchface,
      onProgress: (_) => progressCalls.add(1),
    );
    final duplicate = queue.enqueue(
      fileData: Uint8List.fromList([1, 2, 3]),
      dataType: MassDataType.watchface,
      onProgress: (_) => progressCalls.add(2),
    );
    final second = queue.enqueue(
      fileData: Uint8List.fromList([4, 5, 6]),
      dataType: MassDataType.gnssAgpsOnline,
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, [MassDataType.watchface]);
    releaseFirst.complete();
    await Future.wait([first, duplicate, second]);

    expect(started, [MassDataType.watchface, MassDataType.gnssAgpsOnline]);
    expect(progressCalls, containsAll(<int>[1, 2]));
  });

  test(
    'does not coalesce equal bytes with different transfer contracts',
    () async {
      final releaseFirst = Completer<void>();
      final started = <MassDataType>[];
      final queue = XiaomiMassSendQueue(
        execute:
            ({
              required fileData,
              required dataType,
              expectedSliceLength,
              onProgress,
            }) async {
              started.add(dataType);
              if (started.length == 1) await releaseFirst.future;
            },
      );

      final first = queue.enqueue(
        fileData: Uint8List.fromList([1, 2, 3]),
        dataType: MassDataType.watchface,
        expectedSliceLength: 1024,
      );
      final second = queue.enqueue(
        fileData: Uint8List.fromList([1, 2, 3]),
        dataType: MassDataType.gnssAgpsOnline,
        expectedSliceLength: 1024,
      );

      await Future<void>.delayed(Duration.zero);
      expect(started, [MassDataType.watchface]);
      releaseFirst.complete();
      await Future.wait([first, second]);
      expect(started, [MassDataType.watchface, MassDataType.gnssAgpsOnline]);
    },
  );

  test('aborting the queue completes active and pending callers', () async {
    final releaseFirst = Completer<void>();
    final queue = XiaomiMassSendQueue(
      execute:
          ({
            required fileData,
            required dataType,
            expectedSliceLength,
            onProgress,
          }) => releaseFirst.future,
    );
    final first = queue.enqueue(
      fileData: Uint8List.fromList([1]),
      dataType: MassDataType.watchface,
    );
    final second = queue.enqueue(
      fileData: Uint8List.fromList([2]),
      dataType: MassDataType.watchface,
    );

    await Future<void>.delayed(Duration.zero);
    final firstError = expectLater(first, throwsA(isA<StateError>()));
    final secondError = expectLater(second, throwsA(isA<StateError>()));
    queue.abortPending(StateError('link lost'));
    releaseFirst.complete();

    await Future.wait([firstError, secondError]);
  });
}

int _readUint32Le(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
