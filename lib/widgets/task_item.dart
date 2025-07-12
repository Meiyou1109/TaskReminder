import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/draw_text.dart';
import '../services/event_bus_service.dart';
import '../services/task_events.dart';

class TaskItem extends StatefulWidget {
  final Task task;
  final VoidCallback onToggleCompleted;
  final VoidCallback onToggleImportant;
  final TaskService taskService;
  final bool isActive;
  final VoidCallback? onTap;


  const TaskItem({
    super.key,
    required this.task,
    required this.onToggleCompleted,
    required this.onToggleImportant,
    required this.taskService,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _isHovered = false;

  String? _buildRepeatDescription() {
    final task = widget.task;
    if (task.repeat == RepeatFrequency.none) return null;

    switch (task.repeat) {
      case RepeatFrequency.daily:
        return task.repeatEvery == 1
            ? 'Lặp hàng ngày'
            : 'Lặp mỗi ${task.repeatEvery} ngày';
      case RepeatFrequency.weekly:
        if (task.repeatWeekdays == null || task.repeatWeekdays!.isEmpty) {
          return 'Lặp hàng tuần';
        }
        final weekdayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
        final names = task.repeatWeekdays!.map((d) => weekdayNames[d % 7]).join(', ');
        return task.repeatEvery == 1
            ? 'Lặp hàng tuần vào $names'
            : 'Lặp mỗi ${task.repeatEvery} tuần vào $names';
      case RepeatFrequency.monthly:
        return task.repeatEvery == 1
            ? 'Lặp hàng tháng'
            : 'Lặp mỗi ${task.repeatEvery} tháng';
      case RepeatFrequency.yearly:
        return task.repeatEvery == 1
            ? 'Lặp hàng năm'
            : 'Lặp mỗi ${task.repeatEvery} năm';
      case RepeatFrequency.custom:
        return 'Lặp tuỳ chỉnh';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final textStyle = TextStyle(
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      color: task.isCompleted ? Colors.grey : null,
    );

    final reminderText = task.reminderTime != null
        ? ' ${DateFormat('dd/MM HH:mm').format(task.reminderTime!)}'
        : null;
    final repeatText = _buildRepeatDescription();
    final steps = task.steps ?? [];
    final totalSteps = steps.length;
    final completedSteps = steps.where((s) => s.isCompleted).length;
    final stepProgress = totalSteps > 0 ? '$completedSteps/$totalSteps bước' : null;

    final backgroundColor = (_isHovered || widget.isActive)
        ? Colors.grey.shade100
        : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () => EventBusService.fire(TaskSelectedEvent(task)),
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => widget.onToggleCompleted(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    drawText(
                      task.title,
                      style: textStyle.copyWith(fontSize: 15),
                    ),
                    if (task.dueDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '🗓 ${DateFormat('dd/MM/yyyy').format(task.dueDate!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    if (reminderText != null || repeatText != null || stepProgress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (reminderText != null)
                              Text(
                                reminderText,
                                style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade600),
                              ),
                            if (reminderText != null && repeatText != null)
                              const SizedBox(width: 6),
                            if (repeatText != null)
  Flexible(
    child: Text(
      repeatText,
      style: TextStyle(fontSize: 12, color: Colors.teal.shade600),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  ),

                            if ((reminderText != null || repeatText != null) && stepProgress != null)
                              const SizedBox(width: 6),
                            if (stepProgress != null)
                              Text(
                                ' $stepProgress',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  task.isImportant ? Icons.star : Icons.star_border,
                  color: task.isImportant ? Colors.orange : Colors.grey,
                ),
                onPressed: widget.onToggleImportant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'move', child: Text('Di chuyển tác vụ đến...')),
        PopupMenuItem(value: 'delete', child: Text('Xoá tác vụ')),
      ],
    );

    if (!context.mounted || selected == null) return;

    switch (selected) {
      case 'move':
        await _handleMoveTask(context);
        break;
      case 'delete':
        await _handleDeleteTask(context);
        break;
    }
  }

  Future<void> _handleDeleteTask(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tác vụ'),
        content: const Text('Bạn có chắc muốn xoá tác vụ này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
        ],
      ),
    );

    if (!context.mounted || confirm != true) return;
    widget.taskService.removeTask(widget.task);
  }

  Future<void> _handleMoveTask(BuildContext context) async {
    final lists = widget.taskService.lists.where((l) => !l.id.startsWith('__system_')).toList();

    final selectedListId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Chọn danh sách'),
        children: lists.map((list) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, list.id),
            child: Text(list.name),
          );
        }).toList(),
      ),
    );

    if (!context.mounted || selectedListId == null || selectedListId == widget.task.listId) return;

    final updatedTask = widget.task.copyWith(listId: selectedListId);
    widget.taskService.removeTask(widget.task);
    widget.taskService.addTask(updatedTask);
  }
}
