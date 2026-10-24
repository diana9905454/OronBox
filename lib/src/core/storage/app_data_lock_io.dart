import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:uuid/uuid.dart';

const _serviceName = 'oronbox.storage.locks.v1';
final _owner = const Uuid().v4();
Future<SendPort>? _service;

/// One isolate owns the file descriptors: POSIX record locks are process-scoped.
Future<Future<void> Function()?> acquireAppDataLock(
  String path, {
  required bool wait,
}) async {
  final directory = Directory(path);
  await directory.create(recursive: true);
  path = await directory.resolveSymbolicLinks();
  final server = await _coordinator();
  final reply = ReceivePort();
  final token = const Uuid().v4();
  server.send(['acquire', path, _owner, token, reply.sendPort, wait]);
  final result = await reply.first;
  reply.close();
  if (result is String) throw FileSystemException(result);
  if (result != true) return null;
  var released = false;
  return () async {
    if (released) return;
    released = true;
    final done = ReceivePort();
    server.send(['release', path, _owner, token, done.sendPort]);
    await done.first;
    done.close();
  };
}

Future<SendPort> _coordinator() {
  final cached = _service;
  if (cached != null) return cached;
  late final Future<SendPort> pending;
  pending = _connect().catchError((Object error, StackTrace stack) {
    if (identical(_service, pending)) _service = null;
    Error.throwWithStackTrace(error, stack);
  });
  return _service = pending;
}

Future<SendPort> _connect() async {
  var server = IsolateNameServer.lookupPortByName(_serviceName);
  if (server == null) {
    final ready = ReceivePort();
    final child = await Isolate.spawn(
      _serve,
      ready.sendPort,
      debugName: 'oronbox-storage-locks',
    );
    final candidate = await ready.first as SendPort;
    ready.close();
    if (IsolateNameServer.registerPortWithName(candidate, _serviceName)) {
      server = candidate;
    } else {
      child.kill(priority: Isolate.immediate);
      server = IsolateNameServer.lookupPortByName(_serviceName);
    }
  }
  if (server == null) throw StateError('Storage lock coordinator unavailable');
  Isolate.current.addOnExitListener(server, response: ['exit', _owner]);
  return server;
}

class _Request {
  _Request(this.owner, this.token, this.reply, this.wait);
  final String owner, token;
  final SendPort reply;
  final bool wait;
}

class _Lock {
  final pending = <_Request>[];
  _Request? active;
  RandomAccessFile? handle;
  bool pumping = false;
  Future<void>? releasing;
}

void _serve(SendPort ready) {
  final messages = ReceivePort();
  final locks = <String, _Lock>{};
  final exited = <String>{};
  ready.send(messages.sendPort);

  Future<void> pump(String path, _Lock lock) async {
    if (lock.pumping || lock.active != null || lock.releasing != null) return;
    lock.pumping = true;
    try {
      while (lock.pending.isNotEmpty) {
        final request = lock.pending.removeAt(0);
        if (exited.contains(request.owner)) continue;
        RandomAccessFile? handle;
        try {
          await Directory(path).create(recursive: true);
          handle = await File('$path/.lock').open(mode: FileMode.append);
          try {
            await handle.lock(
              request.wait ? FileLock.blockingExclusive : FileLock.exclusive,
            );
          } on FileSystemException {
            if (request.wait) rethrow;
            request.reply.send(false);
            continue;
          }
          if (exited.contains(request.owner)) continue;
          lock.active = request;
          lock.handle = handle;
          handle = null;
          request.reply.send(true);
          return;
        } catch (_) {
          request.reply.send('Unable to acquire application storage lock');
        } finally {
          await handle?.close();
        }
      }
    } finally {
      lock.pumping = false;
      if (lock.active == null &&
          lock.pending.isEmpty &&
          lock.releasing == null) {
        locks.remove(path);
      }
    }
  }

  Future<void> release(String path, _Lock lock) async {
    final closing = lock.releasing;
    if (closing != null) return closing;
    final done = Completer<void>();
    lock.releasing = done.future;
    try {
      await lock.handle?.close();
      lock.handle = null;
      lock.active = null;
    } finally {
      lock.releasing = null;
      done.complete();
      unawaited(pump(path, lock));
    }
  }

  messages.listen((dynamic message) {
    if (message is! List || message.isEmpty) return;
    if (message[0] == 'exit') {
      final owner = message[1] as String;
      exited.add(owner);
      for (final entry in locks.entries.toList()) {
        entry.value.pending.removeWhere((request) => request.owner == owner);
        if (entry.value.active?.owner == owner) {
          unawaited(release(entry.key, entry.value));
        }
      }
    } else if (message[0] == 'acquire') {
      final path = message[1] as String;
      final request = _Request(
        message[2] as String,
        message[3] as String,
        message[4] as SendPort,
        message[5] as bool,
      );
      final lock = locks.putIfAbsent(path, _Lock.new);
      if (exited.contains(request.owner)) return;
      if (!request.wait &&
          (lock.active != null ||
              lock.pumping ||
              lock.releasing != null ||
              lock.pending.isNotEmpty)) {
        request.reply.send(false);
      } else {
        lock.pending.add(request);
        unawaited(pump(path, lock));
      }
    } else if (message[0] == 'release') {
      final path = message[1] as String;
      final lock = locks[path];
      final reply = message[4] as SendPort;
      if (lock?.active?.owner == message[2] &&
          lock?.active?.token == message[3]) {
        unawaited(release(path, lock!).then((_) => reply.send(true)));
      } else {
        reply.send(false);
      }
    }
  });
}
