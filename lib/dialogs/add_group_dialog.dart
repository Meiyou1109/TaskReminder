import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/task_service.dart';

Future<void> showAddGroupDialog(BuildContext context, TaskService taskService) async {
  final TextEditingController controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tạo nhóm mới'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Tên nhóm'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              taskService.addGroup(
                Group(id: DateTime.now().toIso8601String(), name: name),
              );
            }
            Navigator.pop(context);
          },
          child: const Text('Tạo'),
        ),
      ],
    ),
  );
}
