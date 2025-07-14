import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/list_model.dart';
import '../services/task_service.dart';
import '../services/event_bus_service.dart';
import '../services/task_events.dart';
import '../widgets/sidebar.dart';
import '../widgets/task_item.dart';
import '../widgets/smart_scroll_wrapper.dart';
import '../widgets/repeat_picker_dialog.dart';
import '../widgets/task_detail_view.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import '../services/google_auth_service.dart';




enum SortType {
  none,
  importance,
  createdDate,
  alphabet,
  dueDate,
}

enum PopupAction {
  sort,
  theme,
  view,
  connectGoogle,
}

enum AndroidView { sidebar, taskList, taskDetail }

bool isAndroid(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.android;


class HomePage extends StatefulWidget {
  final TaskService taskService;

  const HomePage({super.key, required this.taskService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showCalendarInPlanned = false;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  Task? _currentTaskDetail;
  late final TaskService _taskService;
  late final StreamSubscription _taskSubscription;
  late final StreamSubscription _taskSelectedSubscription;
  final ScrollController _scrollController = ScrollController();

  final Map<String, SortType> _sortTypes = {};
  final Map<String, Color> _backgroundColors = {};
  final Map<String, bool> _sortAsc = {};

  AndroidView currentAndroidView = AndroidView.taskList;

  String currentTab = 'Today';
  String? _searchQuery;
  String? currentListId;
  List<Task> _tasks = [];
  final Map<String, bool> _expandedSections = {
    'before': true,
    'today': true,
    'tomorrow': true,
    'range': true,
    'later': true,
  };

  String get effectiveKey {
    final id = currentListId;
    return (id != null && id.isNotEmpty) ? id : currentTab;
  }


  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _taskService = widget.taskService;

    Future.microtask(() async {
      await _loadSavedColors();
      await _taskService.loadFromFirebase();
      if (!mounted) return;
      setState(() {
        _loadTasks();
      });
    });

    _taskSubscription = EventBusService.on<TaskEvent>().listen((event) {
      if (!mounted) return;
      setState(() {
        _loadTasks();
      });
    });

    _taskSelectedSubscription = EventBusService.on<TaskSelectedEvent>().listen((event) {
      if (!mounted) return;
      final selected = event.task;
      setState(() {
        if (_currentTaskDetail?.id == selected.id) {
          _currentTaskDetail = null;
        } else {
          _currentTaskDetail = selected;

          if (currentTab == 'SearchResult' && _searchQuery != null) {
            _tasks = _taskService.tasks
                .where((t) => t.title.toLowerCase().contains(_searchQuery!))
                .toList();
          } else {
            _loadTasks();
          }
        }
      });
    });
  }

  void _loadTasks() {
    if (currentListId != null) {
      _tasks = _taskService.filterOutFutureRepeats(
        _taskService.getTasksByListId(currentListId!),
      );
    } else {
      switch (currentTab) {
        case 'Today':
          _tasks = _taskService.filterOutFutureRepeats(_taskService.getTodayTasks());
          break;
        case 'Important':
          _tasks = _taskService.filterOutFutureRepeats(_taskService.getImportantTasks());
          break;
        case 'Planned':
          _tasks = _taskService.filterOutFutureRepeats(_taskService.getPlannedTasks());
          break;
        case 'Completed':
          _tasks = _taskService.getCompletedTasks();
          break;
        default:
          _tasks = _taskService.tasks;
      }
    }

    final key = currentListId ?? currentTab;
    final sortType = _sortTypes[key] ?? SortType.none;
    final isAsc = _sortAsc[key] ?? true;

    _tasks = _applySort(_tasks, sortType, isAsc);
  }


  List<Task> _applySort(List<Task> tasks, SortType type, bool asc) {
    final sorted = [...tasks];

    switch (type) {
      case SortType.importance:
        sorted.sort((a, b) => (b.isImportant ? 1 : 0).compareTo(a.isImportant ? 1 : 0));
        break;

      case SortType.createdDate:
        sorted.sort((a, b) => (a.createdAt ?? DateTime.now())
            .compareTo(b.createdAt ?? DateTime.now()));
        break;

      case SortType.alphabet:
        sorted.sort((a, b) {
          final normalizedA = _normalize(a.title);
          final normalizedB = _normalize(b.title);
          return normalizedA.compareTo(normalizedB);
        });
        break;

      case SortType.dueDate:
        sorted.sort((a, b) {
          final da = a.dueDate;
          final db = b.dueDate;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        break;

      case SortType.none:
        return tasks;
    }

    return asc ? sorted : sorted.reversed.toList();
  }


void _showThemePickerDialog() {
  final colors = [
    '#A0D9C9', '#DFC7C1', '#F4DCD6', '#B2D9EA', '#84B4C8', '#619196', '#B8A0D9', '#91D9BF',
    '#B5DDD1', '#D7E7A9', '#D3C0F9', '#F99A9C', '#FDBCCF', '#DFF2EB', '#ACB7F2', '#F2E2DC',
  ];
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Chọn chủ đề cho tab này'),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: colors.map((hex) {
            final color = Color(int.parse('0xff${hex.substring(1)}'));
            return GestureDetector(
              onTap: () {
                final key = currentListId ?? currentTab;
                _backgroundColors[key] = color;
                _saveColors();
                Navigator.of(context).pop();
                setState(() {});
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

Future<void> _loadSavedColors() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('tab_colors');
  if (jsonString != null) {
    final Map<String, dynamic> colorMap = jsonDecode(jsonString);
    _backgroundColors.clear();
    colorMap.forEach((key, value) {
      _backgroundColors[key] = Color(value);
    });
    if (mounted) setState(() {});
  }
}

Future<void> _saveColors() async {
  final prefs = await SharedPreferences.getInstance();
  // ignore: deprecated_member_use
  final colorMap = _backgroundColors.map((key, color) => MapEntry(key, color.value));
  await prefs.setString('tab_colors', jsonEncode(colorMap));
}

void _handleTabChange(String tab) {
  final isSearchMode = tab.startsWith('search:');
  final searchTerm = isSearchMode ? tab.substring(7).trim().toLowerCase() : null;

  if (!isSearchMode && (tab != currentTab || currentListId != _getListIdIfCustom(tab))) {
    if (_currentTaskDetail != null) {
      setState(() => _currentTaskDetail = null);
    }
  }

  setState(() {
    if (isSearchMode) {
      currentTab = 'SearchResult';
      currentListId = null;
      _searchQuery = searchTerm;
      _tasks = _taskService.tasks
          .where((t) => _normalize(t.title).contains(_normalize(_searchQuery!)))
          .toList();
    } else {
      _searchQuery = null;
      currentTab = tab;
      currentListId = _getListIdIfCustom(tab);
      _loadTasks();
    }
  });
  if (Theme.of(context).platform == TargetPlatform.windows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }
}

  String? _getListIdIfCustom(String tabName) {
    final lists = _taskService.lists;
    final found = lists.firstWhere(
      (l) => l.name == tabName,
      orElse: () => ListModel(id: '', name: '', groupId: null),
    );
    return found.id.isNotEmpty ? found.id : null;
  }

  void _handleAddTask({
    required String title,
    DateTime? dueDate,
    DateTime? reminderTime,
    RepeatFrequency repeat = RepeatFrequency.none,
    int repeatEvery = 1,
    List<int>? repeatWeekdays,
  }) {
    if (title.trim().isEmpty) return;

    final task = Task(
      id: DateTime.now().toIso8601String(),
      title: title.trim(),
      dueDate: dueDate,
      reminderTime: reminderTime,
      repeat: repeat,
      repeatEvery: repeatEvery,
      repeatWeekdays: repeatWeekdays,
      isCompleted: false,
      isImportant: currentTab == 'Important',
      fromTodayTab: currentTab == 'Today',
      listId: currentListId,
    );

    _taskService.addTask(task);
    _taskService.setTaskReminder(task.id, reminderTime);
    
  }

  Map<String, List<Task>> _groupPlannedTasks(List<Task> tasks) {
    final Map<String, List<Task>> grouped = {
      'before': [],
      'today': [],
      'tomorrow': [],
      'range': [],
      'later': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final rangeEnd = tomorrow.add(const Duration(days: 5));

    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) continue;

      final dueDate = DateTime(due.year, due.month, due.day);
      if (dueDate.isBefore(today)) {
        grouped['before']!.add(task);
      } else if (dueDate == today) {
        grouped['today']!.add(task);
      } else if (dueDate == tomorrow) {
        grouped['tomorrow']!.add(task);
      } else if (dueDate.isAfter(tomorrow) && !dueDate.isAfter(rangeEnd)) {
        grouped['range']!.add(task);
      } else if (dueDate.isAfter(rangeEnd)) {
        grouped['later']!.add(task);
      }
    }
    return grouped;
  }

  Widget _buildPlannedTab() {
    final grouped = _groupPlannedTasks(_tasks);

    Widget section(String key, String title, List<Task> tasks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedSections[key] = !_expandedSections[key]!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(_expandedSections[key]! ? Icons.expand_more : Icons.chevron_right),
                  const SizedBox(width: 4),
                  Text('$title (${tasks.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (_expandedSections[key]!)
            ...tasks.map((task) => TaskItem(
              task: task,
              onToggleCompleted: () => _taskService.toggleComplete(task),
              onToggleImportant: () => _taskService.toggleImportant(task),
              taskService: _taskService,
              isActive: _currentTaskDetail?.id == task.id,
              onTap: () {
                setState(() {
                  _currentTaskDetail = task;
                  currentAndroidView = AndroidView.taskDetail;
                });
              },
            )),
        ],
      );
    }

    final rangeLabel = grouped['range']!.isNotEmpty
        ? () {
            final sorted = grouped['range']!..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
            final first = sorted.first.dueDate!;
            final last = sorted.last.dueDate!;
            final f = DateFormat('EEE, MMM d').format(first);
            final l = DateFormat('EEE, MMM d').format(last);
            return '$f đến $l';
          }()
        : 'Trong tuần';

    return _buildTaskList([
      section('before', 'Trước đó', grouped['before']!),
      section('today', 'Hôm nay', grouped['today']!),
      section('tomorrow', 'Ngày mai', grouped['tomorrow']!),
      section('range', rangeLabel, grouped['range']!),
      section('later', 'Để sau', grouped['later']!),
    ]);
  }

  Widget _buildCompletedTab() {
    final uncompleted = _taskService.getUncompletedTasks();
    final completed = _taskService.getCompletedTasksOnly();
  
    if (uncompleted.isEmpty && completed.isEmpty) {
      return _buildTaskList([
        const Center(
          child: Text(
            'Chưa có nhiệm vụ nào',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ]);
    }

    // Áp dụng sắp xếp riêng cho từng phần
    final key = currentListId ?? currentTab;
    final sortType = _sortTypes[key] ?? SortType.none;
    final isAsc = _sortAsc[key] ?? true;

    final sortedUncompleted = _applySort(uncompleted, sortType, isAsc);
    final sortedCompleted = _applySort(completed, sortType, isAsc);
  
    final List<Widget> items = [
      ...sortedUncompleted.map((task) => TaskItem(
            task: task,
            onToggleCompleted: () => _taskService.toggleComplete(task),
            onToggleImportant: () => _taskService.toggleImportant(task),
            taskService: _taskService,
            isActive: _currentTaskDetail?.id == task.id,
            onTap: () {
              setState(() {
                _currentTaskDetail = task;
                currentAndroidView = AndroidView.taskDetail;
              });
            },
          )),
      if (sortedCompleted.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Đã hoàn thành (${sortedCompleted.length})',
            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold),
          ),
        ),
      ...sortedCompleted.map((task) => TaskItem(
            task: task,
            onToggleCompleted: () => _taskService.toggleComplete(task),
            onToggleImportant: () => _taskService.toggleImportant(task),
            taskService: _taskService,
            isActive: _currentTaskDetail?.id == task.id,
            onTap: () {
              setState(() {
                _currentTaskDetail = task;
                currentAndroidView = AndroidView.taskDetail;
              });
            },
          )),
    ];
  
    return _buildTaskList(items);
  }

  Widget _buildTaskList(List<Widget> children) {
    final key = currentListId ?? currentTab;
    final sortType = _sortTypes[key] ?? SortType.none;
    final isAsc = _sortAsc[key] ?? true;
  
    String? label;
    switch (sortType) {
      case SortType.importance: label = 'Tầm quan trọng'; break;
      case SortType.createdDate: label = 'Ngày tạo'; break;
      case SortType.alphabet: label = 'Chữ cái'; break;
      case SortType.dueDate: label = 'Ngày đến hạn'; break;
      default: label = null;
    }
  
    return Column(
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  icon: Icon(isAsc ? Icons.arrow_upward : Icons.arrow_downward),
                  label: Text('Đã sắp xếp theo $label'),
                  onPressed: () {
                    final key = currentListId ?? currentTab;
                    _sortAsc[key] = !_sortAsc[key]!;
                    setState(() => _loadTasks());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _sortTypes[key] = SortType.none;
                    setState(() => _loadTasks());
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: SmartScrollWrapper(
            controller: _scrollController,
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: QuickAddTaskBar(onSubmit: _handleAddTask),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _backgroundColors[currentListId ?? currentTab];

    if (!isAndroid(context)) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: bgColor ?? Colors.white,
        body: Row(
          children: [
            Sidebar(
              onTabSelected: _handleTabChange,
              taskService: _taskService,
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentTab == 'SearchResult' ? 'Kết quả tìm kiếm' : currentTab,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<PopupAction>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (PopupAction action) {
                            if (action == PopupAction.theme) {
                              _showThemePickerDialog();
                            }
                            else if (action == PopupAction.view && currentTab == 'Planned') {
                              setState(() {
                                _showCalendarInPlanned = !_showCalendarInPlanned;
                              });
                            }
                          },
                          itemBuilder: (context) {
                            final key = currentListId ?? currentTab;
                            final isPlanned = currentTab == 'Planned';
                            final isImportant = currentTab == 'Important';

                            return [
                              if (!isPlanned)
                                PopupMenuItem<PopupAction>(
                                  value: PopupAction.sort,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) {
                                      final key = effectiveKey;
                                      final sortType = {
                                        'importance': SortType.importance,
                                        'createdDate': SortType.createdDate,
                                        'alphabet': SortType.alphabet,
                                        'dueDate': SortType.dueDate,
                                      }[value];

                                      if (value == 'clear') {
                                        _sortTypes[key] = SortType.none;
                                      } else if (sortType != null) {
                                        if (_sortTypes[key] == sortType) {
                                          _sortAsc[key] = !(_sortAsc[key] ?? true);
                                        } else {
                                          _sortTypes[key] = sortType;
                                          _sortAsc[key] = true;
                                        }
                                      }
                                      setState(() => _loadTasks());
                                    },
                                    itemBuilder: (_) {
                                      final items = <PopupMenuEntry<String>>[];
                                      if (!isImportant) {
                                        items.add(const PopupMenuItem(
                                          value: 'importance',
                                          child: Row(
                                            children: [Icon(Icons.star_border, size: 18), SizedBox(width: 8), Text('Tầm quan trọng')],
                                          ),
                                        ));
                                      }
                                      items.addAll([
                                        const PopupMenuItem(
                                          value: 'createdDate',
                                          child: Row(
                                            children: [Icon(Icons.event, size: 18), SizedBox(width: 8), Text('Ngày tạo')],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'alphabet',
                                          child: Row(
                                            children: [Icon(Icons.sort_by_alpha, size: 18), SizedBox(width: 8), Text('Theo thứ tự bằng chữ cái')],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'dueDate',
                                          child: Row(
                                            children: [Icon(Icons.access_time, size: 18), SizedBox(width: 8), Text('Ngày đến hạn')],
                                          ),
                                        ),
                                      ]);

                                      if (_sortTypes[key] != SortType.none) {
                                        items.add(const PopupMenuItem(
                                          value: 'clear',
                                          child: Row(
                                            children: [Icon(Icons.clear_all, size: 18), SizedBox(width: 8), Text('Xóa sắp xếp')],
                                          ),
                                        ));
                                      }
                                      return items;
                                    },
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: const [
                                            Text('Sắp xếp theo'),
                                            Icon(Icons.arrow_drop_down),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isPlanned)
                                const PopupMenuItem(
                                  value: PopupAction.view,
                                  child: Text('Lịch'),
                                ),
                              const PopupMenuItem(
                                value: PopupAction.theme,
                                child: Text('Chủ đề'),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: currentTab == 'Completed'
                        ? _buildCompletedTab()
                        : currentTab == 'Planned'
                        ? (_showCalendarInPlanned ? _buildCalendarPlannedTab() : _buildPlannedTab())
                            : _tasks.isEmpty
                                ? _buildTaskList([
                                    const Center(
                                      child: Text(
                                        'Chưa có nhiệm vụ nào',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ),
                                  ])
                                : _buildTaskList(
                                    _tasks.map((task) => TaskItem(
                                          task: task,
                                          onToggleCompleted: () => _taskService.toggleComplete(task),
                                          onToggleImportant: () => _taskService.toggleImportant(task),
                                          taskService: _taskService,
                                          isActive: _currentTaskDetail?.id == task.id,
                                          onTap: () => setState(() {
                                            _currentTaskDetail = task;
                                          }),
                                        )).toList(),
                                  ),
                  ),
                ],
              ),
            ),
            if (_currentTaskDetail != null)
              Container(
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade300)),
                ),
                child: TaskDetailView(
                  task: _currentTaskDetail!,
                  taskService: _taskService,
                  onClose: () => setState(() => _currentTaskDetail = null),
                ),
              ),
          ],
        ),
      );
    } else {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(position: offset, child: child);
        },
        child: _buildAndroidView(),
      );
    }
  }

  Widget _buildAndroidView() {
    final bgColor = _backgroundColors[currentListId ?? currentTab];
    switch (currentAndroidView) {
      case AndroidView.sidebar:
        return Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      currentAndroidView = AndroidView.taskList;
                    });
                  },
                ),
                title: const Text('Danh sách'),
              ),
              Expanded(
                child: Sidebar(
                  onTabSelected: (tab) {
                    _handleTabChange(tab);
                    setState(() {
                      currentAndroidView = AndroidView.taskList;
                    });
                  },
                  taskService: _taskService,
                  isFullScreen: true,
                ),
              ),
            ],
          ),
        );  
      case AndroidView.taskList:
        return Scaffold(
          backgroundColor: bgColor ?? Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                currentAndroidView = AndroidView.sidebar;
              }),
            ),
            title: currentTab == 'SearchResult'
              ? TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm...',
                    border: InputBorder.none,
                  ),
                  onChanged: (text) {
                    _handleTabChange('search:$text');
                  },
                )
              : Text(currentTab),
            actions: [
              PopupMenuButton<PopupAction>(
                onSelected: (PopupAction action) async {
                    if (action == PopupAction.theme) {
                      _showThemePickerDialog();
                    }
                    else if (action == PopupAction.view && currentTab == 'Planned') {
                      setState(() {
                        _showCalendarInPlanned = !_showCalendarInPlanned;
                      });
                    }
                    else if (action == PopupAction.connectGoogle) {
                    await GoogleAuthService().forceReLogin();
                  
                    final account = await GoogleAuthService().signIn(force: true);
                  if (account != null) {
                    try {
                      await GoogleAuthService().syncAllTasksToCalendar(
                        _taskService.getPlannedTasks(),
                      );
                    } catch (_) {}
                  }
                  
                  }
                  },
                itemBuilder: (context) {
                  final key = currentListId ?? currentTab;
                  final isPlanned = currentTab == 'Planned';
                  final isImportant = currentTab == 'Important';

                  return [
                    if (!isPlanned)
                      PopupMenuItem<PopupAction>(
                        value: PopupAction.sort,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'clear') {
                              _sortTypes[key] = SortType.none;
                            } else {
                              final sortType = {
                                'importance': SortType.importance,
                                'createdDate': SortType.createdDate,
                                'alphabet': SortType.alphabet,
                                'dueDate': SortType.dueDate,
                              }[value];

                              if (sortType != null) {
                                if (_sortTypes[key] == sortType) {
                                  _sortAsc[key] = !_sortAsc[key]!;
                                } else {
                                  _sortTypes[key] = sortType;
                                  _sortAsc[key] = true;
                                }
                              }
                            }
                            setState(() => _loadTasks());
                            FocusScope.of(context).unfocus();
                          },
                          itemBuilder: (_) {
                            final items = <PopupMenuEntry<String>>[];
                            if (!isImportant) {
                              items.add(const PopupMenuItem(
                                value: 'importance',
                                child: Row(
                                  children: [Icon(Icons.star_border, size: 18), SizedBox(width: 8), Text('Tầm quan trọng')],
                                ),
                              ));
                            }
                            items.addAll([
                              const PopupMenuItem(
                                value: 'createdDate',
                                child: Row(
                                  children: [Icon(Icons.event, size: 18), SizedBox(width: 8), Text('Ngày tạo')],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'alphabet',
                                child: Row(
                                  children: [Icon(Icons.sort_by_alpha, size: 18), SizedBox(width: 8), Text('Theo chữ cái')],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'dueDate',
                                child: Row(
                                  children: [Icon(Icons.access_time, size: 18), SizedBox(width: 8), Text('Ngày đến hạn')],
                                ),
                              ),
                            ]);

                            if (_sortTypes[key] != SortType.none) {
                              items.add(const PopupMenuItem(
                                value: 'clear',
                                child: Row(
                                  children: [Icon(Icons.clear_all, size: 18), SizedBox(width: 8), Text('Xoá sắp xếp')],
                                ),
                              ));
                            }
                            return items;
                          },
                          child: const SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Sắp xếp theo'),
                                  Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isPlanned) ...[
                        const PopupMenuItem(
                          value: PopupAction.connectGoogle,
                          child: Text('Kết nối Google Calendar'),
                        ),
                        const PopupMenuItem(
                          value: PopupAction.view,
                          child: Text('Lịch'),
                        ),
                      ],
                    const PopupMenuItem(
                      value: PopupAction.theme,
                      child: Text('Chủ đề'),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: currentTab == 'Completed'
              ? _buildCompletedTab()
              : currentTab == 'Planned'
             ? (_showCalendarInPlanned ? _buildCalendarPlannedTab() : _buildPlannedTab())

                  : _buildTaskList(
                      _tasks.map((task) => TaskItem(
                            task: task,
                            onToggleCompleted: () => _taskService.toggleComplete(task),
                            onToggleImportant: () => _taskService.toggleImportant(task),
                            taskService: _taskService,
                            isActive: _currentTaskDetail?.id == task.id,
                            onTap: () {
                              setState(() {
                                _currentTaskDetail = task;
                                currentAndroidView = AndroidView.taskDetail;
                              });
                            },
                          )).toList(),
                    ),
        );
      case AndroidView.taskDetail:
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                currentAndroidView = AndroidView.taskList;
              }),
            ),
            title: const Text('Chi tiết tác vụ'),
          ),
          body: TaskDetailView(
            task: _currentTaskDetail!,
            taskService: _taskService,
            onClose: () => setState(() {
              _currentTaskDetail = null;
              currentAndroidView = AndroidView.taskList;
            }),
          ),
        );
    }
  }
  Widget _buildCalendarPlannedTab() {
  final tasksByDate = <DateTime, List<Task>>{};
  for (final task in _tasks) {
    if (task.dueDate == null) continue;
    final d = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    tasksByDate.putIfAbsent(d, () => []).add(task);
  }

  final normalizedSelectedDay = _selectedDay != null
    ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
    : null;

  final tasksToShow = normalizedSelectedDay != null
      ? tasksByDate[normalizedSelectedDay] ?? []
      : _tasks;


  return Column(
    children: [
      TableCalendar<Task>(
  focusedDay: _focusedDay,
  firstDay: DateTime(2000),
  lastDay: DateTime(2100),
  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
  eventLoader: (day) {
    final d = DateTime(day.year, day.month, day.day);
    return tasksByDate[d] ?? [];
  },
  onDaySelected: (selected, focused) {
    setState(() {
      _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
      _focusedDay = focused;
    });
  },
  calendarStyle: const CalendarStyle(
    todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
    selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
    markerDecoration: BoxDecoration(color: Colors.transparent),
  ),
  headerStyle: const HeaderStyle(formatButtonVisible: false),
  calendarBuilders: CalendarBuilders<Task>(
    markerBuilder: (context, day, events) {
      if (events.isEmpty) return const SizedBox.shrink();

      return Positioned(
        bottom: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${events.length}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    },
  ),
),
      const Divider(),
      Expanded(
        child: SmartScrollWrapper(
          controller: _scrollController,
          children: tasksToShow.map((task) => TaskItem(
            task: task,
            onToggleCompleted: () => _taskService.toggleComplete(task),
            onToggleImportant: () => _taskService.toggleImportant(task),
            taskService: _taskService,
            isActive: _currentTaskDetail?.id == task.id,
            onTap: () {
              setState(() {
                _currentTaskDetail = task;
                currentAndroidView = AndroidView.taskDetail;
              });
            },
          )).toList(),
        ),
      ),
    ],
  );
}


  @override
  void dispose() {
    _taskSubscription.cancel();
    _taskSelectedSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll(RegExp(r'đ'), 'd');
}

class QuickAddTaskBar extends StatefulWidget {
  final void Function({
    required String title,
    DateTime? dueDate,
    DateTime? reminderTime,
    RepeatFrequency repeat,
    int repeatEvery,
    List<int>? repeatWeekdays,
  }) onSubmit;

  const QuickAddTaskBar({super.key, required this.onSubmit});

  @override
  State<QuickAddTaskBar> createState() => _QuickAddTaskBarState();
}

class _QuickAddTaskBarState extends State<QuickAddTaskBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  DateTime? _dueDate;
  DateTime? _reminderTime;
  RepeatFrequency _repeat = RepeatFrequency.none;
  int _repeatEvery = 1;
  List<int> _repeatWeekdays = [];

  bool get isActive => _controller.text.trim().isNotEmpty;

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _reminderTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _showRepeatDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => RepeatPickerDialog(
        initialFrequency: _repeat,
        initialEvery: _repeatEvery,
        initialWeekdays: _repeatWeekdays,
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      _repeat = result['repeat'] as RepeatFrequency;
      _repeatEvery = result['every'] as int;
      _repeatWeekdays = List<int>.from(result['weekdays'] ?? []);
    });
  }

  void _submit() {
    widget.onSubmit(
      title: _controller.text.trim(),
      dueDate: _dueDate,
      reminderTime: _reminderTime,
      repeat: _repeat,
      repeatEvery: _repeatEvery,
      repeatWeekdays: _repeatWeekdays,
    );

    _controller.clear();
    setState(() {
      _dueDate = null;
      _reminderTime = null;
      _repeat = RepeatFrequency.none;
      _repeatEvery = 1;
      _repeatWeekdays = [];
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.add, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onTap: () {
                _focusNode.unfocus();
                Future.delayed(const Duration(milliseconds: 1), () {
                  _focusNode.requestFocus();
                });
              },
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Thêm tác vụ',
                border: InputBorder.none,
              ),
            ),
          ),
          if (isActive)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _pickDueDate,
                  tooltip: 'Ngày đến hạn',
                ),
                IconButton(
                  icon: const Icon(Icons.alarm),
                  onPressed: _pickReminder,
                  tooltip: 'Nhắc nhở',
                ),
                IconButton(
                  icon: const Icon(Icons.repeat),
                  onPressed: _showRepeatDialog,
                  tooltip: 'Lặp lại',
                ),
                if (_dueDate != null)
                  Text(
                    '${_dueDate!.day}/${_dueDate!.month}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Thêm'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
