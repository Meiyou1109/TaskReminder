import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/signup_page.dart';

import 'services/login_events.dart';
import 'services/signup_events.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'services/task_notification_handler.dart';
import 'services/task_sync_handler.dart';
import 'services/event_bus_service.dart';



// Khởi tạo service
final myTaskService = TaskService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await myTaskService.loadGroupsAndLists();
  await myTaskService.loadFromFirebase();
  NotificationService.updateTasks(myTaskService.tasks);
  await NotificationService.initialize();
  await NotificationService.scheduleDailyDueToday();

  registerLoginHandler();
  registerSignUpHandler();
  registerTaskNotificationHandler(myTaskService);
  registerTaskSyncHandler(EventBusService.instance);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkEmailVerified(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final bool isVerified = snapshot.data ?? false;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Task Reminder',
          theme: ThemeData(useMaterial3: true),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginPage());
              case '/signup':
                return MaterialPageRoute(builder: (_) => const SignUpPage());
              case '/home':
                return MaterialPageRoute(
                  builder: (_) => HomePage(taskService: myTaskService),
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('404 - Not Found')),
                  ),
                );
            }
          },
          home: isVerified
              ? HomePage(taskService: myTaskService)
              : const LoginPage(),
        );
      },
    );
  }

  Future<bool> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    }
    return false;
  }
}
