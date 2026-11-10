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
  data?: Uint8Array;
  connected?: boolean;
  serviceUuid?: string;
  charUuid?: string;
  value?: Uint8Array;
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

interface PendingBleResult {
  result: MethodResult;
  timer: number;
}

export class OhosBleBridge {
  private context: common.UIAbilityContext;
  private scanner: ble.BleScanner | null = null;
  private disposed: boolean = false;
  private gattClients: Map<string, ble.GattClientDevice> = new Map();
  private eventSink: EventSink | null = null;
  private connected: Set<string> = new Set();
  private services: Map<string, Array<ble.GattService>> = new Map();
  private mtus: Map<string, number> = new Map();
  private pendingConnections: Map<string, PendingBleResult> = new Map();
  private pendingMtus: Map<string, PendingBleResult> = new Map();

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
        case 'isScanning':
          result.success(this.scanner != null);
          break;
        case 'isConnected':
          result.success(this.connected.has(call.argument('deviceId') as string));
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
      if (this.disposed) throw new Error('BLE bridge has been destroyed');
      await this.stopScanInternal();
      if (this.disposed) throw new Error('BLE bridge has been destroyed');
      const scanner = ble.createBleScanner();
      this.scanner = scanner;
      scanner.on('BLEDeviceFind', (report: ble.ScanReport) => {
        if (this.scanner !== scanner || this.disposed) return;
        const results: Array<ble.ScanResult> = report.scanResult;
        for (const r of results) {
          const data: ArrayBuffer = r.data instanceof ArrayBuffer ? r.data : new ArrayBuffer(0);
          this.emit({
            type: 'scanResult',
            deviceId: r.deviceId,
            name: r.deviceName ?? '',
            rssi: r.rssi,
            data: new Uint8Array(data),
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
    const scanner = this.scanner;
    if (scanner == null) return;
    await scanner.stopScan();
    scanner.off('BLEDeviceFind');
    if (this.scanner === scanner) this.scanner = null;
  }

  private getOrCreateClient(deviceId: string): ble.GattClientDevice {
    const existing = this.gattClients.get(deviceId);
    if (existing != null) return existing;
    const client = ble.createGattClientDevice(deviceId);
    this.gattClients.set(deviceId, client);
    client.on('BLEConnectionStateChange', (state: ble.BLEConnectionChangeState) => {
      if (this.gattClients.get(deviceId) !== client) return;
      // Connecting/disconnecting are intermediate states, not link loss.
      if (state.state !== 0 && state.state !== 2) return;
      const connected = state.state === 2;
      if (connected) this.connected.add(deviceId);
      this.emit({ type: 'connectionState', deviceId: deviceId, connected: connected });
      if (connected) {
        const pending = this.pendingConnections.get(deviceId);
        if (pending != null) {
          this.pendingConnections.delete(deviceId);
          clearTimeout(pending.timer);
          pending.result.success(true);
        }
      } else {
        this.releaseClient(deviceId);
      }
    });
    client.on('BLECharacteristicChange', (characteristic: ble.BLECharacteristic) => {
      if (this.gattClients.get(deviceId) !== client) return;
      this.emit({
        type: 'characteristicChanged', deviceId: deviceId,
        serviceUuid: characteristic.serviceUuid,
        charUuid: characteristic.characteristicUuid,
        value: new Uint8Array(characteristic.characteristicValue),
      });
    });
    client.on('BLEMtuChange', (mtu: number) => {
      if (this.gattClients.get(deviceId) !== client || mtu < 23) return;
      this.mtus.set(deviceId, mtu);
      this.emit({ type: 'mtuChanged', deviceId: deviceId, mtu: mtu });
      const pending = this.pendingMtus.get(deviceId);
      if (pending != null) {
        this.pendingMtus.delete(deviceId);
        clearTimeout(pending.timer);
        pending.result.success(mtu);
      }
    });
    return client;
  }

  private requireClient(deviceId: string): ble.GattClientDevice {
    const client = this.gattClients.get(deviceId);
    if (client == null || !this.connected.has(deviceId)) throw new Error('BLE device is not connected');
    return client;
  }

  private releaseClient(deviceId: string): void {
    const client = this.gattClients.get(deviceId);
    this.gattClients.delete(deviceId);
    this.connected.delete(deviceId);
    this.services.delete(deviceId);
    this.mtus.delete(deviceId);
    for (const pendingMap of [this.pendingConnections, this.pendingMtus]) {
      const pending = pendingMap.get(deviceId);
      if (pending != null) {
        pendingMap.delete(deviceId);
        clearTimeout(pending.timer);
        pending.result.error('disconnected', 'BLE device disconnected', null);
      }
    }
    if (client == null) return;
    try { client.off('BLEConnectionStateChange'); } catch (_) {}
    try { client.off('BLECharacteristicChange'); } catch (_) {}
    try { client.off('BLEMtuChange'); } catch (_) {}
    try { client.disconnect(); } catch (_) {}
    try { client.close(); } catch (_) {}
  }

  dispose(): void {
    this.disposed = true;
    this.eventSink = null;
    this.stopScanInternal().catch((error: Error) => {
      console.warn(TAG + ': scan cleanup failed: ' + error.message);
    });
    for (const deviceId of Array.from(this.gattClients.keys())) this.releaseClient(deviceId);
  }

  private async connect(call: MethodCall, result: MethodResult): Promise<void> {
    const deviceId: string = call.argument('deviceId');
    try {
      await this.stopScanInternal();
      if (this.disposed) throw new Error('BLE bridge has been destroyed');
      if (this.connected.has(deviceId)) { result.success(true); return; }
      if (this.pendingConnections.has(deviceId)) {
        result.error('connect_in_progress', 'BLE connection already pending', null);
        return;
      }
      const client = this.getOrCreateClient(deviceId);
      const timeoutMs: number = call.argument('timeoutMs') ?? 12000;
      const timer = setTimeout(() => {
        if (this.gattClients.get(deviceId) !== client) return;
        this.pendingConnections.delete(deviceId);
        this.releaseClient(deviceId);
        result.error('connect_timeout', 'BLE connection timed out', null);
      }, Math.max(100, timeoutMs - 250));
      this.pendingConnections.set(deviceId, { result: result, timer: timer });
      // Complete the method only when the connection-state event confirms readiness.
      try {
        client.connect();
      } catch (error) {
        this.pendingConnections.delete(deviceId);
        clearTimeout(timer);
        throw error as Error;
      }
    } catch (e) {
      this.releaseClient(deviceId);
      result.error('connect_error', e instanceof Error ? e.message : String(e), null);
    }
  }

  private disconnect(call: MethodCall, result: MethodResult): void {
    const deviceId: string = call.argument('deviceId');
    this.releaseClient(deviceId);
    this.emit({ type: 'connectionState', deviceId: deviceId, connected: false });
    result.success(true);
  }

  private async getServices(deviceId: string, client: ble.GattClientDevice): Promise<Array<ble.GattService>> {
    const cached = this.services.get(deviceId);
    if (cached != null) return cached;
    const services = await client.getServices();
    if (this.gattClients.get(deviceId) !== client) throw new Error('BLE session changed');
    this.services.set(deviceId, services);
    return services;
  }

  private async discoverServices(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.requireClient(deviceId);
      const services: Array<ble.GattService> = await this.getServices(deviceId, client);
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

  private async findCharacteristic(deviceId: string, client: ble.GattClientDevice, serviceUuid: string, charUuid: string): Promise<ble.BLECharacteristic | null> {
    for (const svc of await this.getServices(deviceId, client)) {
      if (svc.serviceUuid.toUpperCase() !== serviceUuid.toUpperCase()) continue;
      for (const ch of svc.characteristics) {
        if (ch.characteristicUuid.toUpperCase() === charUuid.toUpperCase()) return ch;
      }
    }
    return null;
  }

  private async write(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const serviceUuid: string = call.argument('serviceUuid');
      const charUuid: string = call.argument('charUuid');
      const value: Uint8Array = call.argument('value');
      const writeType: number = call.argument('writeType');
      const client = this.requireClient(deviceId);
      const ch = await this.findCharacteristic(deviceId, client, serviceUuid, charUuid);
      if (ch == null) {
        result.error('char_not_found', 'characteristic not found: ' + charUuid, null);
        return;
      }
      const wt: ble.GattWriteType = writeType === 2 ? ble.GattWriteType.WRITE_NO_RESPONSE : ble.GattWriteType.WRITE;
      ch.characteristicValue = value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
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
      const client = this.requireClient(deviceId);
      const ch = await this.findCharacteristic(deviceId, client, serviceUuid, charUuid);
      if (ch == null) {
        result.error('char_not_found', 'characteristic not found: ' + charUuid, null);
        return;
      }
      const read = await client.readCharacteristicValue(ch);
      result.success(new Uint8Array(read.characteristicValue));
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
      const client = this.requireClient(deviceId);
      const ch = await this.findCharacteristic(deviceId, client, serviceUuid, charUuid);
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
    const deviceId: string = call.argument('deviceId');
    try {
      const mtu: number = call.argument('mtu');
      const client = this.requireClient(deviceId);
      if (this.pendingMtus.has(deviceId)) {
        result.error('mtu_in_progress', 'MTU negotiation already pending', null);
        return;
      }
      const timer = setTimeout(() => {
        this.pendingMtus.delete(deviceId);
        result.success(this.mtus.get(deviceId) ?? 23);
      }, 3500);
      this.pendingMtus.set(deviceId, { result: result, timer: timer });
      try {
        client.setBLEMtuSize(mtu);
      } catch (error) {
        this.pendingMtus.delete(deviceId);
        clearTimeout(timer);
        throw error as Error;
      }
    } catch (e) {
      result.error('mtu_error', e instanceof Error ? e.message : String(e), null);
    }
  }

  private async getRssi(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const deviceId: string = call.argument('deviceId');
      const client = this.requireClient(deviceId);
      const rssi = await client.getRssiValue();
      result.success(rssi);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('rssi_error', msg, null);
    }
  }
}
