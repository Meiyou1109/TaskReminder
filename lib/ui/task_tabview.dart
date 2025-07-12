import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/event_bus_service.dart';
import '../services/task_events.dart';
import '../widgets/task_item.dart';

class TaskTabView extends StatelessWidget {
  final String currentTab;
  final TaskService taskService;

  const TaskTabView({
    super.key,
    required this.currentTab,
    required this.taskService,
  });

  List<Task> _getTasks() {
  switch (currentTab) {
    case 'Today':
      return taskService.getTodayTasks();
    case 'Important':
      return taskService.getImportantTasks();
    case 'Planned':
      return taskService.getPlannedTasks();
    case 'Completed':
      return taskService.getCompletedTasks();
    default:
      try {
        final list = taskService.lists.firstWhere((l) => l.name == currentTab);
        return taskService.getTasksByListId(list.id);
      } catch (_) {
        return [];
      }
  }
}


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
      stream: EventBusService.onAny([
        TaskAddedEvent,
        TaskUpdatedEvent,
        TaskRemovedEvent,
      ]),
      builder: (context, snapshot) {
        final tasks = _getTasks();

        return tasks.isEmpty
            ? const Center(child: Text("Không có công việc nào"))
            : ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskItem(
                    task: task,
                    onToggleCompleted: () => taskService.toggleComplete(task),
                    onToggleImportant: () => taskService.toggleImportant(task),
                    taskService: taskService,
                  );
                },
              );
      },
    );
  }
}
