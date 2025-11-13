import 'package:flutter/material.dart';

import '../chat/chat_page.dart';
import '../logs/log_view_page.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId, required this.title});

  final String taskId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Logs')]),
        ),
        body: TabBarView(
          children: [ChatPage(taskId: taskId), LogViewPage(taskId: taskId)],
        ),
      ),
    );
  }
}
