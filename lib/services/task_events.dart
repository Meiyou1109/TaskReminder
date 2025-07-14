import '../../models/task.dart';
import '../../models/group.dart';
import '../../models/list_model.dart';

// TASK EVENTS

abstract class TaskEvent {
  final Task task;
  const TaskEvent(this.task);
}

class TaskAddedEvent extends TaskEvent {
  const TaskAddedEvent(super.task);
}

class TaskRemovedEvent extends TaskEvent {
  const TaskRemovedEvent(super.task);
}

class TaskUpdatedEvent extends TaskEvent {
  const TaskUpdatedEvent(super.task);
}

class TaskSelectedEvent extends TaskEvent {
  const TaskSelectedEvent(super.task);
}

// LIST / GROUP EVENTS

class GroupAddedEvent {
  final Group group;
  const GroupAddedEvent(this.group);
}

class GroupRemovedEvent {
  final String groupId;
  const GroupRemovedEvent(this.groupId);
}

class GroupUpdatedEvent {
  final Group group;
  const GroupUpdatedEvent(this.group);
}

class ListAddedEvent {
  final ListModel list;
  const ListAddedEvent(this.list);
}

class ListUpdatedEvent {
  final ListModel list;
  const ListUpdatedEvent(this.list);
}

class ListRemovedEvent {
  final String listId;
  const ListRemovedEvent(this.listId);
}
