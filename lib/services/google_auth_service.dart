import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/task.dart';
import 'firebase_task_service.dart';

const _scopes = [
  calendar.CalendarApi.calendarScope, 
  'https://www.googleapis.com/auth/calendar.events',
];


class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  GoogleSignInAccount? _currentGoogleAccount;

  GoogleAuthService._internal();

  bool get isGoogleSignedIn => _currentGoogleAccount != null;

  Future<void> forceReLogin() async {
  try {
    await _googleSignIn.signOut(); 
    _currentGoogleAccount = null;
  } catch (e) {
    Logger('GoogleAuthService').warning('Đăng xuất thất bại: $e');
  }
}



  Future<GoogleSignInAccount?> signIn({bool force = false}) async {
  if (!force && _currentGoogleAccount != null) return _currentGoogleAccount;

  try {
    if (force) {
      await _googleSignIn.signOut();
      _currentGoogleAccount = null;
    }

    Logger('GoogleAuthService').info('Bắt đầu đăng nhập Google...');
    
    final account = await _googleSignIn.signInSilently();
    if (account != null) {
      Logger('GoogleAuthService').info('Đăng nhập silent thành công: ${account.email}');
      _currentGoogleAccount = account;
      return account;
    }
    
    Logger('GoogleAuthService').info('Silent sign-in thất bại, thử đăng nhập thủ công...');
    _currentGoogleAccount = await _googleSignIn.signIn();
    
    if (_currentGoogleAccount != null) {
      Logger('GoogleAuthService').info('Đăng nhập thủ công thành công: ${_currentGoogleAccount!.email}');
    } else {
      Logger('GoogleAuthService').warning('Đăng nhập thủ công thất bại');
    }
    
    return _currentGoogleAccount;
  } catch (e) {
    Logger('GoogleAuthService').warning('Lỗi đăng nhập Google: $e');
    return null;
  }
}

  Future<void> syncAllTasksToCalendar(List<Task> tasks) async {
    final calendarApi = await getCalendarApi();
    if (calendarApi == null) return;

    for (final task in tasks) {
      if (task.dueDate == null) continue;

      try {
        final event = calendar.Event()
          ..summary = task.title
          ..description = task.note ?? '';

        if (task.reminderTime != null) {
          // Lấy ngày từ dueDate, giờ từ reminderTime
          final start = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            task.reminderTime!.hour,
            task.reminderTime!.minute,
          );
          event.start = calendar.EventDateTime(
            dateTime: start,
            timeZone: "Asia/Ho_Chi_Minh",
          );
          event.end = calendar.EventDateTime(
            dateTime: start.add(const Duration(hours: 1)),
            timeZone: "Asia/Ho_Chi_Minh",
          );
        } else {
          // All-day event: kéo dài từ 0:00 đến 23:59 cùng ngày
          event.start = calendar.EventDateTime(
            dateTime: DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day, 0, 0),
            timeZone: "Asia/Ho_Chi_Minh",
          );
          event.end = calendar.EventDateTime(
            dateTime: DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day, 23, 59),
            timeZone: "Asia/Ho_Chi_Minh",
          );
        }

        if (task.eventId != null) {
          // Nếu đã có eventId, update event trên Google Calendar
          await calendarApi.events.update(event, "primary", task.eventId!);
        } else {
          // Nếu chưa có eventId, insert event mới
          final insertedEvent = await calendarApi.events.insert(event, "primary");
          if (insertedEvent.id != null) {
            final updatedTask = task.copyWith(eventId: insertedEvent.id);
            await FirebaseTaskService().syncUpdateTask(updatedTask);
          }
        }
      } catch (e) {
        Logger('GoogleAuthService').warning('Lỗi sync task lên Calendar: $e');
      }
    }
  }

  Future<void> deleteTaskFromCalendar(Task task) async {
  if (task.eventId == null) return;
  final calendarApi = await getCalendarApi();
  if (calendarApi == null) return;

  try {
    await calendarApi.events.delete("primary", task.eventId!);
    Logger('GoogleAuthService').info('Đã xóa event trên Google Calendar: ${task.eventId}');
  } catch (e) {
    Logger('GoogleAuthService').warning('Lỗi xóa event trên Calendar: $e');
  }
}

  Future<calendar.CalendarApi?> getCalendarApi() async {
  final account = _currentGoogleAccount ?? await _googleSignIn.signInSilently();
  if (account == null) {
    Logger('GoogleAuthService').warning('getCalendarApi: account == null');
    return null;
  }

  try {
    Logger('GoogleAuthService').info('Lấy auth headers cho account: ${account.email}');
    final authHeaders = await account.authHeaders;
    Logger('GoogleAuthService').info('Auth headers retrieved, keys: ${authHeaders.keys}');
    
    final client = GoogleAuthClient(authHeaders);
    final calendarApi = calendar.CalendarApi(client);
    
    Logger('GoogleAuthService').info('Calendar API tạo thành công');
    return calendarApi;
  } catch (e) {
    Logger('GoogleAuthService').warning('getCalendarApi error: $e');
    return null;
  }
}
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
