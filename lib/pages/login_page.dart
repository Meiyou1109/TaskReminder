import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

import '../services/event_bus_service.dart';
import '../services/login_events.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();

  bool isLoading = false;
  bool showPassword = false;
  bool autoLogin = false;

  final Color pastelBlue = const Color(0xFFD7F0F7);
  final Color pastelBlueDark = const Color(0xFFB2E0F0);
  final Color accentPurple = const Color(0xFF5A189A);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailFocus.requestFocus();
    });

    _checkAutoLogin();

    EventBusService.on<LoginEvent>().listen((event) async {
      if (!mounted) return;
      setState(() => isLoading = false);

      if (event is LoginSuccessEvent) {
        final user = FirebaseAuth.instance.currentUser;
        await user?.reload();
        if (user != null && user.emailVerified) {
          await myTaskService.loadFromFirebase();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showError('Email chưa được xác thực. Vui lòng kiểm tra hộp thư của bạn.');
          await FirebaseAuth.instance.signOut();
        }
      } else if (event is LoginFailedEvent) {
        _showError(event.message);
      }
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuto = prefs.getBool('autoLogin') ?? false;
  
    if (isAuto) {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (!mounted) return;
  
      if (user != null && user.emailVerified) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void handleLogin() {
    if (isLoading) return;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập đầy đủ Email và Mật khẩu');
      return;
    }

    setState(() => isLoading = true);
    EventBusService.fire(LoginRequestedEvent(email, password));
  }

  void _resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showError('Vui lòng nhập email trước khi khôi phục mật khẩu.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showError('Đã gửi email khôi phục. Vui lòng kiểm tra hộp thư.');
    } on FirebaseAuthException catch (e) {
      _showError('Lỗi khôi phục mật khẩu: ${e.message}');
    }
  }

  void _showError(String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                'Login',
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: autoLogin,
                    onChanged: (val) async {
                      final newValue = val ?? false;
                      setState(() => autoLogin = newValue);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('autoLogin', newValue);
                    },
                  ),
                  const Text("Tự động đăng nhập", style: TextStyle(color: Colors.black87)),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Quên mật khẩu?', style: TextStyle(color: Colors.black54)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                onPressed: isLoading ? null : handleLogin,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Đăng nhập'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text.rich(
                  TextSpan(
                    text: 'Chưa có tài khoản? ',
                    style: TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Đăng ký',
                        style: TextStyle(color: Color(0xFF5A189A), fontWeight: FontWeight.bold),
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
