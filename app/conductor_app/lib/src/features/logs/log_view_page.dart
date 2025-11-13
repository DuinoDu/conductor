import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/log_entry.dart';

final logEntriesProvider = StateProvider.family<List<LogEntry>, String>((ref, taskId) => const []);

class LogViewPage extends ConsumerWidget {
  const LogViewPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logEntriesProvider(taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final entry = logs[index];
          Color? color;
          switch (entry.level) {
            case 'ERROR':
              color = Colors.red[100];
              break;
            case 'WARN':
              color = Colors.orange[100];
              break;
            default:
              color = Colors.green[100];
          }
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(entry.message),
          );
        },
      ),
    );
  }
}
