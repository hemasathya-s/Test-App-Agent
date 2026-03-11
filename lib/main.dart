import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'config/router.dart';
import 'core/services/background_tracking.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create the notification channel required for the background service (Android 8.0+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'tracking_channel', // id - MUST MATCH background_tracking.dart
    'Agent Tracking Service', // title
    description: 'This channel is used for agent location tracking.', // description
    importance: Importance.low, // low importance so it doesn't pop up constantly
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize the background service configuration.
  await initializeBackgroundService();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IT Fixer Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
