import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;

class XiaomiRequestPoolSystem extends XiaomiPbSystem {
  @override
  void onWearPacket(pb.WearPacket packet) {
    component.requestPool.onPacket(packet);
  }
}
