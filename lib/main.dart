import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_agent_app/config/router.dart' as app_router;
import 'package:urban_agent_app/core/services/apiservices.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';


FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeNotifications() async {
  print("🔔 [main] Initializing Local Notifications...");

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'modification_alert_channel',
    'Modification Alerts',
    description: 'Used for service modification notifications',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('new_order'),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      print("🔔 [main] Notification tapped. Payload: ${details.payload}");
      if (details.payload != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(details.payload!);
          // Navigate to Home with full data from payload
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/Home',
                (route) => false,
            arguments: data,
          );
        } catch (e) {
          print("❌ [main] Error decoding notification payload: $e");
        }
      }
    },
  );
}

bool _isAlarmNotification(RemoteMessage message) {
  final data = message.data;
  // This logic MUST match MyFirebaseMessagingService.kt shouldTriggerAlarm criteria
  return data['playSound']?.toString().toLowerCase() == 'true' ||
      data['type']?.toString().toLowerCase() == 'modification' ||
      data.containsKey('modification_id');
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 [main] Received BACKGROUND message: ${message.messageId}");
  print("🔔 [main] Full Message Data: ${message.data}");
  if (message.notification != null) {
    print("🔔 [main] Notification Title: ${message.notification?.title}");
    print("🔔 [main] Notification Body: ${message.notification?.body}");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeNotifications();

  // 🔔 Reliability Fix: Skip Flutter local notification if Native AlarmService is triggered
  if (_isAlarmNotification(message)) {
    print("🔔 [main] Native AlarmService will handle this. Skipping Flutter local notification.");
    return;
  }

  String? title = message.notification?.title ?? message.data['title'];
  String? body  = message.notification?.body  ?? message.data['body'];

  if (title != null) {
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'modification_alert_channel',
          'Modification Alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('new_order'),
        ),
      ),
      payload: jsonEncode({
        'title': title,
        'body': body ?? '',
        'modification_id': message.data['modification_id'] ?? '',
      }),
    );
  }
}

void main()async{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeNotifications();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔔 [main] Received FOREGROUND message');
    print('🔔 [main] Full Message Data: ${message.data}');
    if (message.notification != null) {
      print('🔔 [main] Notification Title: ${message.notification?.title}');
      print('🔔 [main] Notification Body: ${message.notification?.body}');
    }

    // 🔔 Reliability Fix: Skip Flutter local notification if Native AlarmService is triggered
    if (_isAlarmNotification(message)) {
      print("🔔 [main] Native AlarmService will handle this. Skipping Flutter local notification.");
      return;
    }

    String? title = message.notification?.title ?? message.data['title'];
    String? body  = message.notification?.body  ?? message.data['body'];

    if (title != null) {
      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'modification_alert_channel',
            'Modification Alerts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('new_order'),
          ),
        ),
        payload: jsonEncode({
          'title': title,
          'body': body ?? '',
          'modification_id': message.data['modification_id'] ?? '',
          'order_id': message.data['order_id'] ?? '',
          'type': message.data['type'] ?? '',
        }),
      );
    } else {
      print('⚠️ [main] Foreground message received but has no title. Notification not shown.');
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _versionChecked = false;
  bool _updateRequired = false;
  int? _currentBuildNumber;
  int? _requiredBuildNumber;
  String _storeUrl = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = int.tryParse(packageInfo.buildNumber) ?? 0;

      final versionInfo = await ApiService.fetchVersionInfo();
      final dynamic rawVersion = versionInfo['app_version'];
      final storeUrl = versionInfo['play_store_url'] as String? ?? '';

      if (!mounted) return;

      setState(() {
        _currentBuildNumber = current;
        if (rawVersion is int) {
          _requiredBuildNumber = rawVersion;
        } else if (rawVersion is String) {
          _requiredBuildNumber = int.tryParse(rawVersion);
        } else {
          _requiredBuildNumber = 0;
        }
        _storeUrl = storeUrl;
        _updateRequired = current < (_requiredBuildNumber ?? 0);
        _versionChecked = true;
      });

      if (_updateRequired) {
        // We use a small delay to ensure the router is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            app_router.router.go('/force-update', extra: {
              'currentBuild': _currentBuildNumber,
              'requiredBuild': _requiredBuildNumber,
              'storeUrl': _storeUrl,
            });
          }
        });
      }
    } catch (e) {
      print("❌ [main] Version check failed: $e");
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to check app version.\nPlease check your internet.';
        _versionChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IT Fixer Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: app_router.router,
    );
  }
}
