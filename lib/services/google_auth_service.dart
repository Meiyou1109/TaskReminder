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

    final account = await _googleSignIn.signInSilently();
    _currentGoogleAccount = account ?? await _googleSignIn.signIn();
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
      if (task.dueDate == null || task.eventId != null) continue;

      try {
        final event = calendar.Event()
          ..summary = task.title
          ..description = task.note ?? ''
          ..start = calendar.EventDateTime(
            dateTime: task.dueDate,
            timeZone: "Asia/Ho_Chi_Minh",
          )
          ..end = calendar.EventDateTime(
            dateTime: task.dueDate!.add(Duration(hours: 1)),
            timeZone: "Asia/Ho_Chi_Minh",
          );

        final insertedEvent = await calendarApi.events.insert(event, "primary");

        if (insertedEvent.id != null) {
          final updatedTask = task.copyWith(eventId: insertedEvent.id);
          await FirebaseTaskService().syncUpdateTask(updatedTask);
        }
      } catch (e) {
        Logger('GoogleAuthService').warning('Lỗi sync task lên Calendar: $e');
      }
    }
  }

  Future<calendar.CalendarApi?> getCalendarApi() async {
    final account = _currentGoogleAccount ?? await _googleSignIn.signInSilently();
    if (account == null) {
      Logger('GoogleAuthService').warning(' getCalendarApi: account == null');
      return null;
    }

    try {
      final authHeaders = await account.authHeaders;
      Logger('GoogleAuthService').info(' authHeaders retrieved, keys: ${authHeaders.keys}');
      final client = GoogleAuthClient(authHeaders);
      return calendar.CalendarApi(client);
    } catch (e) {
      Logger('GoogleAuthService').warning(' getCalendarApi error: $e');
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
