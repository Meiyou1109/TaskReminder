import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_bus_service.dart';
import 'firebase_task_service.dart';
import 'global.dart';
import '../models/task.dart';

// Login Events
abstract class LoginEvent {}

class LoginRequestedEvent extends LoginEvent {
  final String username;
  final String password;

  LoginRequestedEvent(this.username, this.password);
}

class LoginSuccessEvent extends LoginEvent {}

class LoginFailedEvent extends LoginEvent {
  final String message;

  LoginFailedEvent(this.message);
}

// Login Handler
void registerLoginHandler() {
  EventBusService.on<LoginRequestedEvent>().listen((event) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: event.username,
        password: event.password,
      );
      final user = userCredential.user;

      if (user != null && user.emailVerified) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('autoLogin', true);

        final tasks = await FirebaseTaskService().getTasks(user.uid);
        for (Task task in tasks) {
          myTaskService.addTask(task);
        }

        EventBusService.fire(LoginSuccessEvent());
      } else {
        await FirebaseAuth.instance.signOut();
        EventBusService.fire(LoginFailedEvent('Vui lòng xác thực email trước khi đăng nhập.'));
      }
    } on FirebaseAuthException catch (e) {
      EventBusService.fire(LoginFailedEvent(e.message ?? 'Lỗi đăng nhập không xác định'));
    }
  });
}
