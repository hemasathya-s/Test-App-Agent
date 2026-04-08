import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/background_tracking.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_agent_app/config/router.dart' as app_router;
import 'package:urban_agent_app/core/services/apiservices.dart';
import 'package:urban_agent_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';


FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
const MethodChannel _alarmChannel = MethodChannel('in.itfixer199.agent/alarm');

Future<void> initializeNotifications() async {

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'modification_alert_channel',
    'Modification Alerts',
    description: 'Used for service modification notifications',
    importance: Importance.max,
    playSound: false,
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
    onDidReceiveNotificationResponse: (details) async {
      try {
        await _alarmChannel.invokeMethod('stopAlarm');

        // 🔔 Refresh Data: Trigger a refresh when a notification is tapped
        _container.read(dashboardProvider.notifier).fetchUpcomingJobs();
      } catch (e) {
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
  if (message.notification != null) {
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeNotifications();

  // 🔔 Reliability Fix: Skip Flutter local notification if Native AlarmService is triggered
  if (_isAlarmNotification(message)) {
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
          sound: const RawResourceAndroidNotificationSound('notification'),
        ),
      ),
      payload: jsonEncode({
        'title': title,
        'body': body ?? '',
      }),
    );
  }
}

void main()async{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  await initializeNotifications();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
    }

    // 🔔 Refresh Data: Trigger a refresh when ANY message arrives in the foreground
    // Use the global provider container (created below in main)
    try {
      _container.read(dashboardProvider.notifier).fetchUpcomingJobs();
    } catch (e) {
    }

    // 🔔 Reliability Fix: Skip Flutter local notification if Native AlarmService is triggered
    if (_isAlarmNotification(message)) {
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
            sound: const RawResourceAndroidNotificationSound('notification'),
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
    }
  });
  
  // 🔔 Handle notification clicks when the app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    try {
      _container.read(dashboardProvider.notifier).fetchUpcomingJobs();
    } catch (e) {
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Handle the app being opened from a terminated state via a notification
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      try {
        _container.read(dashboardProvider.notifier).fetchUpcomingJobs();
      } catch (e) {
      }
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const MyApp(),
    ),
  );
}

final _container = ProviderContainer();


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
      title: 'IT Fixer Agent',
      debugShowCheckedModeBanner: false,
    //  scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      routerConfig: app_router.router,
    );
  }
}
