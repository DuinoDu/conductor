import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../models/project.dart';
import '../../models/task.dart';
import '../../ws/message_stream_provider.dart';
import '../../ws/ws_client.dart';
import '../projects/create_project_dialog.dart';
import '../projects/project_list_controller.dart';
import 'create_task_dialog.dart';
import 'task_detail_page.dart';
import 'task_list_controller.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskListProvider);
    ref.watch(projectListProvider);
    final unreadTasks = ref.watch(unreadTaskProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const _ConnectionStatusBanner(),
          const _ProjectFilterBar(),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed: $error')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks yet'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(taskListProvider.notifier).reload(),
                  child: ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final hasUnread = unreadTasks.contains(task.id);
                      final createdLabel =
                          DateFormat.yMMMd().add_Hm().format(task.createdAt);
                      return ListTile(
                        title: Text(task.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Status: ${task.status}'),
                            Text(
                              'Created $createdLabel',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: hasUnread ? const _UnreadDot() : null,
                        onTap: () {
                          ref
                              .read(unreadTaskProvider.notifier)
                              .markRead(task.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailPage(
                                  taskId: task.id, title: task.title),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _CreateAction { project, task }

Future<void> _showCreateOptions(BuildContext context, WidgetRef ref) async {
  final action = await showModalBottomSheet<_CreateAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Create Project'),
            onTap: () => Navigator.of(ctx).pop(_CreateAction.project),
          ),
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Create Task'),
            onTap: () => Navigator.of(ctx).pop(_CreateAction.task),
          ),
        ],
      ),
    ),
  );
  switch (action) {
    case _CreateAction.project:
      await _handleCreateProject(context, ref);
      break;
    case _CreateAction.task:
      await _handleCreateTask(context, ref);
      break;
    default:
      break;
  }
}

Future<void> _handleCreateProject(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final project = await showDialog<Project>(
    context: context,
    builder: (_) => const CreateProjectDialog(),
  );
  if (project != null) {
    messenger.showSnackBar(
      SnackBar(content: Text('Project "${project.name}" created')),
    );
    await ref.read(projectListProvider.notifier).reload();
  }
}

Future<void> _handleCreateTask(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final task = await showDialog<Task>(
    context: context,
    builder: (_) => const CreateTaskDialog(),
  );
  if (task != null) {
    messenger.showSnackBar(
      SnackBar(content: Text('Task "${task.title}" created')),
    );
    await ref.read(taskListProvider.notifier).reload();
    if (!context.mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(taskId: task.id, title: task.title),
      ),
    );
  }
}

class _ProjectFilterBar extends ConsumerWidget {
  const _ProjectFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    final selected = ref.watch(currentProjectFilterProvider);

    return projects.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final entries = [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All Projects'),
          ),
          ...items.map(
            (project) => DropdownMenuItem<String?>(
              value: project.id,
              child: Text(project.name),
            ),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text('Project:'),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: selected,
                  items: entries,
                  onChanged: (value) {
                    ref.read(currentProjectFilterProvider.notifier).state =
                        value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.circle, color: Colors.redAccent, size: 10);
  }
}

class _ConnectionStatusBanner extends ConsumerWidget {
  const _ConnectionStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(wsConnectionStatusProvider);
    return status.when(
      data: (state) => _StatusRow(state: state),
      loading: () =>
          const _StatusRow(state: WebSocketConnectionState.connecting),
      error: (_, __) =>
          const _StatusRow(state: WebSocketConnectionState.disconnected),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final WebSocketConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _mapState(state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  (Color, String) _mapState(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return (Colors.green, 'Backend: Connected');
      case WebSocketConnectionState.connecting:
        return (Colors.orange, 'Backend: Connecting...');
      case WebSocketConnectionState.disconnected:
        return (Colors.red, 'Backend: Offline');
    }
  }
}
