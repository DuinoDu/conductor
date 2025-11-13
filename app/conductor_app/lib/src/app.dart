import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/tasks/task_list_page.dart';

class ConductorApp extends StatelessWidget {
  const ConductorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Conductor',
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const TaskListPage(),
      ),
    );
  }
}
