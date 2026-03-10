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
      isForegroundMode: true,           // Survives app swipe-up on Android
      notificationChannelId: "tracking_channel",
      initialNotificationTitle: "Agent Online",
      initialNotificationContent: "Sending location every 60 seconds",
      foregroundServiceNotificationId: 100,
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
  // Called periodically by iOS to let the background task do work.
  // TrackingService is a singleton in this isolate — send one location update.
  TrackingService().sendLocationFromBackground();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Required for Android 14+ to prevent crash on service start.
    service.setAsForegroundService();
  }

  // Listen for destination updates forwarded from the main UI isolate.
  service.on('updateDestination').listen((event) {
    if (event != null) {
      final double lat = (event['latitude'] as num).toDouble();
      final double lng = (event['longitude'] as num).toDouble();
      TrackingService().updateDestination(lat, lng);
    }
  });

  // Gracefully stop: tear down tracking before service exits.
  service.on('stopService').listen((event) async {
    await TrackingService().setOnlineStatus(false);
    service.stopSelf();
  });

  print("[BG] Background service started — 60s tracking loop active");

  // Start the 60-second loop inside the background isolate.
  // The TrackingService singleton in THIS isolate manages its own Timer + WS.
  await TrackingService().setOnlineStatus(true);
}
