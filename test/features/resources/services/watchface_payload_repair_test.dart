import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/services/watchface_payload_repair.dart';

void main() {
  group('isZeroVelaWatchfaceId', () {
    test('detects an all-zero id field at 0x28', () {
      expect(isZeroVelaWatchfaceId(List.filled(0x28 + 12, 0)), isTrue);
    });

    test('detects ascii zero characters as a zero id', () {
      expect(
        isZeroVelaWatchfaceId([
          ...List.filled(0x28, 0xAA),
          ...List.filled(12, 0x30),
        ]),
        isTrue,
      );
    });

    test('is false for a real id', () {
      expect(
        isZeroVelaWatchfaceId([...List.filled(0x28, 0xAA), 49, 50, 51]),
        isFalse,
      );
    });

    test('is false for a truncated payload', () {
      expect(isZeroVelaWatchfaceId(List.filled(0x28, 0)), isFalse);
    });
  });

  group('replaceVelaWatchfaceId', () {
    test('refuses to patch a payload shorter than the id field', () {
      expect(
        replaceVelaWatchfaceId(List.filled(0x28, 0), '123456789012'),
        isNull,
      );
    });

    test('writes ascii digits and zero-pads the remainder', () {
      final result = replaceVelaWatchfaceId(List.filled(0x28 + 12, 0), '42')!;
      expect(result.sublist(0x28, 0x28 + 12), [
        0x34,
        0x32,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
    });

    test('keeps the remaining bytes untouched', () {
      final bytes = [
        ...List.generate(0x28, (index) => index % 256),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0xAA,
        0xBB,
        0xCC,
        0xDD,
      ];
      final result = replaceVelaWatchfaceId(bytes, '7')!;
      expect(result.sublist(0, 0x28), bytes.sublist(0, 0x28));
      expect(result.sublist(0x28 + 12), bytes.sublist(0x28 + 12));
    });
  });
}
