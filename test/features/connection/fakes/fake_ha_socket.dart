import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_socket.dart';

/// In-memory [HaSocket] for unit tests. Drives the client at the decoded-map
/// level (no real JSON / socket) and lets a test play the role of the server.
class FakeHaSocket implements HaSocket {
  final _incoming = StreamController<Map<String, dynamic>>();

  /// Messages the client has sent, in order.
  final List<Map<String, dynamic>> sent = [];

  bool closed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  @override
  void send(Map<String, dynamic> message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  // --- Test helpers (the "server" side) ---

  /// Push a message from the server to the client.
  void serverSend(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  /// Emit a transport error (e.g. network failure).
  void serverError(Object error) {
    if (!_incoming.isClosed) _incoming.addError(error);
  }

  /// Close the connection from the server side (triggers the client's onDone).
  void serverClose() {
    if (!_incoming.isClosed) _incoming.close();
  }

  /// Convenience: messages sent by the client of a given `type`.
  Iterable<Map<String, dynamic>> sentOfType(String type) =>
      sent.where((m) => m['type'] == type);
}

/// [HaSocketConnector] that hands out [FakeHaSocket]s and records every call,
/// so tests can assert on (re)connection attempts.
class FakeConnector {
  final List<FakeHaSocket> sockets = [];
  int calls = 0;

  /// When > 0, the next N connection attempts throw before yielding a socket.
  int failNextConnections = 0;

  Future<HaSocket> connect(Uri url) async {
    calls += 1;
    if (failNextConnections > 0) {
      failNextConnections -= 1;
      throw Exception('connection refused');
    }
    final socket = FakeHaSocket();
    sockets.add(socket);
    return socket;
  }

  FakeHaSocket get last => sockets.last;
}

/// Drives a connected [FakeHaSocket] through the full auth + subscribe + seed
/// handshake on the real event queue, leaving the client `connected`.
Future<void> completeHandshake(
  FakeHaSocket socket, {
  List<Map<String, dynamic>> states = const [],
}) async {
  socket.serverSend({'type': 'auth_required'});
  await pumpEventQueue();
  socket.serverSend({'type': 'auth_ok'});
  await pumpEventQueue();
  final subscribe = socket.sentOfType('subscribe_events').last;
  final getStates = socket.sentOfType('get_states').last;
  socket.serverSend({
    'id': subscribe['id'],
    'type': 'result',
    'success': true,
    'result': null,
  });
  socket.serverSend({
    'id': getStates['id'],
    'type': 'result',
    'success': true,
    'result': states,
  });
  await pumpEventQueue();
}
