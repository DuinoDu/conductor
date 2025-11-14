import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project.dart';
import '../../models/task.dart';
import '../projects/project_list_controller.dart';
import 'task_list_controller.dart';

class CreateTaskDialog extends ConsumerStatefulWidget {
  const CreateTaskDialog({super.key});

  @override
  ConsumerState<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedProjectId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectListProvider);
    return AlertDialog(
      title: const Text('Create Task'),
      content: projects.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('Failed to load projects: $error'),
        data: (items) => _buildForm(context, items),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, List<Project> projects) {
    if (projects.isEmpty) {
      return const Text('Create a project before creating tasks.');
    }
    _selectedProjectId ??= projects.first.id;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedProjectId,
            items: projects
                .map(
                  (project) => DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() {
              _selectedProjectId = value;
            }),
            decoration: const InputDecoration(labelText: 'Project'),
          ),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Task title'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Title required' : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedProjectId == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(taskListProvider.notifier);
      final task = await notifier.createTask(
        projectId: _selectedProjectId!,
        title: _titleController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop<Task>(task);
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
