import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_clock.pb.dart'
    as pb_clock;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_common.pb.dart'
    as pb_common;

void main() {
  group('XiaomiAlarm', () {
    test('preserves a once-only alarm received from the device', () {
      final alarm = XiaomiAlarm.fromProto(
        pb_clock.ClockInfo(
          id: 3,
          data: pb_clock.ClockInfo_Data(
            time: pb_common.Time(hour: 8, minuter: 30),
            clockMode: pb_common.ClockMode.CLOCK_ONCE,
            weekDays: 0,
            enable: true,
            label: '起床',
          ),
        ),
      );

      expect(alarm.id, 3);
      expect(alarm.clockMode, pb_common.ClockMode.CLOCK_ONCE.value);
      expect(alarm.weekDays, 0);
      expect(alarm.toProto().data.clockMode, pb_common.ClockMode.CLOCK_ONCE);
    });

    test('encodes a daily alarm with all weekdays', () {
      const alarm = XiaomiAlarm(
        id: 1,
        hour: 9,
        minute: 15,
        clockMode: 1,
        weekDays: 127,
        enabled: true,
        label: '',
      );

      final proto = alarm.toProto();
      expect(proto.id, 1);
      expect(proto.data.clockMode, pb_common.ClockMode.CLOCK_EVERY_DAY);
      expect(proto.data.weekDays, 127);
    });
  });
}
