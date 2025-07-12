import 'package:flutter/foundation.dart';
import '../services/event_bus_service.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../services/task_events.dart';

void registerTaskNotificationHandler(TaskService taskService) {
  final bus = EventBusService.instance;

  // Lên lịch reminder
  bus.on<TaskAddedEvent>().listen((event) {
    NotificationService.scheduleReminder(event.task);
  });

  bus.on<TaskUpdatedEvent>().listen((event) {
    NotificationService.cancelNotifications(event.task);
    NotificationService.scheduleReminder(event.task);
  });

  bus.on<TaskRemovedEvent>().listen((event) {
    NotificationService.cancelNotifications(event.task);
  });

  // Đồng bộ lại notifi mỗi day
  EventBusService.on<TaskEvent>().listen((event) async {
    debugPrint('TaskEvent triggered: ${event.runtimeType}');
    NotificationService.updateTasks(taskService.tasks);
    await NotificationService.scheduleDailyDueToday();
  });
}

