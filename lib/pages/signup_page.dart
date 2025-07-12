import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/event_bus_service.dart';
import '../services/signup_events.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();

  bool isLoading = false;
  bool showPassword = false;

  final Color pastelBlue = const Color(0xFFD7F0F7);
  final Color pastelBlueDark = const Color(0xFFB2E0F0);
  final Color accentPurple = const Color(0xFF5A189A);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailFocus.requestFocus();
    });

    EventBusService.on<SignUpSuccessEvent>().listen((_) {
      _handleSignUpSuccess();
    });

    EventBusService.on<SignUpFailedEvent>().listen((event) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage(event.message);
    });
  }

  Future<void> _handleSignUpSuccess() async {
    if (!mounted) return;

    setState(() => isLoading = false);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        debugPrint('Đã gửi email xác thực đến: ${user.email}');
      } catch (e) {
        debugPrint('Lỗi gửi email xác thực: $e');
      }
    }

    if (!mounted) return;
    _showMessage('Đăng ký thành công. Vui lòng xác thực email trước khi đăng nhập.');
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onSignUpPressed() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ Email và Mật khẩu');
      return;
    }

    setState(() => isLoading = true);
    EventBusService.fire(SignUpRequestedEvent(email, password));
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pastelBlue,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: pastelBlueDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sign Up',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                focusNode: emailFocus,
                controller: emailController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: pastelBlue.withAlpha((0.7 * 255).toInt()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: !showPassword,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: pastelBlue.withAlpha((0.7 * 255).toInt()),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => showPassword = true),
                      onTapUp: (_) => setState(() => showPassword = false),
                      onTapCancel: () => setState(() => showPassword = false),
                      child: const Icon(Icons.remove_red_eye_outlined, color: Colors.black54),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: isLoading ? null : _onSignUpPressed,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Đăng ký'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text.rich(
                  TextSpan(
                    text: 'Đã có tài khoản? ',
                    style: TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Đăng nhập',
                        style: TextStyle(
                          color: Color(0xFF5A189A),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    super.dispose();
  }
}
