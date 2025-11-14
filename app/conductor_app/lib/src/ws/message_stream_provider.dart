import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'ws_client.dart';

final wsClientProvider = Provider<AppWebSocketClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final uri = _resolveWsUri(config.baseUrl, config.wsUrl);
  final client = AppWebSocketClient(uri: uri);
  ref.onDispose(client.dispose);
  return client;
});

final wsMessageStreamProvider = StreamProvider.autoDispose((ref) {
  final client = ref.watch(wsClientProvider);
  final controller = StreamController<dynamic>();

  scheduleMicrotask(() async {
    await client.connect();
  });

  final sub =
      client.messages.listen(controller.add, onError: controller.addError);
  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });

  return controller.stream;
});

Uri _resolveWsUri(String baseUrl, String? explicitWsUrl) {
  if (explicitWsUrl != null && explicitWsUrl.isNotEmpty) {
    return Uri.parse(explicitWsUrl);
  }
  final baseUri = Uri.parse(baseUrl);
  final scheme = baseUri.scheme.toLowerCase() == 'https' ? 'wss' : 'ws';
  final normalizedPath = baseUri.path.endsWith('/')
      ? '${baseUri.path}ws/app'
      : '${baseUri.path}/ws/app';
  return baseUri.replace(
    scheme: scheme,
    path: normalizedPath,
    query: null,
    fragment: null,
  );
}

final wsConnectionStatusProvider =
    StreamProvider.autoDispose<WebSocketConnectionState>((ref) {
  final client = ref.watch(wsClientProvider);
  scheduleMicrotask(() async {
    await client.connect();
  });
  return client.statusStream;
});
