import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/local_server/local_server.dart';
import 'package:oronbox/src/local_server/local_server_auth.dart';

void main() {
  test('Local API Server full HTTP lifecycle: info, pairing, challenge, SSE and install', () async {
    final serverIdentity = LocalServerEd25519KeyPair.generate();
    final clientIdentity = LocalServerEd25519KeyPair.generate();
    final host = _RecordingHost();

    final stagingDir = await Directory.systemTemp.createTemp(
      'oronbox-staging-',
    );
    final server = LocalServer(
      serverId: 'server-1',
      displayName: 'Test OronBox',
      platform: 'macos',
      identity: serverIdentity,
      host: InternetAddress.loopbackIPv4,
      port: 0,
      commandBus: host,
      temporaryDirectoryProvider: () async => stagingDir,
    );

    await server.start();
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await server.stop();
      await host.close();
      if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
    });

    final port = server.boundPort;

    // 1. GET /v1/info
    final infoRes = await _jsonRequest(http, port, 'GET', '/v1/info');
    expect(infoRes.statusCode, 200);
    expect(infoRes.body['serverId'], 'server-1');
    expect(infoRes.body['protocolVersion'], 1);
    expect(infoRes.body['auth'], 'ed25519-challenge');
    expect(infoRes.body['publicKey'], serverIdentity.publicKeyBase64Url);

    // 2. POST /v1/auth/pairing-requests
    final pairRes = await _jsonRequest(
      http,
      port,
      'POST',
      '/v1/auth/pairing-requests',
      body: {
        'clientName': 'AstroBoxCli',
        'publicKey': clientIdentity.publicKeyBase64Url,
        'requestedScopes': [
          'device.read',
          'events.subscribe',
          'install.upload',
          'task.read',
        ],
      },
    );
    expect(pairRes.statusCode, 202);
    final pairingId = pairRes.body['pairingId'].toString();
    expect(pairRes.body['state'], 'pending');

    // 3. GET /v1/auth/pairing-requests/:pairingId
    final statusRes = await _jsonRequest(
      http,
      port,
      'GET',
      '/v1/auth/pairing-requests/$pairingId',
    );
    expect(statusRes.statusCode, 200);
    expect(statusRes.body['state'], 'pending');

    // 4. Server approves pairing
    server.approvePairing(pairingId);

    final approvedStatusRes = await _jsonRequest(
      http,
      port,
      'GET',
      '/v1/auth/pairing-requests/$pairingId',
    );
    expect(approvedStatusRes.body['state'], 'granted');

    // 5. POST /v1/auth/challenges
    final challengeRes = await _jsonRequest(
      http,
      port,
      'POST',
      '/v1/auth/challenges',
      body: {'fingerprint': clientIdentity.fingerprint},
    );
    expect(challengeRes.statusCode, 200);
    final challengeId = challengeRes.body['challengeId'].toString();
    final signingPayload = challengeRes.body['signingPayload'].toString();

    // 6. Sign challenge with Ed25519
    final payloadBytes = decodeBase64Url(signingPayload);
    final sigBytes = clientIdentity.sign(payloadBytes);
    final signatureBase64Url = base64Url.encode(sigBytes).replaceAll('=', '');

    // 7. POST /v1/auth/sessions
    final sessionRes = await _jsonRequest(
      http,
      port,
      'POST',
      '/v1/auth/sessions',
      body: {'challengeId': challengeId, 'signature': signatureBase64Url},
    );
    expect(sessionRes.statusCode, 200);
    final token = sessionRes.body['token'].toString();
    expect(token, isNotEmpty);
    expect(sessionRes.body['tokenType'], 'Bearer');

    // 8. GET /v1/events (SSE)
    final sseRequest = await http.getUrl(
      Uri.parse('http://127.0.0.1:$port/v1/events'),
    );
    sseRequest.headers.set('authorization', 'Bearer $token');
    final sseResponse = await sseRequest.close();
    expect(sseResponse.statusCode, 200);
    expect(
      sseResponse.headers.contentType.toString(),
      contains('text/event-stream'),
    );

    final sseEvents = <String>[];
    final readyCompleter = Completer<void>();
    final sseCompleter = Completer<void>();
    final sseSub = sseResponse.transform(utf8.decoder).listen((chunk) {
      sseEvents.add(chunk);
      if (chunk.contains('event: ready') && !readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
      if (chunk.contains('device.connected') && !sseCompleter.isCompleted) {
        sseCompleter.complete();
      }
    });

    await readyCompleter.future.timeout(const Duration(seconds: 2));
    expect(sseEvents.any((chunk) => chunk.contains('event: ready')), isTrue);

    // Emit event on command bus and check SSE receipt
    host.emit(
      const CommandEvent('device.connected', data: {'deviceId': 'mac-1'}),
    );
    await sseCompleter.future.timeout(const Duration(seconds: 2));
    await sseSub.cancel();

    // 9. POST /v1/install
    final fileBytes = utf8.encode('test-rpk-binary-payload');
    final sha256Hex = sha256.convert(fileBytes).toString();

    final installReq = await http.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/install'),
    );
    installReq.headers.set('authorization', 'Bearer $token');
    installReq.headers.set('x-oronbox-file-name', 'dial.rpk');
    installReq.headers.set('x-oronbox-type', 'watchface');
    installReq.headers.set('x-oronbox-sha256', sha256Hex);
    installReq.headers.set('x-oronbox-size', fileBytes.length.toString());
    installReq.add(fileBytes);
    final installRes = await installReq.close();
    expect(installRes.statusCode, 202);

    final installBody =
        jsonDecode(await installRes.transform(utf8.decoder).join()) as Map;
    expect(installBody['taskId'], 'task-42');
    expect(installBody['fileName'], 'dial.rpk');
    expect(installBody['sha256'], sha256Hex);

    // 10. GET /v1/tasks/:taskId
    final taskRes = await _jsonRequest(
      http,
      port,
      'GET',
      '/v1/tasks/task-42',
      token: token,
    );
    expect(taskRes.statusCode, 200);
    expect(taskRes.body['taskId'], 'task-42');
    expect(taskRes.body['status'], 'succeeded');

    // 11. GET /v1/devices/info
    final deviceInfoRes = await _jsonRequest(
      http,
      port,
      'GET',
      '/v1/devices/info',
      token: token,
    );
    expect(deviceInfoRes.statusCode, 200);
    final result = deviceInfoRes.body['result'] as Map<String, dynamic>;
    expect(result['connected'], true);
    final storageMap = result['storage'] as Map<String, dynamic>;
    expect(storageMap['totalBytes'], 104857600);
  });
}

class _RecordingHost implements OronBoxCommandBus {
  final _eventsController = StreamController<CommandEvent>.broadcast();
  final commands = <OronBoxCommand>[];

  @override
  Stream<CommandEvent> get events => _eventsController.stream;

  void emit(CommandEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    commands.add(command);
    if (command.method == 'task.enqueue') {
      return const CommandResult.success({'taskId': 'task-42'});
    }
    if (command.method == 'queue.get') {
      return const CommandResult.success({
        'taskId': 'task-42',
        'status': 'succeeded',
        'progress': 1.0,
      });
    }
    if (command.method == 'device.paired') {
      return const CommandResult.success([
        {
          'name': 'Xiaomi Band 9 Pro',
          'address': 'AA:BB:CC:DD:EE:FF',
          'connectType': 'BLE',
          'codename': 'm75',
        },
      ]);
    }
    if (command.method == 'device.status') {
      return const CommandResult.success({
        'connected': true,
        'protocolState': 'ready',
        'device': {
          'name': 'Xiaomi Band 9 Pro',
          'address': 'AA:BB:CC:DD:EE:FF',
          'connectType': 'BLE',
        },
      });
    }
    if (command.method == 'device.info') {
      return const CommandResult.success({
        'connected': true,
        'protocolState': 'ready',
        'device': {
          'name': 'Xiaomi Band 9 Pro',
          'address': 'AA:BB:CC:DD:EE:FF',
          'connectType': 'BLE',
        },
        'battery': 85,
        'storage': {
          'totalBytes': 104857600,
          'freeBytes': 52428800,
          'usedBytes': 52428800,
        },
      });
    }
    return const CommandResult.success(null);
  }

  @override
  Future<void> close() async {
    await _eventsController.close();
  }
}

class _Response {
  const _Response(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

Future<_Response> _jsonRequest(
  HttpClient http,
  int port,
  String method,
  String path, {
  Map<String, Object?>? body,
  String? token,
}) async {
  final request = await http.openUrl(
    method,
    Uri.parse('http://127.0.0.1:$port$path'),
  );
  if (token != null) {
    request.headers.set('authorization', 'Bearer $token');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final responseText = await response.transform(utf8.decoder).join();
  final decoded = responseText.isNotEmpty
      ? jsonDecode(responseText) as Map<String, Object?>
      : <String, Object?>{};
  return _Response(response.statusCode, decoded);
}
