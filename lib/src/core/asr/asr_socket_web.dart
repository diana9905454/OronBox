import 'package:web_socket_channel/web_socket_channel.dart';

import 'asr.dart';

Future<WebSocketChannel> connectAsrSocket(
  Uri url, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) async {
  if (headers?.isNotEmpty == true) throw const AsrFailure('unsupported');
  final channel = WebSocketChannel.connect(url, protocols: protocols);
  await channel.ready.timeout(const Duration(seconds: 10));
  return channel;
}
