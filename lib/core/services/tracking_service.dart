import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'apiservices.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  Timer? _timer;
  bool _isTracking = false;
  bool _isOnline = false;

  void setOnlineStatus(bool online) {
    _isOnline = online;
    debugPrint("[TRACKING] Agent status: ${online ? 'ONLINE' : 'OFFLINE'}");
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    
    debugPrint("[TRACKING] Precise location service started.");

    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _sendLocationUpdate();
    });
    
    _sendLocationUpdate();
  }

  Future<void> _sendLocationUpdate() async {
    if (!_isOnline) return;

    try {
      final String token = ApiService.accessToken;
      if (token.isEmpty) return;

      // Use best accuracy for moving riders
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5), // Don't hang if GPS is slow
      );
      
      debugPrint("[TRACKING] SYNCING: ${position.latitude}, ${position.longitude}");

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/tracking/log/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "speed": position.speed,
          "heading": position.heading,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[TRACKING] OK: Backend Updated.');
      }
    } catch (e) {
      debugPrint('[TRACKING] GPS ERROR: $e');
    }
  }

  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
    debugPrint("[TRACKING] Stopped.");
  }
}
