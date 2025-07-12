import 'package:flutter/material.dart';
import '../models/list_model.dart';
import '../services/task_service.dart';

Future<void> showAddListDialog(BuildContext context, TaskService taskService, {String? groupId}) async {
  final TextEditingController controller = TextEditingController();
  String? selectedGroupId = groupId;

  final showDropdown = groupId == null;
  final groups = taskService.groups;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tạo danh sách mới'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Tên danh sách'),
            autofocus: true,
          ),
          if (showDropdown && groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGroupId,
              hint: const Text('Chọn nhóm (tuỳ chọn)'),
              onChanged: (value) => selectedGroupId = value,
              items: groups.map((group) {
                return DropdownMenuItem(
                  value: group.id,
                  child: Text(group.name),
                );
              }).toList(),
            ),
          ],
        ],
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
              final newList = ListModel(
                id: DateTime.now().toIso8601String(),
                name: name,
                groupId: selectedGroupId,
              );
              taskService.addList(newList);
            }
            Navigator.pop(context);
          },
          child: const Text('Tạo'),
        ),
      ],
    ),
  );
}
