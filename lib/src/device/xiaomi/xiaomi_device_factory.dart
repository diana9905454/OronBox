import 'package:oronbox/src/core/services/device_location_service.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/runtime.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/auth_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/info_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/gnss_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/install_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/mass_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/media_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/network_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/report_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/request_pool_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/resource_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/sync_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/thirdparty_app_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/watchface_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/wifi_config_handler.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/systems/screenshot_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_dispatcher.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_protocol_trace.dart';

class XiaomiDeviceFactory implements DeviceEntityFactory {
  @override
  DeviceEntity create({
    required String id,
    required String kind,
    required Transport transport,
    required DeviceEventBus eventBus,
  }) {
    final entity = DeviceEntity(
      id: id,
      kind: kind,
      transport: transport,
      eventBus: eventBus,
    );

    final component = XiaomiDeviceComponent(
      transport: transport,
      sppV1: kind == 'xiaomi-spp-v1',
    );
    component.onTransportFailure = (error, stackTrace) {
      entity.system<XiaomiMassSystem>()?.abortPending(error, stackTrace);
      entity.system<XiaomiScreenshotSystem>()?.abortPending(error, stackTrace);
      entity.emit(DeviceError(deviceId: id, error: error.toString()));
      entity.emit(TransportDisconnected(deviceId: id));
    };
    component.onRawOutgoing = entity.recordRawOutgoing;
    final tracer = XiaomiProtocolTracer((trace) {
      entity.emit(
        XiaomiProtocolTrace(deviceId: id, trace: Map.unmodifiable(trace)),
      );
    });
    component.protocolTracer = tracer;
    entity.set(component);

    final dispatcher = XiaomiDispatcher(component, tracer: tracer);
    component.onL2Payload = dispatcher.onL2Payload;
    entity.setDispatcher(dispatcher);

    entity.registerSystem(XiaomiRequestPoolSystem());
    entity.registerSystem(XiaomiAuthSystem());

    entity.registerSystem(XiaomiMassSystem());
    final locationService = DeviceLocationService();
    entity.registerSystem(
      XiaomiGnssSystem(
        gpsInfoProvider: locationService.getGpsInfo,
      ),
    );
    entity.registerSystem(XiaomiScreenshotSystem());
    entity.registerSystem(XiaomiMediaSystem());
    entity.registerSystem(XiaomiNetworkSystem());
    entity.registerSystem(XiaomiWifiConfigHandler());

    entity.registerSystem(XiaomiInstallSystem());
    entity.registerSystem(XiaomiInfoSystem());
    final healthSystem = XiaomiHealthSystem();
    entity.registerSystem(healthSystem);
    component.onActivityPayload = healthSystem.onActivityPayload;
    entity.registerSystem(XiaomiSyncSystem());
    entity.registerSystem(XiaomiResourceSystem());
    entity.registerSystem(XiaomiWatchfaceSystem());
    entity.registerSystem(XiaomiThirdpartyAppSystem());
    entity.registerSystem(XiaomiReportSystem());

    return entity;
  }
}
