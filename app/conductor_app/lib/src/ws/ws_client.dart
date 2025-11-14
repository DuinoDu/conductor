import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

enum WebSocketConnectionState { connecting, connected, disconnected }

class AppWebSocketClient {
  AppWebSocketClient({
    required this.uri,
    WebSocketChannelFactory? channelFactory,
    Duration? retryDelay,
  })  : _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _retryDelay = retryDelay ?? const Duration(seconds: 5);

  final Uri uri;
  final WebSocketChannelFactory _channelFactory;
  final Duration _retryDelay;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<dynamic>.broadcast();

  late final StreamController<WebSocketConnectionState> _statusController =
      StreamController<WebSocketConnectionState>.broadcast(
    onListen: () {
      _statusController.add(_status);
    },
  );
  WebSocketConnectionState _status = WebSocketConnectionState.disconnected;

  bool _shouldReconnect = false;
  bool _connecting = false;
  Timer? _retryTimer;

  Stream<dynamic> get messages => _controller.stream;
  Stream<WebSocketConnectionState> get statusStream => _statusController.stream;
  WebSocketConnectionState get status => _status;

  Future<void> connect() async {
    _shouldReconnect = true;
    if (_channel != null || _connecting) {
      return;
    }
    await _attemptConnect();
  }

  void send(dynamic data) {
    _channel?.sink.add(data);
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
    _setStatus(WebSocketConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _statusController.close();
  }

  Future<void> _attemptConnect() async {
    if (_connecting || !_shouldReconnect) {
      return;
    }
    _connecting = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _setStatus(WebSocketConnectionState.connecting);
    try {
      final channel = _channelFactory(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _controller.add,
        onError: (error) {
          _controller.addError(error);
          _handleConnectionLoss();
        },
        onDone: _handleConnectionLoss,
      );
      _setStatus(WebSocketConnectionState.connected);
    } catch (error) {
      _controller.addError(error);
      _handleConnectionLoss();
    } finally {
      _connecting = false;
    }
  }

  void _handleConnectionLoss([dynamic _]) {
    _subscription?..cancel();
    _subscription = null;
    _channel = null;
    if (!_shouldReconnect) {
      _setStatus(WebSocketConnectionState.disconnected);
      return;
    }
    if (_retryTimer != null) {
      return;
    }
    _setStatus(WebSocketConnectionState.disconnected);
    _retryTimer = Timer(_retryDelay, () async {
      _retryTimer = null;
      await _attemptConnect();
    });
  }

  void _setStatus(WebSocketConnectionState next) {
    if (_status == next) {
      return;
    }
    _status = next;
    _statusController.add(next);
  }
}
