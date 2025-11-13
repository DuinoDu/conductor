import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'ws_client.dart';

final wsClientProvider = Provider<AppWebSocketClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final uri = Uri.parse(config.baseUrl.replaceFirst('http', 'ws') + '/ws/app');
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

  final sub = client.messages.listen(controller.add, onError: controller.addError);
  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
    await client.dispose();
  });

  return controller.stream;
});
