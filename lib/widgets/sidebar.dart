import 'dart:async';
import 'package:flutter/material.dart';
import '../dialogs/add_group_dialog.dart';
import '../dialogs/add_list_dialog.dart';
import '../models/group.dart';
import '../models/list_model.dart';
import '../services/task_service.dart';
import '../services/event_bus_service.dart';
import '../services/task_events.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';



class Sidebar extends StatefulWidget {
  final Function(String) onTabSelected;
  final TaskService taskService;
  final bool isFullScreen;

  const Sidebar({super.key, required this.onTabSelected, required this.taskService, this.isFullScreen = false,});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  FocusNode _searchFocusNode = FocusNode();
  final Set<String> expandedGroups = {};
  late final StreamSubscription _eventSub;
  bool _showLogout = false;
  final ScrollController _scrollController = ScrollController();
  // ignore: unused_field
  bool _canScrollUp = false;
  // ignore: unused_field
  bool _canScrollDown = false;
  

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _searchFocusNode = FocusNode();
  
    _eventSub = EventBusService.onAny([
      GroupAddedEvent,
      ListAddedEvent,
      ListUpdatedEvent,
    ]).listen((_) {
      setState(() {});
      refreshScrollState(); 
    });

    refreshScrollState();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _eventSub.cancel();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    setState(() {
      _canScrollUp = offset > 5;
      _canScrollDown = offset < max - 5;
    });
  }

  void refreshScrollState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollIndicators();
    });
  }

  void _showLogoutMenu(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
  
    if (!context.mounted || confirm != true) return;
  
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
  
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final scale = isAndroid ? screen.width / 360.0 : 1.0;
    final sidebarWidth = isAndroid ? screen.width : 270.0;

    final groups = widget.taskService.groups;
    final lists = widget.taskService.lists;
    final user = FirebaseAuth.instance.currentUser;
  
   return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () {
      if (_showLogout) {
        setState(() => _showLogout = false);
      }
    },
    child: Container(
      width: widget.isFullScreen ? screen.width : sidebarWidth,
      height: widget.isFullScreen ? screen.height : null,
      color: Colors.black87,
      child: Stack(
        children: [
          Column(
            children: [
              // PHẦN TRÊN: Avatar + search + tab
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null)
                      Row(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() => _showLogout = !_showLogout),
                              child: CircleAvatar(
                                radius: 30 * scale,
                                backgroundColor: Colors.grey[700],
                                backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty)
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                                child: (user.photoURL == null || user.photoURL!.isEmpty)
                                    ? const Icon(Icons.person, size: 30, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email ?? '',
                                    style: TextStyle(color: Colors.white70, fontSize: 12 * scale)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      onTap: () {
                        _searchFocusNode.unfocus();
                        Future.delayed(const Duration(milliseconds: 1), () {
                          _searchFocusNode.requestFocus();
                        });
                      },
                      onChanged: (text) {
                        widget.onTabSelected('search:$text');
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm',
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarItem(Icons.today, 'Today'),
                    _buildSidebarItem(Icons.star, 'Important'),
                    _buildSidebarItem(Icons.calendar_month, 'Planned'),
                    _buildSidebarItem(Icons.check_circle, 'Completed'),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // PHẦN CUỘN
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    children: [
                      for (final group in groups) ...[
                        _buildGroupHeader(group, expandedGroups.contains(group.id)),
                        if (expandedGroups.contains(group.id)) ...[
                          for (final list in widget.taskService.getListsByGroup(group.id))
                            _buildListItem(list, isIndented: true),
                        ],
                      ],
                      if (lists.any((l) => l.groupId == null)) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 6 * scale),
                          child: Text("KHÔNG NHÓM",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        for (final list in lists.where((l) => l.groupId == null))
                          _buildListItem(list, isIndented: false),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // FOOTER
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black87,
              padding: EdgeInsets.all(12 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await showAddListDialog(context, widget.taskService);
                        setState(() {});
                        refreshScrollState();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Danh sách'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showAddGroupDialog(context, widget.taskService),
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('Nhóm'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // MENU ĐĂNG XUẤT
          if (_showLogout)
            Positioned(
              left: 16,
              top: 84,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.3 * 255).toInt()),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: _showSelectDueTimeDialog,
                      icon: const Icon(Icons.access_time, color: Colors.white),
                      label: const Text('Chọn giờ thông báo hàng ngày', style: TextStyle(color: Colors.white)),
                    ),
                    const Divider(height: 1, color: Colors.white24),
                    TextButton.icon(
                      onPressed: () => _showLogoutMenu(context),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => widget.onTabSelected(title),
    );
  }

  Widget _buildListItem(ListModel list, {required bool isIndented}) {
    final uncompletedCount = widget.taskService.getTasksByListId(list.id).where((t) => !t.isCompleted).length;

    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 32 : 0),
      child: GestureDetector(
        onTap: () => widget.onTabSelected(list.name),
        onSecondaryTapDown: (details) => _showListContextMenu(list, details.globalPosition),
        child: ListTile(
          leading: const Icon(Icons.list, color: Colors.white),
          title: Text(
            list.name,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uncompletedCount > 0)
                Text(
                  '$uncompletedCount',
                  style: const TextStyle(color: Colors.white),
                ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final position = renderBox.localToGlobal(Offset.zero);
                    final size = renderBox.size;
                    final menuPosition = Offset(position.dx + size.width - 20, position.dy - 8);
                    _showListContextMenu(list, menuPosition);
                  },
                  child: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(Group group, bool isExpanded) {
    return InkWell(
      onTap: () {
        setState(() {
          if (expandedGroups.contains(group.id)) {
            expandedGroups.remove(group.id);
          } else {
            expandedGroups.add(group.id);
          }
        });
        refreshScrollState();
      },
      onSecondaryTapDown: (details) => _showGroupContextMenu(group, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  group.name,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      final RenderBox renderBox = context.findRenderObject() as RenderBox;
                      final position = renderBox.localToGlobal(Offset.zero);
                      final size = renderBox.size;
                      final menuPosition = Offset(position.dx + size.width - 20, position.dy - 8);
                      _showGroupContextMenu(group, menuPosition);
                    },
                    child: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameGroupDialog(BuildContext context, Group group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tên mới'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (!mounted || newName == null || newName.isEmpty) return;
    await widget.taskService.renameGroup(group.id, newName);
    setState(() {});
  }

  Future<void> _showMoveListToGroupDialog(BuildContext context, ListModel list) async {
    final currentGroupId = list.groupId;
    final otherGroups = widget.taskService.groups.where((g) => g.id != currentGroupId).toList();

    if (otherGroups.isEmpty) return;

    final selectedGroupId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Di chuyển đến nhóm'),
        children: otherGroups.map((group) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, group.id),
            child: Text(group.name),
          );
        }).toList(),
      ),
    );

    if (!mounted || selectedGroupId == null) return;

    final updatedList = ListModel(id: list.id, name: list.name, groupId: selectedGroupId);
    widget.taskService.updateList(updatedList);
    setState(() {});
  }

  void _showGroupContextMenu(Group group, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Đổi tên nhóm')),
        const PopupMenuItem(value: 'add_list', child: Text('Thêm danh sách')),
        const PopupMenuItem(value: 'delete', child: Text('Xoá nhóm')),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'rename':
        await _showRenameGroupDialog(context, group);
        break;
      case 'add_list':
        await showAddListDialog(context, widget.taskService, groupId: group.id);
        setState(() {});
        refreshScrollState();
        break;
      case 'delete':
        final hasChildList = widget.taskService.getListsByGroup(group.id).isNotEmpty;
        final confirmMessage = hasChildList 
          ? 'Nhóm này có danh sách bên trong. Danh sách sẽ được chuyển ra ngoài. Bạn có chắc chắn muốn xoá nhóm không?'
          : 'Bạn có chắc chắn muốn xoá nhóm này không?';
          
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xoá nhóm'),
            content: Text(confirmMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
            ],
          ),
        );

        if (!mounted || confirm != true) return;

        await widget.taskService.deleteGroup(group.id);
        setState(() {});
        refreshScrollState();
        break;
    }
  }

  void _showListContextMenu(ListModel list, Offset position) async {
    final currentGroupId = list.groupId;
    final otherGroups = widget.taskService.groups.where((g) => g.id != currentGroupId).toList();

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Đổi tên danh sách')),
        if (otherGroups.isNotEmpty)
          const PopupMenuItem(value: 'move', child: Text('Di chuyển đến...')),
        if (currentGroupId != null)
          const PopupMenuItem(value: 'remove_from_group', child: Text('Loại khỏi nhóm')),
        const PopupMenuItem(value: 'delete', child: Text('Xoá danh sách')),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'rename':
        final controller = TextEditingController(text: list.name);
        final newName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đổi tên danh sách'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Tên mới'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
              ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) Navigator.pop(ctx, name);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );

        if (!mounted || newName == null || newName.isEmpty) return;

        widget.taskService.updateList(ListModel(id: list.id, name: newName, groupId: list.groupId));
        setState(() {});
        refreshScrollState();
        break;

      case 'move':
        await _showMoveListToGroupDialog(context, list);
        refreshScrollState();
        break;

      case 'remove_from_group':
        widget.taskService.updateList(list.copyWith(groupId: null));
        setState(() {});
        refreshScrollState();
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xoá danh sách'),
            content: const Text('Bạn có chắc chắn muốn xoá danh sách này không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
            ],
          ),
        );

        if (!mounted || confirm != true) return;

        await widget.taskService.removeList(list.id);
        widget.onTabSelected("Today");
        setState(() {});
        refreshScrollState();
        break;
    }
  }
  Future<void> _showSelectDueTimeDialog() async {
    final current = await _getSavedDueTime();
    if (!mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (!mounted || picked == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('due_hour', picked.hour);
    await prefs.setInt('due_minute', picked.minute);

    await NotificationService.scheduleDailyDueToday();

    if (!mounted) return;
    setState(() {});
  }

  Future<TimeOfDay?> _getSavedDueTime() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('due_hour') || !prefs.containsKey('due_minute')) return null;
  return TimeOfDay(hour: prefs.getInt('due_hour')!, minute: prefs.getInt('due_minute')!);
}



}
