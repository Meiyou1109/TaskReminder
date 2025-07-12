import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/repeat_picker_dialog.dart';
import '../services/notification_service.dart';


class TaskDetailView extends StatefulWidget {
  final Task task;
  final TaskService taskService;
  final VoidCallback onClose;

  const TaskDetailView({
    super.key,
    required this.task,
    required this.taskService,
    required this.onClose,
  });

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  late Task _task;
  late String _initialTitle;
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _noteScroll = ScrollController();
  final Map<String, TextEditingController> _stepControllers = {};
  String? _attachedFileName;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _initialTitle = _task.title;
    _noteController.text = _task.note ?? '';
    for (final step in _task.steps ?? []) {
      _stepControllers[step.id] = TextEditingController(text: step.content);
    }
  }

  @override
  void dispose() {
    for (final controller in _stepControllers.values) {
      controller.dispose();
    }
    _noteController.dispose();
    _noteScroll.dispose();
    super.dispose();
  }

  void _toggleImportant() {
    setState(() => _task = _task.copyWith(isImportant: !_task.isImportant));
    widget.taskService.updateTask(_task);
  }

  void _updateTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _task = _task.copyWith(title: _initialTitle));
    } else {
      _initialTitle = trimmed;
      setState(() => _task = _task.copyWith(title: trimmed));
      widget.taskService.updateTask(_task);
    }
  }

  void _addStep() {
    final newStep = StepModel(id: DateTime.now().toIso8601String(), content: '', isCompleted: false);
    widget.taskService.addStepToTask(_task.id, newStep);
    setState(() {
      _task = _task.copyWith(steps: [...?_task.steps, newStep]);
      _stepControllers[newStep.id] = TextEditingController();
    });
  }

  void _removeStep(StepModel step) {
    widget.taskService.removeStepFromTask(_task.id, step);
    setState(() {
      _task = _task.copyWith(steps: _task.steps!.where((s) => s.id != step.id).toList());
      _stepControllers.remove(step.id)?.dispose();
    });
  }

  void _toggleStep(StepModel step) {
    final updated = step.copyWith(isCompleted: !step.isCompleted);
    final index = _task.steps!.indexWhere((s) => s.id == step.id);
    final steps = [..._task.steps!];
    steps[index] = updated;
    setState(() => _task = _task.copyWith(steps: steps));
    widget.taskService.updateTask(_task);
  }

  void _updateStepContent(StepModel step, String content) {
    final updated = step.copyWith(content: content);
    final index = _task.steps!.indexWhere((s) => s.id == step.id);
    final steps = [..._task.steps!];
    steps[index] = updated;
    setState(() => _task = _task.copyWith(steps: steps));
    widget.taskService.updateTask(_task);
  }

  void _updateNote(String value) {
    widget.taskService.updateTaskNote(_task.id, value);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted || time == null) return;

    final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    widget.taskService.setTaskReminder(_task.id, result);
    setState(() => _task = _task.copyWith(reminderTime: result));
    await NotificationService.scheduleReminder(_task);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;

    final updated = _task.copyWith(dueDate: picked);
    widget.taskService.updateTask(updated);
    setState(() => _task = updated);
  }

  Future<void> _pickRepeat() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => RepeatPickerDialog(
        initialFrequency: _task.repeat,
        initialEvery: _task.repeatEvery,
        initialWeekdays: _task.repeatWeekdays ?? [],
      ),
    );
    if (!mounted || result == null) return;

    final updated = _task.copyWith(
      repeat: result['repeat'],
      repeatEvery: result['every'],
      repeatWeekdays: result['weekdays'],
    );
    widget.taskService.updateTask(updated);
    setState(() => _task = updated);
  }

  Future<void> _pickAttachment() async {
    final typeGroup = const XTypeGroup(label: 'Tất cả tệp');
    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (!mounted || file == null) return;

    setState(() => _attachedFileName = file.name);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã chọn: ${file.name}')),
    );
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tác vụ'),
        content: const Text('Bạn có chắc chắn muốn xoá tác vụ này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    widget.taskService.removeTask(_task);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus) _updateTitle(_task.title);
                        },
                        child: TextFormField(
                          initialValue: _task.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          onChanged: (value) => _task = _task.copyWith(title: value),
                          onFieldSubmitted: _updateTitle,
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _task.isImportant ? Icons.star : Icons.star_border,
                        color: _task.isImportant ? Colors.orange : Colors.grey,
                      ),
                      onPressed: _toggleImportant,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _updateTitle(_task.title);
                        widget.onClose();
                      },
                    ),
                  ],
                ),
                const Divider(),
    
                if ((_task.steps?.isNotEmpty ?? false))
                  ..._task.steps!.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: s.isCompleted,
                          onChanged: (_) => _toggleStep(s),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _stepControllers[s.id],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              hintText: 'Bước chưa đặt tên',
                            ),
                            onSubmitted: (value) => _updateStepContent(s, value),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          onPressed: () => _removeStep(s),
                        ),
                      ],
                    ),
                  )),
    
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm bước'),
                ),
    
                const Divider(),
    
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: const Text('Nhắc nhở'),
                  subtitle: Text(
                    _task.reminderTime != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(_task.reminderTime!)
                        : 'Chưa đặt',
                  ),
                  onTap: _pickReminder,
                ),
    
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Hạn'),
                  subtitle: Text(
                    _task.dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(_task.dueDate!)
                        : 'Chưa đặt',
                  ),
                  onTap: _pickDeadline,
                ),
    
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Lặp lại'),
                  subtitle: Text(
                    _task.repeat != RepeatFrequency.none
                        ? _task.repeat.name
                        : 'Không lặp',
                  ),
                  onTap: _pickRepeat,
                ),
    
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Đính kèm tệp'),
                  subtitle: _attachedFileName != null ? Text('📎 $_attachedFileName') : null,
                  onTap: _pickAttachment,
                ),
    
                const Divider(),
    
                const Text('Ghi chú:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: Scrollbar(
                    controller: _noteScroll,
                    child: TextField(
                      controller: _noteController,
                      scrollController: _noteScroll,
                      onChanged: _updateNote,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Thêm ghi chú...',
                        fillColor: Colors.grey.shade100,
                        filled: true,
                      ),
                    ),
                  ),
                ),
    
                const SizedBox(height: 16),
    
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tạo: ${DateFormat('HH:mm dd/MM/yyyy').format(_task.createdAt ?? DateTime.now())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: _deleteTask,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
