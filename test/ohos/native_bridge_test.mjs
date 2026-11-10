import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

// Host-side fault injection for bridge logic. Does not replace ArkTS SDK checking.
export async function runBridgeTests(root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')) {
  const results = [];
  const check = async (name, body) => {
    await body();
    results.push(name);
  };
  const quiet = { error() {}, warn() {}, log() {} };
  const channels = new Map();
  class MethodChannel {
    constructor(_messenger, name) { this.name = name; }
    setMethodCallHandler(handler) { channels.set(this.name, handler); }
  }
  class EventChannel {
    constructor(_messenger, name) { this.name = name; }
    setStreamHandler(handler) { channels.set(this.name, handler); }
  }
  const engine = { getDartExecutor: () => ({ getBinaryMessenger: () => ({}) }) };
  const request = (channel, method, args = {}) => {
    let settled = false;
    return new Promise((resolve, reject) => {
      const once = fn => value => {
        assert.equal(settled, false, 'method result must complete once');
        settled = true;
        fn(value);
      };
      channels.get(channel).onMethodCall({ method, argument: name => args[name] }, {
        success: once(resolve),
        error: (code, message) => once(reject)(Object.assign(new Error(message), { code })),
        notImplemented: () => once(reject)(new Error('not implemented')),
      });
    });
  };
  const timers = new Map();
  let nextTimer = 0;
  const tick = async () => { for (let i = 0; i < 20; i++) await Promise.resolve(); };
  const load = async (file, name, mocks = {}) => {
    const source = (await readFile(path.join(root, 'ohos/entry/src/main/ets', file), 'utf8'))
      .replace(/^import .*;\r?$/gm, '');
    const js = stripTypeScriptTypes(source, { mode: 'transform' }).replace(/export default /g, '').replace(/export /g, '');
    return vm.runInNewContext(js + '\n' + name, {
      console: quiet, Uint8Array, ArrayBuffer, TextEncoder, TextDecoder,
      setTimeout: fn => { const id = ++nextTimer; timers.set(id, fn); return id; },
      clearTimeout: id => timers.delete(id),
      MethodChannel, EventChannel, ...mocks,
    });
  };

  const records = new Map();
  let failAlias = null;
  const asset = {
    Tag: { ALIAS: 'alias', SECRET: 'secret', ACCESSIBILITY: 'access', RETURN_TYPE: 'return' },
    ReturnType: { ALL: 1, ATTRIBUTES: 2 }, Accessibility: { DEVICE_FIRST_UNLOCKED: 1 },
    ErrorCode: { NOT_FOUND: 404 },
    async query(query) {
      const raw = query.get('alias');
      const alias = raw && new TextDecoder().decode(raw);
      const entries = alias == null ? [...records] : records.has(alias) ? [[alias, records.get(alias)]] : [];
      return entries.map(([key, value]) => new Map([
        ['alias', new TextEncoder().encode(key)], ['secret', value.slice()],
      ]));
    },
    async add(value) {
      const key = new TextDecoder().decode(value.get('alias'));
      if (key === failAlias) throw new Error('injected write failure');
      if (records.has(key)) throw Object.assign(new Error('duplicate'), { code: 24000003 });
      records.set(key, value.get('secret').slice());
    },
    async update(query, value) {
      assert.equal(value.has('access'), false, 'Asset update must not include immutable ACCESSIBILITY');
      const key = new TextDecoder().decode(query.get('alias'));
      if (key === failAlias) throw new Error('injected write failure');
      records.set(key, value.get('secret').slice());
    },
    async remove(query) { records.delete(new TextDecoder().decode(query.get('alias'))); },
  };
  let generation = 0;
  const util = {
    TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
    TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) },
    generateRandomUUID: () => 'generation-' + ++generation,
  };
  const Secure = await load('plugins/SecureStorageBridge.ets', 'SecureStorageBridge', { asset, util });
  new Secure().register(engine);
  const secure = (method, args) => request('plugins.it_nomads.com/flutter_secure_storage', method, args);
  const encode = value => new TextEncoder().encode(value);
  await check('secure storage reads legacy direct values and OBV1 chunks', async () => {
    records.set('direct', encode('legacy'));
    records.set('vault', encode('OBV1:2'));
    records.set('vault#0', encode('old-'));
    records.set('vault#1', encode('value'));
    assert.equal(await secure('read', { key: 'direct' }), 'legacy');
    assert.equal(await secure('read', { key: 'vault' }), 'old-value');
  });
  await check('updating an existing asset sends only mutable attributes', async () => {
    await secure('write', { key: 'direct', value: 'updated' });
    assert.equal(await secure('read', { key: 'direct' }), 'updated');
  });
  generation = 0;
  await check('failed new chunk leaves the entire old vault readable', async () => {
    failAlias = 'vault#generation-1#1';
    await assert.rejects(secure('write', { key: 'vault', value: '中'.repeat(700) }));
    assert.equal(await secure('read', { key: 'vault' }), 'old-value');
    failAlias = null;
  });
  await check('failed manifest commit preserves old chunks and value', async () => {
    failAlias = 'vault';
    await assert.rejects(secure('write', { key: 'vault', value: 'replacement' }));
    assert.equal(await secure('read', { key: 'vault' }), 'old-value');
    failAlias = null;
  });
  await check('successful write roundtrips UTF-8 and cleans obsolete and orphan chunks', async () => {
    const value = '设备🙂'.repeat(500);
    await secure('write', { key: 'vault', value });
    assert.equal(await secure('read', { key: 'vault' }), value);
    assert.equal(records.has('vault#0'), false);
    assert.equal(records.has('vault#generation-1#0'), false);
    assert.equal(records.has('vault#generation-2#0'), false);
  });
  await check('serialized overlapping writes never mix chunk generations', async () => {
    await Promise.all([
      secure('write', { key: 'vault', value: 'a'.repeat(2500) }),
      secure('write', { key: 'vault', value: '末'.repeat(800) }),
    ]);
    assert.equal(await secure('read', { key: 'vault' }), '末'.repeat(800));
    await secure('write', { key: 'vault', value: '' });
    assert.equal(await secure('read', { key: 'vault' }), '');
    await secure('delete', { key: 'vault' });
    assert.equal(await secure('read', { key: 'vault' }), null);
    assert.equal([...records.keys()].some(key => key.startsWith('vault#')), false);
  });

  const clients = [];
  let scannerStopped = 0;
  class Client {
    callbacks = new Map(); calls = 0; closed = false;
    characteristic = { serviceUuid: 'service', characteristicUuid: 'char', characteristicValue: new ArrayBuffer(0), properties: { write: true } };
    on(name, fn) { this.callbacks.set(name, fn); }
    off(name) { this.callbacks.delete(name); }
    emit(name, value) { this.callbacks.get(name)?.(value); }
    connect() {}
    disconnect() {}
    close() { this.closed = true; }
    async getServices() { this.calls++; return [{ serviceUuid: 'service', isPrimary: true, characteristics: [this.characteristic] }]; }
    async writeCharacteristicValue(ch) { this.written = ch.characteristicValue; }
    async readCharacteristicValue() { return { characteristicValue: encode('reply').buffer }; }
    async setCharacteristicChangeNotification() {}
    setBLEMtuSize() {}
  }
  const ble = {
    createGattClientDevice: () => { const c = new Client(); clients.push(c); return c; },
    createBleScanner: () => ({ on() {}, off() {}, async startScan() {}, async stopScan() { scannerStopped++; } }),
    GattWriteType: { WRITE: 1, WRITE_NO_RESPONSE: 2 },
  };
  const Ble = await load('plugins/OhosBleBridge.ets', 'OhosBleBridge', { ble });
  const bridge = new Ble({}); bridge.register(engine);
  const events = [];
  channels.get('oronbox/ble_events').onListen(null, { success: ev => events.push(ev) });
  const callBle = (method, args) => request('oronbox/ble', method, args);
  await check('BLE connect stops scanning and waits for connected state', async () => {
    await callBle('startScan');
    assert.equal(await callBle('isScanning'), true);
    let done = false;
    const connected = callBle('connect', { deviceId: 'watch', timeoutMs: 12000 }).then(() => { done = true; });
    await tick();
    assert.equal(done, false);
    assert.equal(scannerStopped, 1);
    assert.equal(await callBle('isScanning'), false);
    clients[0].emit('BLEConnectionStateChange', { state: 1 });
    assert.equal(events.some(ev => ev.type === 'connectionState'), false);
    clients[0].emit('BLEConnectionStateChange', { state: 2 });
    await connected;
    assert.equal(await callBle('isConnected', { deviceId: 'watch' }), true);
  });
  await check('BLE byte transport preserves typed-array slice and caches services', async () => {
    const value = new Uint8Array([9, 1, 2, 9]).subarray(1, 3);
    await callBle('write', { deviceId: 'watch', serviceUuid: 'service', charUuid: 'char', value, writeType: 1 });
    assert.deepEqual([...new Uint8Array(clients[0].written)], [1, 2]);
    const reply = await callBle('read', { deviceId: 'watch', serviceUuid: 'service', charUuid: 'char' });
    assert.ok(reply instanceof Uint8Array);
    clients[0].emit('BLECharacteristicChange', { serviceUuid: 'service', characteristicUuid: 'char', characteristicValue: encode('event').buffer });
    assert.ok(events.at(-1).value instanceof Uint8Array);
    assert.equal(clients[0].calls, 1);
  });
  await check('MTU returns negotiated value, then conservative fallback on timeout', async () => {
    const mtu = callBle('requestMtu', { deviceId: 'watch', mtu: 517 });
    clients[0].emit('BLEMtuChange', 185);
    assert.equal(await mtu, 185);
    const fallback = callBle('requestMtu', { deviceId: 'watch', mtu: 517 });
    [...timers.values()][0]();
    assert.equal(await fallback, 185);
    timers.clear();
  });
  await check('disconnect releases GATT client and invalidates cached state', async () => {
    await callBle('disconnect', { deviceId: 'watch' });
    assert.equal(clients[0].closed, true);
    assert.equal(clients[0].callbacks.size, 0);
    assert.equal(await callBle('isConnected', { deviceId: 'watch' }), false);
    await assert.rejects(callBle('read', { deviceId: 'watch', serviceUuid: 'service', charUuid: 'char' }));
    assert.equal(clients.length, 1);
  });
  await check('connection timeout closes native client and rejects pending connect', async () => {
    const pending = callBle('connect', { deviceId: 'absent', timeoutMs: 12000 });
    const rejected = assert.rejects(pending, { code: 'connect_timeout' });
    await tick();
    [...timers.values()][0]();
    await rejected;
    assert.equal(clients.at(-1).closed, true);
    timers.clear();
  });

  await check('destroyed BLE bridge cannot create a late pending connection', async () => {
    const pending = callBle('connect', { deviceId: 'destroyed', timeoutMs: 12000 });
    const rejected = assert.rejects(pending);
    bridge.dispose();
    await rejected;
    assert.equal(clients.length, 2);
  });

  let sppCallback;
  const closedSockets = [];
  const socket = {
    SppType: { SPP_RFCOMM: 0 },
    sppConnect: (_addr, _options, callback) => { sppCallback = callback; },
    sppCloseClientSocket: id => closedSockets.push(id), on() {}, off() {},
  };
  const connection = { stopBluetoothDiscovery() {}, off() {} };
  let permissionsGranted = false;
  const abilityAccessCtrl = { createAtManager: () => ({ requestPermissionsFromUser: async () => ({ authResults: [permissionsGranted ? 0 : -1] }) }) };
  const Spp = await load('plugins/ClassicSppBridge.ets', 'ClassicSppBridge', { socket, connection, abilityAccessCtrl });
  new Spp({}).register(engine);
  await check('SPP permission denial is reported instead of silently ignored', async () => {
    await assert.rejects(request('oronbox/classic_spp', 'requestPermissions'), { code: 'permission_denied' });
    permissionsGranted = true;
    assert.equal(await request('oronbox/classic_spp', 'requestPermissions'), true);
  });
  await check('SPP stop scan obeys Dart list-result contract', async () => {
    assert.ok(Array.isArray(await request('oronbox/classic_spp', 'stopScan')));
  });
  await check('cancelled SPP connect rejects and closes a late successful socket', async () => {
    const pending = request('oronbox/classic_spp', 'connect', { addr: 'watch' });
    const rejected = assert.rejects(pending, { code: 'connect_cancelled' });
    await request('oronbox/classic_spp', 'disconnect');
    await rejected;
    sppCallback(null, 42);
    assert.deepEqual(closedSockets, [42]);
  });

  let starts = 0, stops = 0, failBackground = false;
  const backgroundTaskManager = {
    BackgroundMode: { BLUETOOTH_INTERACTION: 5 },
    async startBackgroundRunning() { if (failBackground) throw new Error('refused'); starts++; },
    async stopBackgroundRunning() { stops++; },
  };
  const wantAgent = { getWantAgent: async () => ({}), OperationType: { START_ABILITY: 0 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 0 } };
  const Background = await load('plugins/BackgroundTasksBridge.ets', 'BackgroundTasksBridge', { backgroundTaskManager, wantAgent });
  const background = new Background({ abilityInfo: { bundleName: 'test', name: 'EntryAbility' } }); background.register(engine);
  const task = (method, args) => request('oronbox/background_tasks', method, args);
  await check('connection and transfer leases share one background task', async () => {
    await task('beginConnection');
    const id = await task('begin');
    await task('updateConnection');
    assert.equal(starts, 1);
    await task('endConnection');
    assert.equal(stops, 0);
    await task('end', { id });
    assert.equal(stops, 1);
  });
  await check('system refusal does not poison later background requests', async () => {
    failBackground = true;
    await assert.rejects(task('beginConnection'));
    failBackground = false;
    await task('updateConnection');
    assert.equal(starts, 2);
    await task('endConnection');
  });
  await check('destroying ability stops task and rejects subsequent starts', async () => {
    await task('beginConnection');
    background.dispose();
    await tick();
    assert.equal(starts, stops);
    await assert.rejects(task('beginConnection'), { code: 'background_task_disposed' });
  });

  const files = new Map(); const descriptors = new Map(); let nextFd = 0;
  let failWrite = false;
  const fileSystem = {
    OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    accessSync: name => files.has(name),
    openSync(name, flags) {
      if ((flags & 4) !== 0) files.set(name, new Uint8Array());
      if (!files.has(name)) throw new Error('missing');
      const file = { fd: ++nextFd }; descriptors.set(file.fd, { name, offset: 0 }); return file;
    },
    statSync(fd) { return { size: files.get(descriptors.get(fd).name).length }; },
    readSync(fd, buffer) {
      const descriptor = descriptors.get(fd), value = files.get(descriptor.name);
      const count = Math.min(buffer.byteLength, value.length - descriptor.offset, 5);
      new Uint8Array(buffer).set(value.subarray(descriptor.offset, descriptor.offset + count));
      descriptor.offset += count; return count;
    },
    writeSync(fd, buffer) {
      if (failWrite) throw new Error('disk full');
      const descriptor = descriptors.get(fd), old = files.get(descriptor.name), value = new Uint8Array(buffer);
      const count = Math.min(value.length, 7), next = new Uint8Array(old.length + count);
      next.set(old); next.set(value.subarray(0, count), old.length); files.set(descriptor.name, next); return count;
    },
    fsyncSync() {}, closeSync(file) { descriptors.delete(file.fd); },
    renameSync(from, to) { files.set(to, files.get(from)); files.delete(from); },
  };
  const Prefs = await load('plugins/StubPlugins.ets', 'OronBoxStubPlugins', { fs: fileSystem, util });
  new Prefs({ filesDir: '/sandbox' }).register(engine);
  const pref = (method, args) => request('plugins.flutter.io/shared_preferences', method, args);
  await check('preferences handle partial I/O and preserve UTF-8', async () => {
    await pref('setString', { key: 'name', value: '设备🙂' });
    assert.equal((await pref('getAll')).name, '设备🙂');
    assert.equal(descriptors.size, 0);
  });
  await check('failed preferences write reports error and preserves previous file', async () => {
    failWrite = true;
    await assert.rejects(pref('setString', { key: 'name', value: 'lost' }));
    failWrite = false;
    assert.equal((await pref('getAll')).name, '设备🙂');
    assert.equal(descriptors.size, 0);
  });
  await check('corrupt preferences are reported instead of silently cleared', async () => {
    files.set('/sandbox/oronbox_shared_prefs.json', encode('{broken'));
    await assert.rejects(pref('setString', { key: 'name', value: 'replacement' }));
    assert.equal(new TextDecoder().decode(files.get('/sandbox/oronbox_shared_prefs.json')), '{broken');
  });
  const AppLinks = await load('plugins/AppLinksBridge.ets', 'OronBoxAppLinksBridge');
  class StubBridge { register() {} dispose() {} }
  class FlutterAbility {
    context = {};
    onCreate() {} configureFlutterEngine() {} onDestroy() {}
  }
  const Entry = await load('entryability/EntryAbility.ets', 'EntryAbility', {
    FlutterAbility, GeneratedPluginRegistrant: { registerWith() {} },
    OronBoxAppLinksBridge: AppLinks,
    OronBoxStubPlugins: StubBridge, OhosBleBridge: StubBridge, BackgroundTasksBridge: StubBridge,
    OronBoxUrlLauncherStub: StubBridge, ClassicSppBridge: StubBridge,
    FilePickerBridge: StubBridge, MiAccountTwoFactorBridge: StubBridge,
    ImageEncodeBridge: StubBridge, LogsBridge: StubBridge, FileOpenBridge: StubBridge,
    PublicBackupsBridge: StubBridge, SecureStorageBridge: StubBridge,
    WearableLogBridge: StubBridge, QrScanBridge: StubBridge,
  });
  await check('cold-start OAuth link survives engine registration', async () => {
    const entry = new Entry();
    const uri = 'oronbox://oauth/bandbbs?code=test';
    entry.onCreate({ uri }, {});
    entry.configureFlutterEngine(engine);
    assert.equal(await request('com.llfbandit.app_links/messages', 'getInitialLink'), uri);
    entry.onDestroy();
  });
  return results;
}
