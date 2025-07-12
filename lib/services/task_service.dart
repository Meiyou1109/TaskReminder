import 'package:firebase_auth/firebase_auth.dart';

import '../models/task.dart';
import '../models/list_model.dart';
import '../models/group.dart';
import 'event_bus_service.dart';
import '../services/task_events.dart';
import '../helpers/repeat_helper.dart';
import 'firebase_task_service.dart';
import 'notification_service.dart';
import 'google_auth_service.dart';

class TaskService {
  final List<Task> _tasks = [];
  final List<ListModel> _lists = [];
  final List<Group> _groups = [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<ListModel> get lists => List.unmodifiable(_lists);
  List<Group> get groups => List.unmodifiable(_groups);

  // TASK
  Future<void> loadFromFirebase() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final loadedTasks = await FirebaseTaskService().getTasks(userId);
    final loadedLists = await FirebaseTaskService().loadLists();
    final loadedGroups = await FirebaseTaskService().loadGroups();

    _tasks
      ..clear()
      ..addAll(loadedTasks);
    _lists
      ..clear()
      ..addAll(loadedLists);
    _groups
      ..clear()
      ..addAll(loadedGroups);

    NotificationService.updateTasks(_tasks);
    if (GoogleAuthService().isGoogleSignedIn) {
    await GoogleAuthService().syncAllTasksToCalendar(getPlannedTasks());
  }
  }

  void addTask(Task task) {
    _tasks.add(task);
    NotificationService.updateTasks(_tasks);
    EventBusService.instance.fire(TaskAddedEvent(task));
    GoogleAuthService().syncAllTasksToCalendar([task]);
  }

  void removeTask(Task task) {
    _tasks.remove(task);
    EventBusService.instance.fire(TaskRemovedEvent(task));
  }

  void toggleComplete(Task task) {
    task.isCompleted = !task.isCompleted;

    if (task.isCompleted && task.repeat != RepeatFrequency.none) {
      final nextDate = RepeatHelper.calculateNextRepeat(task);
      if (nextDate != null) {
        final isToday = _isSameDay(nextDate, DateTime.now());
        final newTask = task.copyWith(
          id: DateTime.now().toIso8601String(),
          dueDate: nextDate,
          isCompleted: false,
          parentId: task.id,
          fromTodayTab: isToday,
        );
        _tasks.add(newTask);
        EventBusService.instance.fire(TaskAddedEvent(newTask));
      }
    }

    EventBusService.instance.fire(TaskUpdatedEvent(task));
  }

  void toggleImportant(Task task) {
    task.isImportant = !task.isImportant;
    EventBusService.instance.fire(TaskUpdatedEvent(task));
  }

  List<Task> getTodayTasks() {
    final now = DateTime.now();
    return _tasks.where((task) {
      final isDueToday = task.dueDate != null && _isSameDay(task.dueDate!, now);
      return isDueToday || task.fromTodayTab;
    }).toList();
  }

  List<Task> getImportantTasks() => _tasks.where((t) => t.isImportant).toList();

  List<Task> getPlannedTasks() {
    final planned = _tasks.where((t) => t.dueDate != null).toList();
    return filterOutFutureRepeats(planned);
  }

  List<Task> getCompletedTasks() =>
      _tasks.where((t) => t.isCompleted).toList();

  List<Task> getUncompletedTasks() =>
      _tasks.where((t) => !t.isCompleted).toList();

  List<Task> getTasksByListId(String listId) {
    return _tasks.where((t) =>
      t.listId == listId &&
      !t.listId!.startsWith('__system_')
    ).toList();
  }

  List<Task> getCompletedTasksOnly() =>
      _tasks.where((t) => t.isCompleted).toList();

  List<Task> filterOutFutureRepeats(List<Task> tasks) {
    final Map<String?, Task> latestUncompleted = {};
    final List<Task> result = [];

    for (var task in tasks) {
      if (task.isCompleted) {
        result.add(task);
      } else if (task.repeat != RepeatFrequency.none) {
        final key = task.parentId ?? task.id;
        if (!latestUncompleted.containsKey(key) ||
            (task.dueDate != null &&
                latestUncompleted[key]!.dueDate != null &&
                task.dueDate!.isBefore(latestUncompleted[key]!.dueDate!))) {
          latestUncompleted[key] = task;
        }
      } else {
        result.add(task);
      }
    }

    result.addAll(latestUncompleted.values);
    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // LIST MNG
  Future<void> addList(ListModel list) async {
    _lists.add(list);
    await FirebaseTaskService().saveList(list);
    await loadGroupsAndLists();
    EventBusService.fire(ListAddedEvent(list));
  }

  void removeList(String listId) {
    _lists.removeWhere((l) => l.id == listId);
    _tasks.removeWhere((t) => t.listId == listId);
    FirebaseTaskService().deleteList(listId);
  }

  void updateList(ListModel updatedList) {
    final index = _lists.indexWhere((l) => l.id == updatedList.id);
    if (index != -1) {
      _lists[index] = updatedList;
      FirebaseTaskService().saveList(updatedList);
      EventBusService.fire(ListUpdatedEvent(updatedList));
    }
  }

  List<ListModel> getListsByGroup(String groupId) =>
      _lists.where((l) => l.groupId == groupId).toList();

  // GROUP MNG
  Future<void> addGroup(Group group) async {
    _groups.add(group);
    await FirebaseTaskService().saveGroup(group);
    await loadGroupsAndLists();
    EventBusService.fire(GroupAddedEvent(group));
  }

  void removeGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _lists.removeWhere((l) => l.groupId == groupId);
    FirebaseTaskService().deleteGroup(groupId);
  }

  void ungroupGroup(String groupId) {
    final affectedLists = getListsByGroup(groupId).toList();
    for (final list in affectedLists) {
      _lists.remove(list);
      final newList = ListModel(id: list.id, name: list.name, groupId: null);
      _lists.add(newList);
      FirebaseTaskService().saveList(newList);
    }
    removeGroup(groupId);
  }

  void renameGroup(String groupId, String newName) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      final renamed = Group(id: groupId, name: newName);
      _groups[index] = renamed;
      FirebaseTaskService().saveGroup(renamed);
    }
  }

  Future<void> loadGroupsAndLists() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final firebase = FirebaseTaskService();

    final loadedGroups = await firebase.loadGroups();
    final loadedLists = await firebase.loadLists();

    _groups
      ..clear()
      ..addAll(loadedGroups);

    _lists
      ..clear()
      ..addAll(loadedLists);
  }

  void updateTask(Task updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _tasks[index] = updated;
      FirebaseTaskService().syncUpdateTask(updated);
      EventBusService.fire(TaskUpdatedEvent(updated));
    }
  }

  void addStepToTask(String taskId, StepModel step) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final updated = task.copyWith(steps: [...(task.steps ?? []), step]);
    _tasks[taskIndex] = updated;
    EventBusService.fire(TaskUpdatedEvent(updated));
  }

  void removeStepFromTask(String taskId, StepModel step) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final updated = task.copyWith(
      steps: (task.steps ?? []).where((s) => s.id != step.id).toList(),
    );
    _tasks[taskIndex] = updated;
    EventBusService.fire(TaskUpdatedEvent(updated));
  }

  void updateTaskNote(String taskId, String note) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final updated = _tasks[taskIndex].copyWith(note: note);
    _tasks[taskIndex] = updated;
    EventBusService.fire(TaskUpdatedEvent(updated));
  }

  void setTaskReminder(String taskId, DateTime? reminderTime) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final updated = _tasks[taskIndex].copyWith(reminderTime: reminderTime);
    _tasks[taskIndex] = updated;

    EventBusService.fire(TaskUpdatedEvent(updated));

    if (reminderTime != null) {
      await NotificationService.scheduleReminder(updated);
    } else {
      await NotificationService.cancelNotifications(updated);
    }
  }
}
