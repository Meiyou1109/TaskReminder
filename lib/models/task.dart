import 'package:firebase_auth/firebase_auth.dart';

enum RepeatFrequency {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

class StepModel {
  final String id;
  final String content;
  final bool isCompleted;

  StepModel({
    required this.id,
    required this.content,
    this.isCompleted = false,
  });

  StepModel copyWith({
    String? id,
    String? content,
    bool? isCompleted,
  }) {
    return StepModel(
      id: id ?? this.id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isCompleted': isCompleted,
    };
  }

  factory StepModel.fromMap(Map<String, dynamic> map) {
    return StepModel(
      id: map['id'],
      content: map['content'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

String _cleanDate(dynamic input) {
  if (input == null) return '';
  if (input is String) return input.replaceAll('"', '');
  return input.toString();
}

class Task {
  final String id;
  String title;
  DateTime? dueDate;
  bool isImportant;
  bool isCompleted;
  bool fromTodayTab;
  String? listId;

  DateTime? reminderTime;
  RepeatFrequency repeat;
  int repeatEvery;
  List<int>? repeatWeekdays;
  String? parentId;

  String? note;
  List<StepModel>? steps;
  DateTime? createdAt;
  String? eventId;

  Task({
    required this.id,
    required this.title,
    this.dueDate,
    this.isImportant = false,
    this.isCompleted = false,
    this.fromTodayTab = false,
    this.listId,
    this.reminderTime,
    this.repeat = RepeatFrequency.none,
    this.repeatEvery = 1,
    this.repeatWeekdays,
    this.parentId,
    this.note,
    this.steps,
    this.eventId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    bool? isImportant,
    bool? isCompleted,
    bool? fromTodayTab,
    String? listId,
    DateTime? reminderTime,
    RepeatFrequency? repeat,
    int? repeatEvery,
    List<int>? repeatWeekdays,
    String? parentId,
    String? note,
    List<StepModel>? steps,
    String? eventId,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      isImportant: isImportant ?? this.isImportant,
      isCompleted: isCompleted ?? this.isCompleted,
      fromTodayTab: fromTodayTab ?? this.fromTodayTab,
      listId: listId ?? this.listId,
      reminderTime: reminderTime ?? this.reminderTime,
      repeat: repeat ?? this.repeat,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      parentId: parentId ?? this.parentId,
      note: note ?? this.note,
      steps: steps ?? this.steps,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate?.toIso8601String(),
      'isImportant': isImportant,
      'isCompleted': isCompleted,
      'fromTodayTab': fromTodayTab,
      'listId': listId,
      'reminderTime': reminderTime?.toIso8601String(),
      'repeat': repeat.name,
      'repeatEvery': repeatEvery,
      'repeatWeekdays': repeatWeekdays,
      'parentId': parentId,
      'note': note,
      'steps': steps?.map((e) => e.toMap()).toList(),
      'eventId': eventId,
      'createdAt': createdAt?.toIso8601String(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      dueDate: map['dueDate'] != null ? DateTime.parse(_cleanDate(map['dueDate'])).toLocal() : null,
      isImportant: map['isImportant'] ?? false,
      isCompleted: map['isCompleted'] ?? false,
      fromTodayTab: map['fromTodayTab'] ?? false,
      listId: map['listId'],
      reminderTime: map['reminderTime'] != null ? DateTime.parse(_cleanDate(map['reminderTime'])).toLocal() : null,
      repeat: RepeatFrequency.values.firstWhere(
        (e) => e.name == map['repeat'],
        orElse: () => RepeatFrequency.none,
      ),
      repeatEvery: map['repeatEvery'] ?? 1,
      repeatWeekdays: (map['repeatWeekdays'] as List?)?.map((e) => e as int).toList(),
      parentId: map['parentId'],
      note: map['note'],
      steps: (map['steps'] as List?)?.map((e) =>
          StepModel.fromMap(Map<String, dynamic>.from(e))).toList(),
      eventId: map['eventId'],
      createdAt: map['createdAt'] != null ? DateTime.parse(_cleanDate(map['createdAt'])).toLocal() : null,
    );
  }
}
