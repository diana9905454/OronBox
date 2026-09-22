import { FlutterEngine, MethodChannel, MethodCall, MethodResult, EventChannel, StreamHandler, EventSink, BinaryMessenger } from '@ohos/flutter_ohos';
import socket from '@ohos.bluetooth.socket';
import connection from '@ohos.bluetooth.connection';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';

/**
 * OronBox 鸿蒙 classic_spp（经典蓝牙 RFCOMM/SPP 串口）桥接层。
 *
 * OronBox 用 classic_spp 做小米手环的经典蓝牙串口通信（文件传输、大数据下发）。
 * 该 channel 在鸿蒙端无原生实现，本文件用 @ohos.bluetooth.socket + @ohos.bluetooth.connection
 * 实现扫描、连接、读写。
 *
 * MethodChannel "oronbox/classic_spp"：requestPermissions / startScan / stopScan /
 *   connect / send / disconnect
 * EventChannel "oronbox/classic_spp/events"：{event: 'connected'|'disconnected'|'data', data?}
 * EventChannel "oronbox/classic_spp/scan_events"：{addr, name}
 */

const TAG = 'OronBoxClassicSppBridge';

const SPP_METHOD_CHANNEL = 'oronbox/classic_spp';
const SPP_EVENT_CHANNEL = 'oronbox/classic_spp/events';
const SPP_SCAN_EVENT_CHANNEL = 'oronbox/classic_spp/scan_events';

/** 小米手环常见 SPP service UUID（SPP 标准 UUID）。 */
const SPP_UUID = '00001101-0000-1000-8000-00805f9b34fb';

const SPP_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH',
  'ohos.permission.LOCATION',
];

interface SppEvent {
  event: string;
  data?: Uint8Array;
}

interface SppScanEvent {
  addr: string;
  name: string;
}

export class ClassicSppBridge {
  private context: common.UIAbilityContext;
  private clientSocket: number = -1;
  private eventSink: EventSink | null = null;
  private scanEventSink: EventSink | null = null;
  private discovered: Map<string, string> = new Map();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerMethodChannel(messenger);
    this.registerEventChannel(messenger);
    this.registerScanEventChannel(messenger);
  }

  // ---------------------------------------------------------------------------
  private registerMethodChannel(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, SPP_METHOD_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handleMethod(call, result);
      }
    });
  }

  private handleMethod(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'requestPermissions':
          this.requestPermissions(result);
          break;
        case 'startScan':
          this.startScan(result);
          break;
        case 'stopScan':
          this.stopScan(result);
          break;
        case 'connect':
          this.connect(call, result);
          break;
        case 'send':
          this.send(call, result);
          break;
        case 'disconnect':
          this.disconnect(result);
          break;
        default:
          result.notImplemented();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('spp_error', msg, null);
    }
  }

  private registerEventChannel(messenger: BinaryMessenger): void {
    const channel = new EventChannel(messenger, SPP_EVENT_CHANNEL);
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

  private registerScanEventChannel(messenger: BinaryMessenger): void {
    const channel = new EventChannel(messenger, SPP_SCAN_EVENT_CHANNEL);
    const handler: StreamHandler = {
      onListen: (args: Object | null, events: EventSink): void => {
        this.scanEventSink = events;
      },
      onCancel: (args: Object | null): void => {
        this.scanEventSink = null;
      }
    };
    channel.setStreamHandler(handler);
  }

  private emitEvent(ev: SppEvent): void {
    if (this.eventSink != null) {
      try { this.eventSink.success(ev); } catch (e) {
        console.error(TAG + ': event emit failed: ' + JSON.stringify(e));
      }
    }
  }

  private emitScanEvent(ev: SppScanEvent): void {
    if (this.scanEventSink != null) {
      try { this.scanEventSink.success(ev); } catch (e) {
        console.error(TAG + ': scan event emit failed: ' + JSON.stringify(e));
      }
    }
  }

  // ---------------------------------------------------------------------------
  private async requestPermissions(result: MethodResult): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(this.context, SPP_PERMISSIONS);
      let granted = true;
      for (let i = 0; i < res.authResults.length; i++) {
        if (res.authResults[i] !== 0) { granted = false; break; }
      }
      result.success(granted);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('permission_error', msg, null);
    }
  }

  private startScan(result: MethodResult): void {
    try {
      this.discovered.clear();
      // 注册发现回调（若已注册先 off 避免重复）。
      try { connection.off('bluetoothDeviceFind'); } catch (_) {}
      connection.on('bluetoothDeviceFind', (deviceIds: Array<string>) => {
        for (const id of deviceIds) {
          let name = '';
          try { name = connection.getRemoteDeviceName(id); } catch (_) {}
          this.discovered.set(id, name);
          const ev: SppScanEvent = { addr: id, name: name };
          this.emitScanEvent(ev);
        }
      });
      connection.startBluetoothDiscovery();
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('scan_error', msg, null);
    }
  }

  private stopScan(result: MethodResult): void {
    try {
      connection.stopBluetoothDiscovery();
      try { connection.off('bluetoothDeviceFind'); } catch (_) {}
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('scan_error', msg, null);
    }
  }

  private connect(call: MethodCall, result: MethodResult): void {
    try {
      const addr: string = call.argument('addr');
      // 先停止扫描。
      try { connection.stopBluetoothDiscovery(); } catch (_) {}
      const options: socket.SppOptions = {
        uuid: SPP_UUID,
        secure: false,
        type: socket.SppType.SPP_RFCOMM,
      };
      socket.sppConnect(addr, options, (err: BusinessError, clientSocket: number) => {
        if (err != null && (err as BusinessError).code != null && (err as BusinessError).code !== 0) {
          const msg = (err as BusinessError).message ?? String(err);
          result.error('connect_error', msg, null);
          return;
        }
        this.clientSocket = clientSocket;
        // 监听读取。注意：sppRead 回调给的是 ArrayBuffer，StandardMessageCodec
        // 只认识 Uint8Array，必须转换后 emit，否则 Dart 端收到错误结构。
        socket.on('sppRead', clientSocket, (data: ArrayBuffer) => {
          this.emitEvent({ event: 'data', data: new Uint8Array(data) });
        });
        result.success({
          channel: clientSocket,
          connectionMode: 'rfcomm',
          discoveryMs: 0,
          connectMs: 0,
        });
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('connect_error', msg, null);
    }
  }

  private send(call: MethodCall, result: MethodResult): void {
    try {
      const data: Uint8Array = call.argument('data');
      if (this.clientSocket < 0) {
        result.error('not_connected', 'SPP socket not connected', null);
        return;
      }
      // sppWrite 要求 ArrayBuffer；StandardMethodCodec 解码得到 Uint8Array，
      // 取其底层 buffer 传入（注意 offset/length 对齐，这里按完整拷贝处理）。
      const buf: ArrayBuffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
      socket.sppWrite(this.clientSocket, buf);
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('send_error', msg, null);
    }
  }

  private disconnect(result: MethodResult): void {
    try {
      if (this.clientSocket >= 0) {
        try { socket.sppCloseClientSocket(this.clientSocket); } catch (_) {}
        this.clientSocket = -1;
      }
      this.emitEvent({ event: 'disconnected' });
      result.success(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('disconnect_error', msg, null);
    }
  }
}
