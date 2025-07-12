import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:win_toast/win_toast.dart';
import '../models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static List<Task> _latestTasks = [];

  static void updateTasks(List<Task> tasks) {
    _latestTasks = tasks;
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    if (Platform.isAndroid) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(settings);
      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        debugPrint('Quyền thông báo: $result');
      }
    } else if (Platform.isWindows) {
      await WinToast.instance().initialize(
        aumId: 'task.reminder.app',
        displayName: 'Task Reminder',
        iconPath: '',
        clsid: '{1E8B98D9-6C35-409F-9358-3D9A48F3D59B}',
      );
    }
  }

  static Future<void> scheduleReminder(Task task) async {
    if (task.reminderTime == null) return;
    if (Platform.isAndroid) {
      final sched = tz.TZDateTime.from(task.reminderTime!, tz.local);
      await _notifications.zonedSchedule(
        task.id.hashCode,
        'Nhắc việc: ${task.title}',
        task.note ?? '',
        sched,
        _buildDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getRepeatComponent(task),
      );
    } else if (Platform.isWindows) {
      final diff = task.reminderTime!.difference(DateTime.now());
      if (diff.inMinutes <= 10 && !diff.isNegative) {
        final xml = """
          <toast>
            <visual>
              <binding template="ToastGeneric">
                <text>Nhắc việc: ${task.title}</text>
                <text>${task.note ?? ''}</text>
              </binding>
            </visual>
          </toast>
          """;
        WinToast.instance().showCustomToast(xml: xml);
      }
    }
  }

  static Future<void> cancelNotifications(Task task) async {
    if (Platform.isAndroid) {
      await _notifications.cancel(task.id.hashCode);
      await _notifications.cancel(task.id.hashCode + 100000);
    }
  }

  static NotificationDetails _buildDetails() {
    const android = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Thông báo nhắc nhở và deadline',
      importance: Importance.max,
      priority: Priority.high,
    );
    return const NotificationDetails(android: android);
  }

  static DateTimeComponents? _getRepeatComponent(Task task) {
    if (task.repeat == RepeatFrequency.daily) {
      return DateTimeComponents.time;
    }
    return null;
  }

  static Future<void> scheduleDailyDueToday() async {
    if (Platform.isWindows) return;

    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('due_hour') ?? 8;
    final minute = prefs.getInt('due_minute') ?? 0;

    final now = DateTime.now();
    final targetTime = DateTime(now.year, now.month, now.day, hour, minute);
    final scheduled = tz.TZDateTime.from(
      targetTime.isBefore(now) ? targetTime.add(const Duration(days: 1)) : targetTime,
      tz.local,
    );

    final todayTasks = _latestTasks.where((t) {
      final isToday = t.dueDate != null &&
          t.dueDate!.year == now.year &&
          t.dueDate!.month == now.month &&
          t.dueDate!.day == now.day;
      return isToday && !t.isCompleted;
    }).toList();

    if (todayTasks.isEmpty) {
      debugPrint('Không có task nào hôm nay');
      return;
    }

    debugPrint('Đặt thông báo lúc: $scheduled với ${todayTasks.length} task');

    try {
      await _notifications.zonedSchedule(
        999999,
        'Công việc hôm nay',
        'Bạn có ${todayTasks.length} nhiệm vụ cần hoàn thành hôm nay',
        scheduled,
        _buildAndroidDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (e) {
      debugPrint('Lỗi khi đặt thông báo chính xác: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('Lỗi không xác định khi đặt thông báo: $e');
    }
  }

  static NotificationDetails _buildAndroidDetails() {
    const android = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Thông báo nhắc nhở và deadline',
      importance: Importance.max,
      priority: Priority.high,
    );
    return const NotificationDetails(android: android);
  }
}
