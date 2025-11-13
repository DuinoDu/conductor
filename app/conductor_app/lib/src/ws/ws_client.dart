import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

typedef MessageHandler = void Function(dynamic message);

class AppWebSocketClient {
  AppWebSocketClient({
    required this.uri,
    WebSocketChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final Uri uri;
  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get messages => _controller.stream;

  Future<void> connect() async {
    await disconnect();
    _channel = _channelFactory(uri);
    _subscription = _channel!.stream.listen(
      _controller.add,
      onError: _controller.addError,
      onDone: () {},
    );
  }

  void send(dynamic data) {
    _channel?.sink.add(data);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}
