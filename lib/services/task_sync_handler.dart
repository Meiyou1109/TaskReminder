import 'package:event_bus/event_bus.dart';
import 'firebase_task_service.dart';
import 'task_events.dart';

final _firebaseService = FirebaseTaskService();

void registerTaskSyncHandler(EventBus eventBus) {
  eventBus.on<TaskAddedEvent>().listen((event) {
    _firebaseService.syncAddTask(event.task);
  });

  eventBus.on<TaskUpdatedEvent>().listen((event) {
    _firebaseService.syncUpdateTask(event.task);
  });

  eventBus.on<TaskRemovedEvent>().listen((event) {
    _firebaseService.syncDeleteTask(event.task);
  });
}
