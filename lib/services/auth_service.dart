import 'package:firebase_auth/firebase_auth.dart';
import 'event_bus_service.dart';
import 'login_events.dart';

void registerLoginHandler() {
  EventBusService.on<LoginRequestedEvent>().listen((event) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: event.username,
        password: event.password,
      );

      final user = userCredential.user;

      if (user != null && user.emailVerified) {
        EventBusService.fire(LoginSuccessEvent());
      } else {
        EventBusService.fire(LoginFailedEvent('Vui lòng xác thực email trước khi đăng nhập.'));
      }
    } on FirebaseAuthException catch (e) {
      EventBusService.fire(LoginFailedEvent(e.message ?? 'Lỗi đăng nhập'));
    }
  });
}
