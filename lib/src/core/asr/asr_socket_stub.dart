import 'package:web_socket_channel/web_socket_channel.dart';

import 'asr.dart';

Future<WebSocketChannel> connectAsrSocket(
  Uri url, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) => Future.error(const AsrFailure('unsupported'));
