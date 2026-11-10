import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectAsrSocket(
  Uri url, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) async {
  final channel = IOWebSocketChannel.connect(
    url,
    headers: headers,
    protocols: protocols,
    connectTimeout: const Duration(seconds: 10),
  );
  await channel.ready;
  return channel;
}
