/// The socket a multiplayer room talks over (net/online_table.dart), on
/// web_socket_channel: the browser's WebSocket on the web, dart:io's on a
/// phone.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../net/online_table.dart';

class _ChannelSocket implements RoomSocket {
  _ChannelSocket(this._channel);
  final WebSocketChannel _channel;

  @override
  Stream<String> get incoming => _channel.stream.map((m) => '$m');

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}

/// Opens a room's socket; throws if it can't be reached.
Future<RoomSocket> openRoomSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return _ChannelSocket(channel);
}
