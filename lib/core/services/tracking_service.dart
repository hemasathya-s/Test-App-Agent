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
  bool _isOnline = false; // Internal state to track active status

  void setOnlineStatus(bool online) {
    _isOnline = online;
    debugPrint("[TRACKING] Agent status set to: ${online ? 'ONLINE' : 'OFFLINE'}");
    if (!online) {
      debugPrint("[TRACKING] Offline: Data sharing suspended.");
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    
    debugPrint("[TRACKING] Background tracking service running.");

    try {
      // Periodic timer every 60 seconds
      _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
        _sendLocationUpdate();
      });
      
      _sendLocationUpdate();
    } catch (e) {
      debugPrint("[TRACKING] Start Error: $e");
      _isTracking = false;
    }
  }

  Future<void> _sendLocationUpdate() async {
    // REQUIREMENT: Only share to backend if agent is ONLINE
    if (!_isOnline) {
      debugPrint(" TRACKING] Skip update: Agent is currently OFFLINE.");
      return;
    }

    try {
      final String token = ApiService.accessToken;
      if (token.isEmpty) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint("[TRACKING] SHARING: Lat: ${position.latitude}, Lng: ${position.longitude}");

      final String url = '${ApiService.baseUrl}/api/tracking/log/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "timestamp": DateTime.now().toIso8601String(),
          "is_mock_location": position.isMocked,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[TRACKING] SUCCESS: Backend updated.');
      }
    } catch (e) {
      debugPrint('[TRACKING] ERROR: $e');
    }
  }

  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
    debugPrint("[TRACKING] Service stopped.");
  }
}
