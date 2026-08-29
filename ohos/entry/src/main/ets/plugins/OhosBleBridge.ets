import { FlutterEngine, MethodChannel, MethodCall, MethodResult, EventChannel, StreamHandler, EventSink, BinaryMessenger } from '@ohos/flutter_ohos';
import ble from '@ohos.bluetooth.ble';
import bluetoothManager from '@ohos.bluetoothManager';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';

/**
 * OronBox 鸿蒙 BLE 桥接层。
 *
 * OronBox 依赖 universal_ble 插件做蓝牙，而该插件没有鸿蒙实现。
 * 本文件用鸿蒙原生 @ohos.bluetooth.ble API 实现 BLE 能力，
 * 通过 MethodChannel（Dart→鸿蒙）和 EventChannel（鸿蒙→Dart）与 Dart 侧适配层通信。
 *
 * MethodChannel "oronbox/ble" 方法：isAvailable / requestPermissions / startScan /
 *   stopScan / connect / disconnect / discoverServices / write / read / setNotify /
 *   requestMtu / getRssi
 *
 * EventChannel "oronbox/ble_events" 事件（Map）：
 *   {type, ...} 其中 type ∈ scanResult / connectionState / characteristicChanged / mtuChanged
 */

const TAG = 'OronBoxBleBridge';
const BLE_CHANNEL = 'oronbox/ble';
const BLE_EVENT_CHANNEL = 'oronbox/ble_events';

/** 需要动态申请的权限。 */
const BLE_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH',
  'ohos.permission.LOCATION',
  'ohos.permission.APPROXIMATELY_LOCATION',
];

/** 事件推送用的统一结构。 */
interface BleEvent {
  type: string;
  deviceId?: string;
  name?: string;
  rssi?: number;
  data?: ArrayBuffer;
  connected?: boolean;
  serviceUuid?: string;
  charUuid?: string;
  value?: ArrayBuffer;
  mtu?: number;
}

/** 服务发现返回的特征值结构。 */
interface CharInfo {
  uuid: string;
  properties: Array<string>;
}

/** 服务发现返回的服务结构。 */
interface ServiceInfo {
  uuid: string;
  isPrimary: boolean;
  characteristics: Array<CharInfo>;
}

export class OhosBleBridge {
  private context: common.UIAbilityContext;
  private scanner: ble.BleScanner | null = null;
  private gattClients: Map<string, ble.GattClientDevice> = new Map();
  private eventSink: EventSink | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerEventChannel(messenger);
    this.registerMethodChannel(messenger);
  }

  // ---------------------------------------------------------------------------
  // EventChannel：鸿蒙 → Dart
  // ---------------------------------------------------------------------------
  private registerEventChannel(messenger: BinaryMessenger): void {
    const channel = new EventChannel(messenger, BLE_EVENT_CHANNEL);
    const handler: StreamHandler = {
      onListen: (args: Object | null, events: EventSink): void => {
        this.eventSink = events;
      },
      onCancel: (args: Object | null): void => {
        this.eventSink = null;
      }
    };
    channel.setStreamHandler(handler);
  }

  private emit(event: BleEvent): void {
    const sink = this.eventSink;
    if (sink == null) return;
    try {
      sink.success(event);
    } catch (e) {
      console.error(TAG + ': emit failed: ' + JSON.stringify(e));
    }
  }

  // ---------------------------------------------------------------------------
  // MethodChannel：Dart → 鸿蒙
  // ---------------------------------------------------------------------------
  private registerMethodChannel(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, BLE_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handleMethod(call, result);
      }
    });
  }

  private handleMethod(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'isAvailable':
          this.isAvailable(result);
          break;
        case 'requestPermissions':
          this.requestPermissions(result);
          break;
        case 'startScan':
          this.startScan(call, result);
          break;
        case 'stopScan':
          this.stopScan(result);
          break;
        case 'connect':
          this.connect(call, result);
          break;
        case 'disconnect':
          this.disconnect(call, result);
          break;
        case 'discoverServices':
          this.discoverServices(call, result);
          break;
        case 'write':
          this.write(call, result);
          break;
        case 'read':
          this.read(call, result);
          break;
        case 'setNotify':
          this.setNotify(call, result);
          break;
        case 'requestMtu':
          this.requestMtu(call, result);
          break;
        case 'getRssi':
          this.getRssi(call, result);
          break;
        default:
          result.notImplemented();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('ble_error', msg, null);
    }
  }

  // ---------------------------------------------------------------------------
  private isAvailable(result: MethodResult): void {
    const state = bluetoothManager.getState();
    // STATE_ON = 2, STATE_BLE_ON = 5
    result.success(state === 2 || state === 5);
  }

  private async requestPermissions(result: MethodResult): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(this.context, BLE_PERMISSIONS);
      let granted = true;
      for (let i = 0; i < res.authResults.length; i++) {
        if (res.authResults[i] !== 0) {
          granted = false;
          break;
        }
      }
      result.success(granted);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('permission_error', msg, null);
    }
  }

  private async startScan(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.stopScanInternal();
      const scanner = ble.createBleScanner();
      this.scanner = scanner;
      scanner.on('BLEDeviceFind', (report: ble.ScanReport) => {
        const results: Array<ble.ScanResult> = report.scanResult;
        for (const r of results) {
          const data: ArrayBuffer = r.data instanceof ArrayBuffer ? r.data : new ArrayBuffer(0);
          this.emit({
            type: 'scanResult',
            deviceId: r.deviceId,
            name: r.deviceName ?? '',
            rssi: r.rssi,
            data: data,
          });
        }
      });
      const filters: Array<ble.ScanFilter> = [];
      const servicesArg: Object | null = call.argument('services');
      if (servicesArg != null) {
        const services = servicesArg as Array<string>;
        for (const s of services) {
          const f: ble.ScanFilter = { serviceUuid: s };
          filters.push(f);
        }
      }
      // 鸿蒙 startScan 要求 filters 至少有一个元素（空数组会报 401）。
      // 无 service 过滤时传一个空 filter 表示匹配所有设备。
      if (filters.length === 0) {
        const emptyFilter: ble.ScanFilter = {};
        filters.push(emptyFilter);
      }
      await scanner.startScan(filters);
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('scan_error', msg, null);
    }
  }

  private async stopScan(result: MethodResult): Promise<void> {
    try {
      await this.stopScanInternal();
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('scan_error', msg, null);
    }
  }

  private async stopScanInternal(): Promise<void> {
    if (this.scanner != null) {
      const scanner = this.scanner;
      this.scanner = null;
      try {
        scanner.off('BLEDeviceFind');
        await scanner.stopScan();
      } catch (e) {
        console.error(TAG + ': stopScanInternal failed: ' + JSON.stringify(e));
      }
    }
  }

  private getOrCreateClient(deviceId: string): ble.GattClientDevice {
    let client = this.gattClients.get(deviceId);
    if (client == null) {
      client = ble.createGattClientDevice(deviceId);
      client.on('BLEConnectionStateChange', (state: ble.BLEConnectionChangeState) => {
        const connected = state.state === 2; // STATE_CONNECTED
        const ev: BleEvent = { type: 'connectionState', deviceId: deviceId, connected: connected };
        this.emit(ev);
      });
      client.on('BLECharacteristicChange', (characteristic: ble.BLECharacteristic) => {
        const ev: BleEvent = {
          type: 'characteristicChanged',
          deviceId: deviceId,
          serviceUuid: characteristic.serviceUuid,
          charUuid: characteristic.characteristicUuid,
          value: characteristic.characteristicValue,
        };
        this.emit(ev);
      });
      client.on('BLEMtuChange', (mtu: number) => {
        const ev: BleEvent = { type: 'mtuChanged', deviceId: deviceId, mtu: mtu };
        this.emit(ev);
      });
      this.gattClients.set(deviceId, client);
    }
    return client;
  }

  private connect(call: MethodCall, result: MethodResult): void {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.getOrCreateClient(deviceId);
      client.connect();
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('connect_error', msg, null);
    }
  }

  private disconnect(call: MethodCall, result: MethodResult): void {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.gattClients.get(deviceId);
      if (client != null) {
        client.disconnect();
      }
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('disconnect_error', msg, null);
    }
  }

  private async discoverServices(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.getOrCreateClient(deviceId);
      const services: Array<ble.GattService> = await client.getServices();
      const resultList: Array<ServiceInfo> = [];
      for (const svc of services) {
        const chars: Array<CharInfo> = [];
        for (const ch of svc.characteristics) {
          const props = ch.properties;
          const properties: Array<string> = [];
          if (props != null) {
            if (props.read) properties.push('read');
            if (props.write) properties.push('write');
            if (props.writeNoResponse) properties.push('writeWithoutResponse');
            if (props.notify) properties.push('notify');
            if (props.indicate) properties.push('indicate');
          }
          const ci: CharInfo = { uuid: ch.characteristicUuid, properties: properties };
          chars.push(ci);
        }
        const si: ServiceInfo = { uuid: svc.serviceUuid, isPrimary: svc.isPrimary, characteristics: chars };
        resultList.push(si);
      }
      result.success(resultList);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('discover_error', msg, null);
    }
  }

  private findCharacteristic(client: ble.GattClientDevice, serviceUuid: string, charUuid: string): Promise<ble.BLECharacteristic | null> {
    return new Promise<ble.BLECharacteristic | null>((resolve, reject) => {
      client.getServices().then((services: Array<ble.GattService>) => {
        for (const svc of services) {
          if (svc.serviceUuid.toUpperCase() !== serviceUuid.toUpperCase()) continue;
          for (const ch of svc.characteristics) {
            if (ch.characteristicUuid.toUpperCase() === charUuid.toUpperCase()) {
              resolve(ch);
              return;
            }
          }
        }
        resolve(null);
      }).catch((e: Error) => reject(e));
    });
  }

  private async write(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const serviceUuid: string = call.argument('serviceUuid');
      const charUuid: string = call.argument('charUuid');
      const value: ArrayBuffer = call.argument('value');
      const writeType: number = call.argument('writeType');
      const client = this.getOrCreateClient(deviceId);
      const ch = await this.findCharacteristic(client, serviceUuid, charUuid);
      if (ch == null) {
        result.error('char_not_found', 'characteristic not found: ' + charUuid, null);
        return;
      }
      const wt: ble.GattWriteType = writeType === 2 ? ble.GattWriteType.WRITE_NO_RESPONSE : ble.GattWriteType.WRITE;
      ch.characteristicValue = value;
      await client.writeCharacteristicValue(ch, wt);
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('write_error', msg, null);
    }
  }

  private async read(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const serviceUuid: string = call.argument('serviceUuid');
      const charUuid: string = call.argument('charUuid');
      const client = this.getOrCreateClient(deviceId);
      const ch = await this.findCharacteristic(client, serviceUuid, charUuid);
      if (ch == null) {
        result.error('char_not_found', 'characteristic not found: ' + charUuid, null);
        return;
      }
      const read = await client.readCharacteristicValue(ch);
      result.success(read.characteristicValue);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('read_error', msg, null);
    }
  }

  private async setNotify(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const serviceUuid: string = call.argument('serviceUuid');
      const charUuid: string = call.argument('charUuid');
      const enable: boolean = call.argument('enable');
      const client = this.getOrCreateClient(deviceId);
      const ch = await this.findCharacteristic(client, serviceUuid, charUuid);
      if (ch == null) {
        result.error('char_not_found', 'characteristic not found: ' + charUuid, null);
        return;
      }
      await client.setCharacteristicChangeNotification(ch, enable);
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('notify_error', msg, null);
    }
  }

  private requestMtu(call: MethodCall, result: MethodResult): void {
    try {
      const deviceId: string = call.argument('deviceId');
      const mtu: number = call.argument('mtu');
      const client = this.getOrCreateClient(deviceId);
      client.setBLEMtuSize(mtu);
      result.success(mtu);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('mtu_error', msg, null);
    }
  }

  private async getRssi(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.getOrCreateClient(deviceId);
      const rssi = await client.getRssiValue();
      result.success(rssi);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('rssi_error', msg, null);
    }
  }
}
