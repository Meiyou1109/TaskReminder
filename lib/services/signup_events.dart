import 'package:firebase_auth/firebase_auth.dart';
import 'event_bus_service.dart';

// Events
abstract class SignUpEvent {}

class SignUpRequestedEvent extends SignUpEvent {
  final String email;
  final String password;

  SignUpRequestedEvent(this.email, this.password);
}

class SignUpSuccessEvent extends SignUpEvent {}

class SignUpFailedEvent extends SignUpEvent {
  final String message;

  SignUpFailedEvent(this.message);
}

// Event Handler Registration
void registerSignUpHandler() {
  EventBusService.on<SignUpRequestedEvent>().listen((event) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: event.email, password: event.password);

      await credential.user?.sendEmailVerification();

      EventBusService.fire(SignUpSuccessEvent());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        EventBusService.fire(SignUpFailedEvent('Email này đã được sử dụng.'));
      } else if (e.code == 'weak-password') {
        EventBusService.fire(SignUpFailedEvent('Mật khẩu quá yếu. (Tối thiểu 6 ký tự)'));
      } else {
        EventBusService.fire(SignUpFailedEvent('Đăng ký thất bại: ${e.message}'));
      }
    }
  });
}
