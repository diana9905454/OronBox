import 'dart:io';

import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

import '../../../support/memory_secure_storage.dart';

import 'dart:async';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_service.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('extracts Xiaomi and Huami authkeys from wearable log zip', () {
    const log = '''
2026-01-01|I|HttpClient|{"code":0,"result":{"list":[{"sid":"1","identifier":"1","name":"Xiaomi Watch","model":"miwear.watch.test","status":1,"create_time":1,"update_time":2,"detail":{"encrypt_key":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","fw_ver":"1.2.3","mac":"01:23:45:67:89:AB","sn":"SN1","token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"sid":"huami.2","identifier":"huami.2","name":"Mi Band","model":"hmpace.bracelet.test","status":1,"create_time":1,"update_time":2,"detail":{"auth_key":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","mac_address":"10:32:54:76:98:BA","sn":"SN2"}}]}}
2026-01-01|I|Account|cookie is {auth_key=not-a-device-key}
''';
    final archive = Archive()
      ..addFile(ArchiveFile.string('XiaomiFit.device.log', log));
    final bytes = ZipEncoder().encode(archive);

    final devices = extractMiDevicesFromWearableLogZip(bytes);

    expect(devices, hasLength(2));
    expect(devices[0].mac, '01:23:45:67:89:AB');
    expect(devices[0].authKey, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(devices[1].mac, '10:32:54:76:98:BA');
    expect(devices[1].authKey, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
  });

  test(
    'extracts camelCase device snapshots with a redacted address suffix',
    () {
      const log = '''
2026-09-24|I|RRLog|
{
  "deviceInfo": {
    "device": {
      "name": "REDMI Watch 5 eSIM",
      "model": "miwear.watch.o65m",
      "detail": {
        "macAddress": null,
        "mac": "48:B0",
        "encryptKey": "cccccccccccccccccccccccccccccccc",
        "sn": "SN3"
      }
    }
  }
}
''';
      final archive = Archive()
        ..addFile(ArchiveFile.string('XiaomiFit.main.log', log));

      final devices = extractMiDevicesFromWearableLogZip(
        ZipEncoder().encode(archive),
      );

      expect(devices, hasLength(1));
      expect(devices.single.model, 'miwear.watch.o65m');
      expect(devices.single.mac, '48:B0');
      expect(devices.single.authKey, 'cccccccccccccccccccccccccccccccc');
      expect(devices.single.hasAuthKey, isFalse);
    },
  );

  test('resolves a redacted address from companion log records', () {
    const deviceLog = '''
{
  "deviceInfo": {
    "device": {
      "name": "REDMI Watch 5 eSIM",
      "model": "miwear.watch.o65m",
      "detail": {
        "mac": "48:B0",
        "encryptKey": "dddddddddddddddddddddddddddddddd"
      }
    }
  }
}
''';
    const transferLog =
        'CompanionDeviceManagerApi|isAssociated 3C:AF:B7:FE:48:B0';
    final archive = Archive()
      ..addFile(ArchiveFile.string('XiaomiFit.main.log', deviceLog))
      ..addFile(ArchiveFile.string('Transfer.device.log', transferLog));

    final devices = extractMiDevicesFromWearableLogZip(
      ZipEncoder().encode(archive),
    );

    expect(devices, hasLength(1));
    expect(devices.single.mac, '3C:AF:B7:FE:48:B0');
    expect(devices.single.hasAuthKey, isTrue);
  });

  test('resolves a redacted log address only when it is unambiguous', () {
    const device = MiCloudDevice(
      name: 'REDMI Watch 5 eSIM',
      model: 'miwear.watch.o65m',
      mac: '48:B0',
      authKey: 'cccccccccccccccccccccccccccccccc',
      firmwareVersion: '',
      serialNumber: 'SN3',
    );

    expect(
      resolveMiCloudDeviceAddress(device, const ['AA:BB:CC:DD:48:B0']),
      'AA:BB:CC:DD:48:B0',
    );
    expect(
      resolveMiCloudDeviceAddress(device, const [
        'AA:BB:CC:DD:48:B0',
        '11:22:33:44:48:B0',
      ]),
      isNull,
    );
  });

  test('persists and clears the Xiaomi signed session material', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp(
      'oronbox-host-account-test-',
    );
    PrivateAppState.instanceForTesting = PrivateAppState(
      secureStorage: MemorySecureStorage(),
      lock: IoAppDataDirectory(root),
    );
    addTearDown(() async {
      PrivateAppState.instanceForTesting = null;
      await root.delete(recursive: true);
    });
    final service = MiAccountService();
    const token = MiAccountToken(
      userId: '10001',
      deviceId: 'device-id',
      ssecurity: 'ssecurity',
      serviceToken: 'service-token',
      cUserId: 'c-user-id',
      passToken: 'pass-token',
      psecurity: 'psecurity',
    );

    await service.persistToken(token);
    expect((await service.loadStoredToken())?.toJson(), token.toJson());

    await service.clearStoredToken();
    expect(await service.loadStoredToken(), isNull);
  });

  test('account state and mutations use the host interface', () async {
    final host = _AccountHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    await container.read(hostAccountsProvider.notifier).refresh();
    await container
        .read(hostAccountsProvider.notifier)
        .loginAmazfit(username: 'user@example.com', password: 'secret');
    await container
        .read(hostAccountsProvider.notifier)
        .saveCredentials(
          provider: 'amazfit',
          remember: true,
          username: 'user@example.com',
          password: 'secret',
        );
    final credentials = await container
        .read(hostAccountsProvider.notifier)
        .rememberedCredentials('amazfit');

    final state = container.read(hostAccountsProvider);
    expect(state.amazfit.signedIn, true);
    expect(state.amazfit.username, 'user@example.com');
    expect(credentials['password'], 'secret');
    expect(
      host.methods.where((method) => method == 'account.list'),
      isNotEmpty,
    );
    expect(
      host.methods,
      containsAll([
        'account.login',
        'account.credentials.set',
        'account.credentials.get',
      ]),
    );
  });

  test(
    'BandBBS callback state is not overwritten by a stale account list',
    () async {
      final host = _OAuthCallbackHost();
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      await container.read(hostAccountsProvider.notifier).refresh();
      expect(container.read(hostAccountsProvider).bandbbs.signedIn, false);

      await container
          .read(hostAccountsProvider.notifier)
          .handleBandBbsCallback(
            Uri.parse('oronbox://oauth/bandbbs?ticket=one-time'),
          );
      host.completeStaleRefresh();
      await Future<void>.delayed(Duration.zero);

      final account = container.read(hostAccountsProvider).bandbbs;
      expect(account.signedIn, true);
      expect(account.username, 'OrPudding');
      expect(account.userId, '191699');
    },
  );

  test('BandBBS publishing authorization runs through the host', () async {
    final host = _AccountHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    await container
        .read(hostAccountsProvider.notifier)
        .startBandBbsPublishingAuthorization();

    expect(host.methods, contains('account.bandbbs.publish'));
    expect(container.read(hostAccountsProvider).bandbbs.isBusy, false);
  });
}

class _AccountHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    if (command.method == 'account.list') {
      return const CommandResult.success([
        {'provider': 'xiaomi', 'signedIn': false},
        {'provider': 'amazfit', 'signedIn': false},
        {'provider': 'bandbbs', 'signedIn': false},
      ]);
    }
    if (command.method == 'account.credentials.get') {
      return const CommandResult.success({
        'provider': 'amazfit',
        'remember': true,
        'username': 'user@example.com',
        'password': 'secret',
      });
    }
    if (command.method == 'account.credentials.set') {
      return CommandResult.success(command.params);
    }
    return CommandResult.success({
      'provider': 'amazfit',
      'signedIn': true,
      'username': command.params['username'],
    });
  }

  @override
  Future<void> close() => _events.close();
}

class _OAuthCallbackHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  Completer<CommandResult>? _staleRefresh;
  var _callbackStarted = false;

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'account.list') {
      if (_callbackStarted) {
        return (_staleRefresh ??= Completer<CommandResult>()).future;
      }
      return const CommandResult.success([
        {'provider': 'bandbbs', 'signedIn': false},
      ]);
    }
    if (command.method == 'account.bandbbs.callback') {
      _callbackStarted = true;
      const account = {
        'provider': 'bandbbs',
        'signedIn': true,
        'username': 'OrPudding',
        'userId': '191699',
      };
      _events.add(
        const CommandEvent(
          'account.state',
          data: {
            'state': [account],
          },
        ),
      );
      return const CommandResult.success(account);
    }
    throw StateError('Unexpected command ${command.method}');
  }

  void completeStaleRefresh() {
    _staleRefresh?.complete(
      const CommandResult.success([
        {'provider': 'bandbbs', 'signedIn': false},
      ]),
    );
  }

  @override
  Future<void> close() => _events.close();
}
