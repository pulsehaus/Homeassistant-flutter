import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal duplex JSON transport to a Home Assistant WebSocket.
///
/// This is the seam that makes [HaWebSocketClient] unit-testable: the client
/// talks to this interface, not to a real socket. The production implementation
/// ([WebSocketChannelHaSocket]) wraps `package:web_socket_channel`; tests supply
/// a fake that pushes decoded maps directly.
abstract interface class HaSocket {
  /// Decoded inbound messages. The stream closes (`onDone`) when the connection
  /// ends and emits an error (`onError`) on a transport failure.
  Stream<Map<String, dynamic>> get messages;

  /// JSON-encode and send a single message.
  void send(Map<String, dynamic> message);

  /// Close the underlying connection.
  Future<void> close();
}

/// Opens a [HaSocket] to [url]. Injected into [HaWebSocketClient] so tests can
/// substitute a fake transport. The returned future lets the production
/// connector await the socket handshake before the client uses it.
typedef HaSocketConnector = Future<HaSocket> Function(Uri url);

/// Production [HaSocket] backed by a [WebSocketChannel]. Works across web,
/// mobile and desktop.
class WebSocketChannelHaSocket implements HaSocket {
  WebSocketChannelHaSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Map<String, dynamic>> get messages => _channel.stream.map((event) {
    final decoded = jsonDecode(event as String);
    return (decoded as Map).cast<String, dynamic>();
  });

  @override
  void send(Map<String, dynamic> message) =>
      _channel.sink.add(jsonEncode(message));

  @override
  Future<void> close() => _channel.sink.close();
}

/// Default [HaSocketConnector]: opens a real WebSocket and waits for the
/// connection to be established (or to fail) before returning.
Future<HaSocket> connectHaWebSocket(Uri url) async {
  final channel = WebSocketChannel.connect(url);
  // Throws if the connection cannot be established — the client treats this as
  // a (retryable) connection failure.
  await channel.ready;
  return WebSocketChannelHaSocket(channel);
}
