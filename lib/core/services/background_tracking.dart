import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'tracking_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: true, // Helps survive device restarts
      isForegroundMode: true,
      notificationChannelId: "tracking_channel",
      initialNotificationTitle: "IT-fixer199 Partner",
      initialNotificationContent: "Online and waiting for jobs",
      foregroundServiceNotificationId: 100,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  TrackingService().sendLocationFromBackground();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // CRITICAL: Immediately tell Android we are a foreground service.
  if (service is AndroidServiceInstance) {
    // Force set as foreground immediately
    service.setAsForegroundService();
    
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) async {
      await TrackingService().setOnlineStatus(false);
      service.stopSelf();
    });
  }

  DartPluginRegistrant.ensureInitialized();

  // Start the tracking logic
  await TrackingService().setOnlineStatus(true);
}
