import 'dart:async';

import 'package:conductor_app/src/ws/ws_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeSink implements WebSocketSink {
  final _sent = <dynamic>[];
  final _done = Completer<void>();

  List<dynamic> get sent => _sent;

  @override
  void add(dynamic data) {
    _sent.add(data);
  }

  @override
  Future addStream(Stream stream) => stream.forEach(add);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future get done => _done.future;
}

class FakeChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  FakeChannel(this.controller) : sinkImpl = FakeSink();

  final StreamController<dynamic> controller;
  final FakeSink sinkImpl;

  @override
  Stream get stream => controller.stream;

  @override
  WebSocketSink get sink => sinkImpl;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

void main() {
  test('AppWebSocketClient forwards incoming messages', () async {
    final controller = StreamController<dynamic>();
    final client = AppWebSocketClient(
      uri: Uri.parse('ws://localhost:1234'),
      channelFactory: (_) => FakeChannel(controller),
    );

    await client.connect();
    controller.add('hello');
    expect(await client.messages.first, 'hello');
    await client.dispose();
  });

  test('AppWebSocketClient sends data through sink', () async {
    final controller = StreamController<dynamic>();
    final fakeChannel = FakeChannel(controller);
    final client = AppWebSocketClient(
      uri: Uri.parse('ws://localhost:1234'),
      channelFactory: (_) => fakeChannel,
    );

    await client.connect();
    client.send({'ping': true});
    expect(fakeChannel.sinkImpl.sent.single, {'ping': true});
    await client.dispose();
  });
}
