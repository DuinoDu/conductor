import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/tasks/task_list_page.dart';
import 'providers.dart';
import 'ws/ws_event_handler.dart';

class ConductorApp extends ConsumerWidget {
  const ConductorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(wsEventListenerProvider);
    return MaterialApp(
      title: 'Conductor',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const TaskListPage(),
    );
  }
}
